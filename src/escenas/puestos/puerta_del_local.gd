## Una puerta que se ve: se la toca y la hoja gira hacia adentro del cuarto. Cablea y nada más.
##
## **No decide si está abierta ni cuánto giró.** Eso es `Puerta`, que es de `dominio/` y tiene
## test; acá viven la bisagra, el sentido y la aritmética de transformadas, que son geometría de
## la escena y no una regla del juego.
##
## **Gira la hoja y no este cuerpo**: el script está pegado a un cuerpo hijo de la malla, así
## que mover al padre se lleva la colisión con la malla y el vano queda libre de verdad. Al
## revés —girar sólo el cuerpo— dejaría la puerta dibujada en el vano y atravesable, y la escena
## cargaría sin un solo error.
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

## Un gesto sobre la puerta. Sale una vez, al pedirlo, y no durante el giro.
signal puerta_abierta(puerta: Node3D)
signal puerta_cerrada(puerta: Node3D)
signal puerta_trabada(puerta: Node3D)
signal porton_trabado(puerta: Node3D)

## Qué aviso da una puerta que no abre. El portón suena distinto que las otras dos.
enum Traba { NINGUNA, PUERTA, PORTON }

## La malla que gira, que es el padre de este cuerpo. Entra por `@export` y no con un
## `get_parent()` para que el `.tscn` diga qué se mueve en vez de que lo suponga el script.
@export var hoja: MeshInstance3D

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
	if not _puerta.alternar():
		(porton_trabado if traba == Traba.PORTON else puerta_trabada).emit(self)
	elif _puerta.abierta():
		puerta_abierta.emit(self)
	else:
		puerta_cerrada.emit(self)
	return null


## En qué estado está. Lo pregunta el test del vano para saber cuándo terminó el giro.
func puerta() -> Puerta:
	return _puerta


## La cierra de golpe y pone la hoja en su lugar en el mismo paso. Sin reiniciar la
## interpolación, la hoja se dibujaría girando hasta cerrarse.
func cerrar_de_golpe() -> void:
	_puerta.cerrar_de_golpe()
	_girando = false
	# Sin sincronizar con la física, el cuerpo salta a su lugar en vez de barrer el recorrido y
	# llevarse por delante lo que haya en el vano.
	sync_to_physics = false
	hoja.transform = _cerrada
	global_transform = hoja.global_transform * _desde_la_hoja
	sync_to_physics = true
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
