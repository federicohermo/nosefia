## Qué productos existen en el almacén y con qué valores.
##
## Es el único lugar donde viven el nombre, el precio y el umbral de cada producto. Están acá y
## no adentro de `inventario.gd` porque son los números que se van a mover balanceando, y un
## valor que vive al lado de la lógica que lo usa termina copiado en el segundo lugar que lo
## necesita.
##
## Los seis productos y sus tres columnas son un **primer valor**: el GDD no los fija. Se
## ajustan jugando, y ajustarlos no rompe ningún test de `inventario.gd`, que recibe los
## productos en vez de venir a buscarlos acá.
class_name Catalogo
extends RefCounted

## Cada `Producto.Id` con su nombre, su precio en pesos enteros y su umbral de reposición.
##
## Agregar un producto es una línea en el enum de `producto.gd` y una fila acá. Olvidarse de la
## fila es rojo: `catalogo_test.gd` cuenta las filas de acá contra `Producto.Id.size()`, y las
## cuenta sobre este diccionario y no sobre `todos()` a propósito —ver `de()`—.
const FILAS := {
	Producto.Id.YERBA: ["Yerba", 2500, 4],
	Producto.Id.FIDEOS: ["Fideos", 1200, 4],
	Producto.Id.GASEOSA: ["Gaseosa", 1800, 6],
	Producto.Id.GALLETITAS: ["Galletitas", 900, 5],
	Producto.Id.ARROZ: ["Arroz", 1100, 3],
	Producto.Id.JABON: ["Jabón", 1500, 2],
}


## Construye un producto nuevo en cada llamada, y eso es correcto: la identidad es el `id`, así
## que dos yerbas distintas indexan al mismo lugar. Es lo que permite que esto sea `static` y
## que ningún test tenga que compartir estado.
##
## Un `id` sin fila devuelve `null` en vez de indexar el diccionario y reventar, y es la misma
## forma que `Reglas.costo_de()`, que devuelve `0.0` para un tipo sin costo. El motivo está
## medido el 2026-09-01: con un séptimo valor en el enum y sin su fila, `FILAS[id]` tira
## `Out of bounds get index '6' (on base: 'Dictionary')`, gdUnit4 lo cuenta como *error* y no
## como *failure* —la línea de estadísticas del archivo sigue diciendo `PASSED`— y la aserción
## que tenía que ponerse en rojo **nunca llega a correr**. Con `null` el rojo lo produce la
## aserción, que es lo que el AC promete.
static func de(id: Producto.Id) -> Producto:
	if not FILAS.has(id):
		return null
	var fila: Array = FILAS[id]
	var nombre: String = fila[0]
	var precio: int = fila[1]
	var umbral: int = fila[2]
	return Producto.new(id, nombre, precio, umbral)


## En el orden del enum, que es el orden en que el jugador los va a ver listados.
##
## Saltea los `id` sin fila para no meter un `null` en la lista que después recorre la pantalla:
## así la falta de una fila se lee como un producto que no está y la cuenta de `catalogo_test.gd`
## se pone en rojo afirmando, en vez de romperse al desreferenciar.
static func todos() -> Array[Producto]:
	var productos: Array[Producto] = []
	for id in Producto.Id.values():
		var producto := de(id)
		if producto == null:
			continue
		productos.append(producto)
	return productos
