## Un casillero de la góndola como lo ve la mira: el cuerpo que se enfoca, del tamaño de la unidad
## que va ahí, y el envase que se dibuja en él.
##
## **Hay uno por casillero, y sólo se dibuja el que la mira enfoca.** Vacío, con una unidad de su
## producto en la mano, es el contorno del foco con la forma del envase, sin su superficie.
## Ocupado, con la mano vacía, marca la unidad que dibuja la góndola, sin reemplazar su superficie.
## Sin papel no está para la mira. Qué papel le toca lo decide el estante,
## en `dominio/`: acá sólo se pinta.
extends StaticBody3D

signal casillero_usado(producto: Producto.Id, casillero: int)

## Para qué está el casillero con lo que hay en la mano.
enum Papel { NINGUNO, COLOCAR, AGARRAR }

## La capa de lo que sólo existe para la mira, la misma de la mancha del piso: nada choca con un
## casillero, y los rayos de la mira sí lo encuentran.
const CAPA_DE_LA_MIRA := 2

@export var producto: Producto.Id
@export var casillero: int

## **Vacía a propósito.** La marca del foco pinta las mallas que un objetivo declara, y sin la
## lista iría a buscarlas entre los hijos: pisaría el contorno que el envase ya lleva. El
## casillero se pinta solo.
@export var mallas: Array[MeshInstance3D] = []

var papel := Papel.NINGUNO

## Si la mira podría elegirlo ahora: cerca de su alcance y de su centro. Sólo así se le ofrece
## a la mira; con papel y lejos, no está para ella. Lo decide el puesto en cada paso de física.
var cerca_de_la_mira := false

## El radio de la esfera que envuelve la unidad, en metros: con él se sabe si alguna parte de
## ella puede caer adentro del alcance y del desvío de la mira.
var radio := 0.0

## El envase de la unidad, puesto donde va. Lleva siempre encima el contorno del foco.
var vista: MeshInstance3D
## Con qué se dibuja el envase: tapa lo que el contorno tiene detrás, y no se ve.
var sin_superficie: Material


## El clic lo resuelve el puesto de la góndola, que sabe qué hay en la mano: acá sólo se avisa
## sobre cuál casillero fue. Contesta `null` porque el clic se gasta acá y no agarra este cuerpo.
func interactuar() -> ObjetoDelAlmacen:
	casillero_usado.emit(producto, casillero)
	return null


## Se pinta según su papel y si la mira lo enfoca: sólo el enfocado se dibuja.
##
## La góndola conserva la superficie y su iluminación durante el hover. El casillero dibuja
## solamente sus aristas: reemplazar la superficie cambiaba su color al enfocar y al salir.
##
## **Escribe sólo lo que cambia**: cada escritura de un material o de una capa es un pedido al
## motor.
func pintar(enfocado: bool) -> void:
	var con_papel := papel != Papel.NINGUNO
	var capa := CAPA_DE_LA_MIRA if cerca_de_la_mira and con_papel else 0
	var se_ve := enfocado and con_papel
	if collision_layer != capa:
		collision_layer = capa
	if vista == null:
		return
	if vista.visible != se_ve:
		vista.visible = se_ve
