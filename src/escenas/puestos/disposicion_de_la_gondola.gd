## Dónde va cada unidad de la góndola, medida del modelo y no escrita a mano.
##
## **Es dato, no regla.** Sale de recorrer el `.blend`: cada exhibición de un producto —una
## tanda contigua de copias sobre un estante— llega acá como el `buffer` que un `MultiMesh`
## espera, con las copias en el orden en que están puestas. Por eso vive en `escenas/` y no en
## `dominio/`: mover una caja en Blender la cambia, y eso es una medición y no una decisión.
##
## **Los `Array` de Blender se apagan al exportar**, así que el `.glb` trae **una unidad** de
## cada producto y es este recurso el que dice cuántas hay y dónde. Sin él la góndola se ve
## vacía: el modelo ya no lleva las copias adentro.
##
## Hay dos listas porque el juego las trata distinto:
##
## - `principales`, una por producto y **en el orden de `Producto.Id`**, es la exhibición que el
##   jugador repone. Sus copias van con **la guía primero y el tramo reponible al final**, del
##   fondo hacia el pasillo: `visible_instance_count` corta por el final, así que vender apaga
##   la copia más visible y reponer prende la siguiente hacia adelante.
## - `guias` son las otras caras donde el mismo producto se exhibe. No cambian nunca: están
##   enteras desde que abre el local, y muestran dónde va cada cosa.
##
## **Cuántas del final son reponibles no está acá**: es el `umbral` del `Catalogo`, y el puesto
## lo resta del total. Copiarlo acá sería el mismo número escrito en dos lugares.
class_name DisposicionDeLaGondola
extends Resource

## Cuántos flotantes ocupa una copia en el `buffer` de un `MultiMesh` en `TRANSFORM_3D`: tres
## filas de cuatro.
const FLOTANTES_POR_COPIA := 12

## El bloque que el jugador repone, uno por producto y en el orden de `Producto.Id`.
@export var principales: Array[PackedFloat32Array] = []

## Las exhibiciones que no cambian, en el orden de los hijos de `guia_del_estante.tscn`.
@export var guias: Array[PackedFloat32Array] = []


## Cuántas copias trae un bloque.
static func copias(bloque: PackedFloat32Array) -> int:
	@warning_ignore("integer_division")
	var cuantas := bloque.size() / FLOTANTES_POR_COPIA
	return cuantas


## La transformación de una copia.
##
## Un índice fuera del bloque devuelve la identidad en vez de indexar de más: así una copia
## queda apilada en el origen —que se ve— en lugar de un cuadro que revienta con un mensaje que
## no nombra ni a este recurso ni al producto.
static func copia(bloque: PackedFloat32Array, indice: int) -> Transform3D:
	if indice < 0 or indice >= copias(bloque):
		push_error("DisposicionDeLaGondola: la copia %d no está en el bloque" % indice)
		return Transform3D.IDENTITY
	var desde := indice * FLOTANTES_POR_COPIA
	return Transform3D(
		Vector3(bloque[desde + 0], bloque[desde + 4], bloque[desde + 8]),
		Vector3(bloque[desde + 1], bloque[desde + 5], bloque[desde + 9]),
		Vector3(bloque[desde + 2], bloque[desde + 6], bloque[desde + 10]),
		Vector3(bloque[desde + 3], bloque[desde + 7], bloque[desde + 11])
	)
