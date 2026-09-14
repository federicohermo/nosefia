## Una puerta que se ve: se la toca y la hoja gira. Cablea y nada más.
##
## **No decide si está abierta ni cuánto giró.** Eso es `Puerta`, que es de `dominio/` y tiene
## test; acá viven la bisagra, el sentido y la aritmética de transformadas, que son geometría de
## la escena y no una regla del juego.
##
## **Gira la hoja y no este cuerpo**: el script está pegado al `StaticBody3D` que el sufijo
## `-col` del modelo cuelga de la malla, así que mover al padre se lleva la colisión con la
## malla y el vano queda libre de verdad. Al revés —girar sólo el cuerpo— dejaría la puerta
## dibujada en el vano y atravesable, y la escena cargaría sin un solo error.
##
## Va en `puestos/` y no en `objetos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: de éstas hay una por vano y viven cableadas.
##
## No declara un nombre global a propósito: es cáscara, nadie la nombra desde abajo, y el `.tscn`
## que la usa la trae con su script puesto.
extends StaticBody3D

## La malla que gira, que es el padre de este cuerpo. Entra por `@export` y no con un
## `get_parent()` para que el `.tscn` diga qué se mueve en vez de que lo suponga el script.
@export var hoja: MeshInstance3D

## Qué borde de la hoja queda fijo: `1.0` el de la derecha en coordenadas de la malla, `-1.0` el
## de la izquierda. Es geometría del vano y por eso la declara cada instancia.
@export var lado_de_la_bisagra := 1.0

## Hacia qué lado se abre. Es el otro dato del vano: una hoja puede colgar del mismo borde y
## abrir para cualquiera de los dos lados, y el que da contra la pared la traba.
@export var sentido_del_giro := 1.0

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


func _ready() -> void:
	_cerrada = hoja.transform
	var caja := hoja.get_aabb()
	var borde := caja.position.x + caja.size.x if lado_de_la_bisagra > 0.0 else caja.position.x
	_bisagra = _cerrada * Vector3(borde, 0.0, 0.0)


## El contrato de «con esto se puede interactuar» es este método más el grupo del `.tscn`.
##
## Devuelve `null` porque una puerta no se levanta: si contestara un objeto, el clic del 006 se
## llevaría la hoja en la mano en vez de abrirla.
func interactuar() -> ObjetoDelAlmacen:
	_puerta.alternar()
	return null


## En qué estado está. Lo pregunta el test del vano para saber cuándo terminó el giro.
func puerta() -> Puerta:
	return _puerta


## El giro va por cuadro de física y no de dibujo: lo que se mueve es un cuerpo de colisión, y
## adelantarlo en el cuadro equivocado lo deja medio paso atrás del jugador que lo está cruzando.
func _physics_process(delta: float) -> void:
	var giro := Basis(Vector3.UP, sentido_del_giro * _puerta.avanzar(delta))
	hoja.transform = Transform3D(giro, _bisagra - giro * _bisagra) * _cerrada
