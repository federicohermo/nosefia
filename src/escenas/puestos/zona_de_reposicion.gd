## Un casillero de la góndola como lo ve la mira: el cuerpo que se enfoca, del tamaño de la unidad
## que va ahí, y el envase que se dibuja en él.
##
## **Hay uno por casillero, y se pinta según su papel.** Vacío, con una unidad de su producto en la
## mano, es el envase en blanco y negro, quieto, o titilando en color si la mira lo enfoca.
## Ocupado, con la mano vacía, es la unidad que se agarra, con el contorno del foco si la mira la
## enfoca. Sin papel no está para la mira. Qué papel le toca lo decide el estante, en `dominio/`,
## y cuándo está al alcance, sus reglas: acá sólo se pinta.
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
## lista iría a buscarlas entre los hijos: le pondría su contorno encima al envase que titila. El
## casillero se pinta solo, y su contorno lo pone él cuando corresponde.
@export var mallas: Array[MeshInstance3D] = []

var papel := Papel.NINGUNO

## El envase de la unidad, puesto donde va.
var vista: MeshInstance3D
## El envase en blanco y negro, quieto: el casillero que espera la unidad de la mano.
var material_quieto: Material
## El envase en color y con emisión, titilando: el que espera la unidad y la mira enfoca.
var material_apuntado: Material
## Lo que no dibuja nada: la unidad puesta ya la dibuja la góndola, y acá sólo va su contorno.
var material_invisible: Material
## El contorno del foco, para la unidad puesta que la mira enfoca.
var contorno: Material


## El clic lo resuelve el puesto de la góndola, que sabe qué hay en la mano: acá sólo se avisa
## sobre cuál casillero fue. Contesta `null` porque el clic se gasta acá y no agarra este cuerpo.
func interactuar() -> ObjetoDelAlmacen:
	casillero_usado.emit(producto, casillero)
	return null


## Se pinta según su papel, si la mira lo enfoca y si está al alcance de la vista.
func pintar(enfocado: bool, al_alcance: bool) -> void:
	collision_layer = 0 if papel == Papel.NINGUNO else CAPA_DE_LA_MIRA
	if vista == null:
		return
	vista.material_overlay = null
	match papel:
		Papel.COLOCAR:
			vista.material_override = material_apuntado if enfocado else material_quieto
			vista.visible = enfocado or al_alcance
		Papel.AGARRAR:
			vista.material_override = material_invisible
			vista.material_overlay = contorno if enfocado else null
			vista.visible = enfocado
		_:
			vista.visible = false
