## Dónde va cada unidad de la góndola, medida del modelo y no escrita a mano.
##
## **Es dato, no regla.** Sale de recorrer el `.blend`: cada exhibición de un producto —una
## tanda de copias sobre un estante— llega acá como el `buffer` que un `MultiMesh` espera, con
## las copias en el orden en que están puestas. Por eso vive en `escenas/` y no en `dominio/`:
## mover una caja en Blender la cambia, y eso es una medición y no una decisión. La escribe
## `.claude/scripts/blender/disponer.py`, y a mano no se toca.
##
## **Los `Array` de Blender se apagan al exportar**, así que el `.glb` trae **una unidad** de
## cada producto y es este recurso el que dice cuántas hay y dónde. Sin él la góndola se ve
## vacía: el modelo ya no lleva las copias adentro.
##
## Hay dos listas porque el juego las trata distinto:
##
## - `principales`, una por producto y **en el orden de `Producto.Id`**, es la única tanda con
##   casilleros de ese producto. Tiene una fila, o dos del mismo largo. En dos filas sus copias
##   van con la fila de atrás primero y la de adelante al final, de izquierda a derecha:
##   `visible_instance_count` corta por el final, así que los casilleros son las últimas copias
##   y caen todos en la fila de adelante, que es la que da al pasillo.
## - `guias` son las tandas fijas: lo que se repite para completar un estante. No cambian
##   nunca, y están enteras desde que abre el local.
##
## **Cuántas del final son casilleros sale de acá**: cada lugar de la fila de adelante es un
## casillero, así que el cupo de cada producto es su `filas_de_adelante`. El puesto se lo pasa
## al inventario de cada jornada, y el `Estante` lo contesta desde ahí.
class_name DisposicionDeLaGondola
extends Resource

## Cuántos flotantes ocupa una copia en el `buffer` de un `MultiMesh` en `TRANSFORM_3D`: tres
## filas de cuatro.
const FLOTANTES_POR_COPIA := 12

## El bloque que el jugador repone, uno por producto y en el orden de `Producto.Id`.
@export var principales: Array[PackedFloat32Array] = []

## Las exhibiciones que no cambian, en el orden de los hijos de `guia_del_estante.tscn`.
@export var guias: Array[PackedFloat32Array] = []

## Cuántas copias del final de cada bloque principal forman su fila de adelante, en el orden
## de `Producto.Id`. Si tiene fila de atrás, son las primeras del bloque y tienen igual largo.
@export var filas_de_adelante: PackedInt32Array = PackedInt32Array()


func primera_reponible(id: Producto.Id, cupo: int) -> int:
	var bloque := principales[id]
	var total := copias(bloque)
	if cupo <= 0 or total not in [cupo, 2 * cupo] or bloque.size() % FLOTANTES_POR_COPIA != 0:
		push_error(
			(
				"DisposicionDeLaGondola %s: el bloque %d tiene %d copias para %d casilleros"
				% [
					resource_path if not resource_path.is_empty() else resource_name,
					id,
					total,
					cupo
				]
			)
		)
		return -1
	return total - cupo


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


## Hacia dónde mira una tanda: de atrás hacia adelante, o perpendicular al orden de sus columnas
## en una sola fila. El acomodador las escribe de izquierda a derecha mirando desde el pasillo.
##
## Un bloque sin cupo o con una sola copia contesta el vector nulo en vez de inventar una
## dirección: quien lo use para girar algo lo deja como estaba.
static func frente(bloque: PackedFloat32Array, fila_de_adelante: int) -> Vector3:
	var total := copias(bloque)
	if fila_de_adelante <= 0 or fila_de_adelante > total:
		return Vector3.ZERO
	if fila_de_adelante == total:
		if total < 2:
			return Vector3.ZERO
		var costado := copia(bloque, total - 1).origin - copia(bloque, 0).origin
		costado.y = 0.0
		return costado.cross(Vector3.UP).normalized()
	var atras := Vector3.ZERO
	var adelante := Vector3.ZERO
	for indice in total:
		var origen := copia(bloque, indice).origin
		if indice < total - fila_de_adelante:
			atras += origen / (total - fila_de_adelante)
		else:
			adelante += origen / fila_de_adelante
	var direccion := adelante - atras
	direccion.y = 0.0
	return direccion.normalized()
