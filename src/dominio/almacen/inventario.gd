## Cuántas unidades hay de cada producto y **dónde**: qué falta en la góndola, qué se puede
## mover del depósito al estante y qué se puede cobrar.
##
## No conoce al `Catalogo` ni al local: los productos y los casilleros de la fila de adelante
## de cada uno se los pasan al `_init`. Es lo que permite armar un inventario de prueba con dos
## productos inventados en tres líneas, y lo que hace que el día que el modelo mueva una fila
## ningún test de acá se entere.
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

## Cuántos casilleros tiene la fila de adelante de cada producto: cuántas unidades pide su
## góndola. La clave es el `id`, como en `_unidades`.
var _casilleros: Dictionary[Producto.Id, int] = {}


## Recibe los productos y sus casilleros en vez de ir a buscarlos, y ésa es la decisión que hace
## que rebalancear el catálogo o mover una fila en el modelo no ponga en rojo un solo test de
## este archivo.
##
## **Los casilleros vienen del local armado y no del producto**: cuántas unidades pide la
## góndola de cada uno es lo que entra en su fila de adelante, que lo mide la escena. Un
## producto sin casilleros no tiene dónde ir en la góndola: no falta nunca y todo su depósito se
## vende.
func _init(productos: Array[Producto], casilleros: Dictionary[Producto.Id, int] = {}) -> void:
	for producto in productos:
		# Un `id` repetido en la lista se ignora: sin este corte, el segundo pisaría con
		# ceros lo ya contado y `faltantes()` devolvería el mismo producto dos veces, que es una
		# línea duplicada en la lista de reposición.
		if _unidades.has(producto.id):
			continue
		_productos.append(producto)
		_unidades[producto.id] = {Ubicacion.DEPOSITO: 0, Ubicacion.GONDOLA: 0}
		var declarados: int = casilleros.get(producto.id, 0)
		_casilleros[producto.id] = maxi(0, declarados)


## Cuántos casilleros tiene la fila de adelante de ese producto: su cupo. Cero si el inventario
## no lo conoce o no le declararon casilleros.
func casilleros(producto: Producto) -> int:
	if producto == null:
		return 0
	return _casilleros.get(producto.id, 0)


func unidades(producto: Producto, ubicacion: Ubicacion) -> int:
	if not _unidades.has(producto.id):
		return 0
	var por_ubicacion: Dictionary = _unidades[producto.id]
	var cuantas: int = por_ubicacion[ubicacion]
	return cuantas


## Suma unidades a una ubicación. Una cantidad que no es positiva se ignora en silencio, igual
## que los segundos negativos de `Turno.consumir()`: por acá se **ingresa** mercadería, y el
## único que la resta es este archivo. Sin el corte, un `ingresar(p, GONDOLA, -5)` de quien
## reponga mal deja la góndola en `-5`, que `faltantes()` lee como vacía y `mover()` como que no
## hay nada: un estado imposible que ningún número delata.
func ingresar(producto: Producto, ubicacion: Ubicacion, cuantas: int) -> void:
	if cuantas <= 0:
		return
	_sumar(producto, ubicacion, cuantas)


## El único que puede restar, y por eso es privado: `mover()` y `cobrar()` lo usan con un delta
## negativo después de haber verificado que hay con qué, así que las unidades nunca bajan de 0.
func _sumar(producto: Producto, ubicacion: Ubicacion, delta: int) -> void:
	if not _unidades.has(producto.id):
		return
	var por_ubicacion: Dictionary = _unidades[producto.id]
	por_ubicacion[ubicacion] += delta


## Devuelve **cuántas movió de verdad**, no un `bool`: con 2 unidades y un pedido de 5 mueve 2 y
## devuelve 2. Es lo que necesita quien repone unidad por unidad para saber si el gesto tuvo
## efecto, y lo que evita que la escena tenga que preguntar el stock antes de cada una.
func mover(producto: Producto, desde: Ubicacion, hacia: Ubicacion, cuantas: int) -> int:
	var disponibles := unidades(producto, desde)
	var a_mover := mini(cuantas, disponibles)
	if a_mover <= 0:
		return 0
	_sumar(producto, desde, -a_mover)
	_sumar(producto, hacia, a_mover)
	return a_mover


## Los productos con algún casillero vacío en su fila de adelante, en el orden en que llegaron
## al `_init`. Ese orden es el que la pantalla lista, y sin él la lista se barajaría entre dos
## cuadros.
##
## Mira **sólo la góndola**: un producto con el depósito lleno y la góndola vacía es faltante, y
## ésa es exactamente la situación que le da al jugador la razón para ir al estante. Y cuenta
## contra la fila, no contra lo que la jornada hizo faltar: un casillero que se vacía durante la
## noche vuelve a faltar aunque la jornada no lo haya pedido.
func faltantes() -> Array[Producto]:
	var faltan: Array[Producto] = []
	for producto in _productos:
		if _vacios(producto) > 0:
			faltan.append(producto)
	return faltan


## Cuántos casilleros de la fila de adelante de ese producto están vacíos: lo que a su góndola
## le falta. Nunca menos de cero, aunque la góndola tenga más de lo que su fila pide.
func _vacios(producto: Producto) -> int:
	return maxi(0, casilleros(producto) - unidades(producto, Ubicacion.GONDOLA))


## Cuántas unidades de ese producto se pueden vender: el depósito menos los casilleros vacíos de
## su fila de adelante, y nunca menos de 0.
##
## Lo que el estante necesita no se vende. Sin ese descuento, una venta se llevaría la unidad
## que el jugador iba a colocar, y reponer quedaría sin cumplir sin que nada lo avise.
##
## Una unidad en la mano sigue en el depósito hasta que se coloca, y también en lo que a la
## góndola le falta: por eso no se vende, y colocarla después sigue funcionando.
func vendibles(producto: Producto) -> int:
	if not _unidades.has(producto.id):
		return 0
	return maxi(0, unidades(producto, Ubicacion.DEPOSITO) - _vacios(producto))


## Descuenta del depósito lo que la venta pide, y devuelve si pudo. La góndola no se toca.
##
## Es **todo o nada**: recorre las líneas enteras antes de tocar una sola unidad. Descontar lo
## que se pueda dejaría un estado que el jugador no puede distinguir de una venta completa —la
## misma decisión que `Tarea.completar()`—.
##
## Un producto que la venta pide y este inventario no conoce tiene 0 vendibles, así que cae por
## el mismo camino que «no alcanza». El `bool` alcanza porque para el jugador los dos motivos
## son el mismo: eso no se vende hoy.
func cobrar(venta: Venta) -> bool:
	var pedido := venta.productos()
	for producto in pedido:
		if venta.unidades_de(producto) > vendibles(producto):
			return false
	for producto in pedido:
		_sumar(producto, Ubicacion.DEPOSITO, -venta.unidades_de(producto))
	return true
