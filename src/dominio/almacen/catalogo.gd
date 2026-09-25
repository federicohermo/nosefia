## Qué productos existen en el almacén y con qué valores.
##
## Es el único lugar donde viven el nombre, el precio y el umbral de cada producto. Están acá y
## no adentro de `inventario.gd` porque son los números que se van a mover balanceando, y un
## valor que vive al lado de la lógica que lo usa termina copiado en el segundo lugar que lo
## necesita.
##
## Los productos y sus tres columnas son un **primer valor**: el GDD no los fija. Se
## ajustan jugando, y ajustarlos no rompe ningún test de `inventario.gd`, que recibe los
## productos en vez de venir a buscarlos acá.
class_name Catalogo
extends RefCounted

## Cada `Producto.Id` con su nombre, su precio en pesos enteros y su umbral de reposición.
##
## **Los nombres son los del modelo 3D**, y no una etiqueta genérica: cada fila tiene detrás
## una malla que el jugador ve en la góndola, y un nombre que no coincide con lo que se ve
## deja al inventario hablando de otra cosa. Qué malla es cada uno lo dice
## `contenido_del_estante.tscn`, donde están en este mismo orden.
##
## Agregar un producto es una línea en el enum de `producto.gd` y una fila acá. Olvidarse de la
## fila es rojo: `catalogo_test.gd` cuenta las filas de acá contra `Producto.Id.size()`, y las
## cuenta sobre este diccionario y no sobre `todos()` a propósito —ver `de()`—.
const FILAS := {
	Producto.Id.ACTRONCITO: ["Actroncito", 2500, 8],
	Producto.Id.DUREXTRA: ["Durextra", 1200, 8],
	Producto.Id.BURBALOO: ["Burbaloo", 1800, 8],
	Producto.Id.ZUCARACHAS: ["Zucarachas", 900, 8],
	Producto.Id.LAYSNTT: ["Laysntt", 1100, 8],
	Producto.Id.MALBARDO: ["Malbardo", 1500, 8],
	Producto.Id.PRONGLES: ["Prongles", 1200, 8],
	Producto.Id.JORGILLO: ["Jorgillo", 900, 8],
	Producto.Id.ARVEJAS: ["Arvejas", 800, 8],
	Producto.Id.CHISITOS: ["Chisitos", 700, 8],
	Producto.Id.OREMOS: ["Oremos", 1000, 8],
	Producto.Id.PEPITOS: ["Pepitos", 950, 8],
	Producto.Id.SALADIK: ["Saladik", 850, 8],
	Producto.Id.UAKAS: ["Uakas", 1300, 8],
	Producto.Id.CORACOLA: ["Coracola", 1400, 8],
	Producto.Id.FROTLUPS: ["Frotlups", 1600, 8],
	Producto.Id.MAROLINI: ["Marolini", 1050, 8],
	Producto.Id.AMARGADITO: ["Amargadito", 3200, 8],
	Producto.Id.CINDOLOR: ["Cindolor", 1900, 8],
	Producto.Id.FLINPUF: ["Flinpuf", 600, 8],
	Producto.Id.DONSATURADOS: ["Donsaturados", 1150, 8],
	Producto.Id.PETISAS: ["Petisas", 980, 8],
	Producto.Id.MACUMBAS: ["Macumbas", 1250, 8],
}


## Construye un producto nuevo en cada llamada, y eso es correcto: la identidad es el `id`, así
## que dos productos con el mismo `id` indexan al mismo lugar. Es lo que permite que esto sea
## `static` y que ningún test tenga que compartir estado.
##
## Un `id` sin fila devuelve `null` en vez de indexar el diccionario y reventar. El motivo está
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
