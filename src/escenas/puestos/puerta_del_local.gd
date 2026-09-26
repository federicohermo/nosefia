## Una puerta que se ve: se la toca y la hoja gira hacia adentro del cuarto. Cablea y nada más.
##
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

## La hoja dejó de girar. Sale una vez por movimiento, en el paso en que queda quieta.
signal hoja_quieta(cuerpo: PhysicsBody3D)

## La malla que gira, que es el padre de este cuerpo. Entra por `@export` y no con un
## `get_parent()` para que el `.tscn` diga qué se mueve en vez de que lo suponga el script.
@export var hoja: MeshInstance3D

## Las mallas que el marco del objetivo pinta al enfocar. Sin esto iría a buscar
## `MeshInstance3D` hijos de este cuerpo, que no tiene ninguno: la puerta se vería sin contorno.
@export var mallas: Array[MeshInstance3D] = []

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
	# La bisagra es el borde de menor X de la hoja, y la hoja gira hacia adentro del cuarto. La
	# escena no elige ninguna de las dos cosas. El sentido está fijo porque así la hoja se aleja
	# del que la abre en vez de barrerlo. El muro no lo limita: las cuatro combinaciones de
	# borde y sentido dejan libre el barrido.
	_bisagra = _cerrada * Vector3(hoja.get_aabb().position.x, 0.0, 0.0)
	_desde_la_hoja = hoja.global_transform.affine_inverse() * global_transform
	top_level = true


## El contrato de «con esto se puede interactuar» es este método más el grupo del `.tscn`.
##
## Devuelve `null` porque una puerta no se levanta: si contestara un objeto, el clic de agarrar se
## llevaría la hoja en la mano en vez de abrirla.
func interactuar() -> ObjetoDelAlmacen:
	_puerta.alternar()
	return null


## En qué estado está. Lo pregunta el test del vano para saber cuándo terminó el giro.
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
