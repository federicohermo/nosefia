## Un casillero de la góndola como lo ve la mira: el cuerpo que se enfoca, del tamaño de la unidad
## que va ahí, y el envase que se dibuja en él.
##
## **Hay uno por casillero, y se pinta según su papel.** Vacío, con una unidad de su producto en la
## mano, es el envase en blanco y negro, quieto, o titilando en color y con emisión si la mira lo
## enfoca. Ocupado, con la mano vacía, es la unidad que se agarra: enfocada, la dibuja él y no la
## góndola, con el mismo titileo encima. Sin papel no está para la mira. Qué papel le toca lo
## decide el estante, en `dominio/`, y cuándo está al alcance, sus reglas: acá sólo se pinta.
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
## casillero se pinta solo.
@export var mallas: Array[MeshInstance3D] = []

var papel := Papel.NINGUNO

## Si la mira podría elegirlo ahora: cerca de su alcance y de su centro. Sólo así se le ofrece
## a la mira; con papel y lejos, no está para ella. Lo decide el puesto en cada paso de física.
var cerca_de_la_mira := false

## El radio de la esfera que envuelve la unidad, en metros: con él se sabe si alguna parte de
## ella puede caer adentro del alcance y del desvío de la mira.
var radio := 0.0

## El envase de la unidad, puesto donde va.
var vista: MeshInstance3D
## El envase en blanco y negro, quieto: el casillero que espera la unidad de la mano.
var material_quieto: Material
## El envase en color y con emisión, titilando: lo que espera el clic y la mira enfoca.
var material_apuntado: Material


## El clic lo resuelve el puesto de la góndola, que sabe qué hay en la mano: acá sólo se avisa
## sobre cuál casillero fue. Contesta `null` porque el clic se gasta acá y no agarra este cuerpo.
func interactuar() -> ObjetoDelAlmacen:
	casillero_usado.emit(producto, casillero)
	return null


## Se pinta según su papel, si la mira lo enfoca y si está al alcance de la vista.
##
## **La unidad puesta y enfocada se dibuja con su propio material**, y el titileo va encima: la
## góndola deja de dibujarla mientras tanto, y así la unidad no se dibuja dos veces en el mismo
## lugar. Sin enfocar, el envase queda con el fantasma quieto aunque no se vea, y es lo que deja
## que el calentamiento de los shaders lo encuentre.
##
## **Escribe sólo lo que cambia**: el casillero que espera la unidad se repinta cada cuadro, porque
## la vista se mueve, y cada escritura de un material o de una capa es un pedido al motor.
func pintar(enfocado: bool, al_alcance: bool) -> void:
	var capa := CAPA_DE_LA_MIRA if cerca_de_la_mira else 0
	var reemplazo: Material = material_quieto
	var encima: Material = null
	var se_ve := false
	match papel:
		Papel.COLOCAR:
			if enfocado:
				reemplazo = material_apuntado
			se_ve = enfocado or al_alcance
		Papel.AGARRAR:
			if enfocado:
				reemplazo = null
				encima = material_apuntado
			se_ve = enfocado
		_:
			capa = 0
	if collision_layer != capa:
		collision_layer = capa
	if vista == null:
		return
	if vista.material_override != reemplazo:
		vista.material_override = reemplazo
	if vista.material_overlay != encima:
		vista.material_overlay = encima
	if vista.visible != se_ve:
		vista.visible = se_ve
