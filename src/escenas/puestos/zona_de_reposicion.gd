## Un casillero de la góndola como lo ve la mira: el cuerpo que se enfoca, del tamaño de la unidad
## que va ahí, y el envase que se dibuja en él.
##
## **Hay uno por casillero, y sólo se dibuja el que la mira enfoca.** Vacío, con una unidad de su
## producto en la mano, es el contorno del foco con la forma del envase, sin su superficie.
## Ocupado, con la mano vacía, es la unidad que se agarra: la dibuja él y no la góndola, con el
## mismo contorno encima. Sin papel no está para la mira. Qué papel le toca lo decide el estante,
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
## Con qué se dibuja el envase del casillero vacío: tapa lo que el contorno tiene detrás, y no se
## ve.
var sin_superficie: Material


## El clic lo resuelve el puesto de la góndola, que sabe qué hay en la mano: acá sólo se avisa
## sobre cuál casillero fue. Contesta `null` porque el clic se gasta acá y no agarra este cuerpo.
func interactuar() -> ObjetoDelAlmacen:
	casillero_usado.emit(producto, casillero)
	return null


## Se pinta según su papel y si la mira lo enfoca: sólo el enfocado se dibuja.
##
## **La unidad puesta y enfocada se dibuja con su propio material**: la góndola deja de dibujarla
## mientras tanto, y así la unidad no se dibuja dos veces en el mismo lugar. El casillero vacío
## enfocado se dibuja sin superficie. El contorno va encima de los dos, y no se escribe acá: el
## envase lo lleva desde que se arma.
##
## **Apagado, el envase queda con la superficie que no se ve.** El calentamiento de los shaders
## dibuja una vez lo oculto con los materiales que tiene puestos, y así encuentra los dos.
##
## **Escribe sólo lo que cambia**: cada escritura de un material o de una capa es un pedido al
## motor.
func pintar(enfocado: bool) -> void:
	var con_papel := papel != Papel.NINGUNO
	var capa := CAPA_DE_LA_MIRA if cerca_de_la_mira and con_papel else 0
	var se_ve := enfocado and con_papel
	var reemplazo: Material = null if se_ve and papel == Papel.AGARRAR else sin_superficie
	if collision_layer != capa:
		collision_layer = capa
	if vista == null:
		return
	if vista.material_override != reemplazo:
		vista.material_override = reemplazo
	if vista.visible != se_ve:
		vista.visible = se_ve
