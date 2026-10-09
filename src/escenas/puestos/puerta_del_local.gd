## **No decide si está abierta ni cuánto giró.** Eso es `Puerta`, que es de `dominio/` y tiene
## test; acá viven la bisagra, el sentido y la aritmética de transformadas, que son geometría de
## la escena y no una regla del juego.
##
## **El cuerpo es animable y no estático.** Un estático movido a mano le pasa a través a lo que
## tiene adelante y no lo despierta. Uno animable lo empuja: el motor arrastra lo suelto sin
## código propio. El `.tscn` no le puede cambiar el tipo al cuerpo que trae el modelo, y por eso
## éste es nuevo y el del modelo queda con la forma apagada.
##
## Va en `puestos/` y no en `objetos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: de éstas hay una por vano y viven cableadas.
##
## No declara un nombre global a propósito: es cáscara, nadie la nombra desde abajo, y el `.tscn`
## que la usa la trae con su script puesto.
extends AnimatableBody3D

## La hoja quedó quieta: al terminar un giro, o al cerrarla de golpe.
signal hoja_quieta(cuerpo: PhysicsBody3D)

## Un gesto sobre la puerta. Sale una vez, al pedirlo, y no durante el giro.
signal puerta_abierta(puerta: Node3D)
signal puerta_cerrada(puerta: Node3D)
signal puerta_trabada(puerta: Node3D)
signal porton_trabado(puerta: Node3D)

## Qué aviso da una puerta que no abre.
enum Traba { NINGUNA, PUERTA, PORTON }

## La malla que gira, que es el padre de este cuerpo. Entra por `@export` y no con un
## `get_parent()` para que el `.tscn` diga qué se mueve en vez de que lo suponga el script.
@export var hoja: MeshInstance3D

## Un herraje puede sobresalir del canto de la hoja. El eje explícito evita que ese detalle
## cambie el punto de giro; las puertas sin anclaje conservan el borde de su malla.
@export var eje_de_la_bisagra: Marker3D

## Las mallas que el marco del objetivo pinta al enfocar. Sin esto iría a buscar
## `MeshInstance3D` hijos de este cuerpo, que no tiene ninguno: la puerta se vería sin contorno.
@export var mallas: Array[MeshInstance3D] = []

## El setter y no `_ready()`: los tests tocan la puerta sin meter la escena al árbol.
@export var traba := Traba.NINGUNA:
	set(valor):
		traba = valor
		_puerta = Puerta.new(valor != Traba.NINGUNA)

var _puerta := Puerta.new()

## La hoja cerrada, en coordenadas del padre. Se guarda entera y no sólo el ángulo porque el
## giro se compone contra ella: acumular sobre la transformada actual arrastra el error de cada
## cuadro y la hoja termina corrida del marco.
var _cerrada: Transform3D

## El punto por el que pasa el eje, en coordenadas del padre.
var _bisagra: Vector3

var _girando := false

## Dónde va este cuerpo respecto de la hoja. **El cuerpo no sigue a la hoja solo**: un cuerpo
## animable sincronizado con la física sólo se entera de su propia transformada, no de la del
## padre. Medido el 2026-09-26: con la hoja girando, el cuerpo del servidor no se movía. Por eso
## va suelto de la jerarquía y el giro se le escribe a él.
var _desde_la_hoja: Transform3D


func _ready() -> void:
	_cerrada = hoja.transform
	var punto := Vector3(hoja.get_aabb().position.x, 0.0, 0.0)
	if eje_de_la_bisagra != null:
		punto = hoja.to_local(eje_de_la_bisagra.global_position)
	_bisagra = _cerrada * punto
	_desde_la_hoja = hoja.global_transform.affine_inverse() * global_transform
	top_level = true


## El clic derecho de lo fijo comparte la operación con las puertas de heladera.
func accionar() -> void:
	usar()


## Abrir, cerrar o intentar una puerta trabada corresponde al clic derecho.
## El mismo gesto emite el aviso que dispara su sonido.
func usar() -> void:
	if not _puerta.alternar():
		(porton_trabado if traba == Traba.PORTON else puerta_trabada).emit(self)
	elif _puerta.abierta():
		puerta_abierta.emit(self)
	else:
		puerta_cerrada.emit(self)


## En qué estado está.
func puerta() -> Puerta:
	return _puerta


## Sin reiniciar la interpolación, la hoja se dibujaría girando hasta cerrarse.
func cerrar_de_golpe() -> void:
	_puerta.cerrar_de_golpe()
	_girando = false
	hoja.transform = _cerrada
	# Animable, el cuerpo llega a su lugar con velocidad y despide lo que toca la hoja: medido el
	# 2026-09-26, una unidad apoyada salía a 85 m/s. Estático, salta.
	PhysicsServer3D.body_set_mode(get_rid(), PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_state(
		get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, hoja.global_transform * _desde_la_hoja
	)
	PhysicsServer3D.body_set_mode(get_rid(), PhysicsServer3D.BODY_MODE_KINEMATIC)
	hoja.reset_physics_interpolation()
	hoja_quieta.emit(self)


## El giro va por cuadro de física y no de dibujo: lo que se mueve es un cuerpo de colisión, y
## adelantarlo en el cuadro equivocado lo deja medio paso atrás del jugador que lo está cruzando.
func _physics_process(delta: float) -> void:
	var giro := Basis(Vector3.UP, _puerta.avanzar(delta))
	hoja.transform = Transform3D(giro, _bisagra - giro * _bisagra) * _cerrada
	global_transform = hoja.global_transform * _desde_la_hoja
	if not _puerta.quieta():
		_girando = true
	elif _girando:
		_girando = false
		hoja_quieta.emit(self)
