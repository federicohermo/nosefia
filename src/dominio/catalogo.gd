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
## fila es rojo: `catalogo_test.gd` cuenta las filas contra `Producto.Id.size()`.
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
static func de(id: Producto.Id) -> Producto:
	var fila: Array = FILAS[id]
	var nombre: String = fila[0]
	var precio: int = fila[1]
	var umbral: int = fila[2]
	return Producto.new(id, nombre, precio, umbral)


## En el orden del enum, que es el orden en que el jugador los va a ver listados.
static func todos() -> Array[Producto]:
	var productos: Array[Producto] = []
	for id in Producto.Id.values():
		productos.append(de(id))
	return productos
