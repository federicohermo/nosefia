## Cuántas unidades hay de cada producto y **dónde**: qué falta en la góndola, qué se puede
## mover del depósito al estante y qué se puede cobrar.
##
## No conoce al `Catalogo`: los productos se los pasan al `_init`. Es lo que permite armar un
## inventario de prueba con dos productos inventados en tres líneas, y lo que hace que el día
## que la yerba pase de umbral 4 a 6 ningún test de acá se entere.
##
## Nadie de este archivo abre una pantalla. Acá está la aritmética; mostrarla es de `ui/` y
## mover una unidad con la mano es de la escena.
class_name Inventario
extends RefCounted

## Los dos lugares donde puede estar una unidad. Es la distinción que hace que reponer sea una
## tarea: sin ella, mover mercadería del fondo al estante no cambia ningún número.
enum Ubicacion { DEPOSITO, GONDOLA }

## En el orden en que llegaron al `_init`.
var _productos: Array[Producto] = []

## `id` → `{ Ubicacion: unidades }`. La clave es el `id` y nunca la instancia.
var _unidades: Dictionary = {}


## Recibe los productos en vez de ir a buscarlos al `Catalogo`, y ésa es la decisión que hace
## que rebalancear los precios y los umbrales no ponga en rojo un solo test de este archivo.
func _init(productos: Array[Producto]) -> void:
	for producto in productos:
		if _unidades.has(producto.id):
			continue
		_productos.append(producto)
		_unidades[producto.id] = {Ubicacion.DEPOSITO: 0, Ubicacion.GONDOLA: 0}


func unidades(producto: Producto, ubicacion: Ubicacion) -> int:
	if not _unidades.has(producto.id):
		return 0
	var por_ubicacion: Dictionary = _unidades[producto.id]
	var cuantas: int = por_ubicacion[ubicacion]
	return cuantas


func ingresar(producto: Producto, ubicacion: Ubicacion, cuantas: int) -> void:
	if not _unidades.has(producto.id):
		return
	var por_ubicacion: Dictionary = _unidades[producto.id]
	por_ubicacion[ubicacion] += cuantas


## Devuelve **cuántas movió de verdad**, no un `bool`: con 2 unidades y un pedido de 5 mueve 2 y
## devuelve 2. Es lo que necesita quien repone unidad por unidad para saber si el gesto tuvo
## efecto, y lo que evita que la escena tenga que preguntar el stock antes de cada una.
func mover(producto: Producto, desde: Ubicacion, hacia: Ubicacion, cuantas: int) -> int:
	var disponibles := unidades(producto, desde)
	var a_mover := mini(cuantas, disponibles)
	if a_mover <= 0:
		return 0
	ingresar(producto, desde, -a_mover)
	ingresar(producto, hacia, a_mover)
	return a_mover


## Los productos cuya góndola está por debajo de su umbral, en el orden en que llegaron al
## `_init`. Ese orden es el que la pantalla lista, y sin él la lista se barajaría entre dos
## cuadros.
##
## Mira **sólo la góndola**: un producto con el depósito lleno y la góndola vacía es faltante, y
## ésa es exactamente la situación que le da al jugador la razón para ir al estante.
func faltantes() -> Array[Producto]:
	var faltan: Array[Producto] = []
	for producto in _productos:
		if unidades(producto, Ubicacion.GONDOLA) < producto.umbral:
			faltan.append(producto)
	return faltan


## Si hay al menos una unidad **en la góndola**. Lo que está en el depósito no se puede vender
## por la ventanilla: hay que reponerlo primero.
func hay_stock(producto: Producto) -> bool:
	return unidades(producto, Ubicacion.GONDOLA) > 0


## Descuenta de la góndola lo que la venta pide, y devuelve si pudo.
##
## Es **todo o nada**: recorre las líneas enteras antes de tocar una sola unidad. Descontar lo
## que se pueda dejaría un estado que el jugador no puede distinguir de una venta completa —la
## misma decisión que `Tarea.completar()`—.
##
## Un producto que la venta pide y este inventario no conoce responde 0 unidades, así que cae
## por el mismo camino que «no alcanza el stock». El `bool` alcanza porque para el jugador los
## dos motivos son el mismo: eso no se vende hoy.
func cobrar(venta: Venta) -> bool:
	var pedido := venta.productos()
	for producto in pedido:
		if venta.unidades_de(producto) > unidades(producto, Ubicacion.GONDOLA):
			return false
	for producto in pedido:
		ingresar(producto, Ubicacion.GONDOLA, -venta.unidades_de(producto))
	return true
