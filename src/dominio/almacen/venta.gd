## Lo que un comprador se lleva por la ventanilla: qué productos, cuántas unidades de cada uno y
## cuánto suma todo.
##
## No descuenta nada ni sabe si hay stock: eso lo decide `Inventario.cobrar()`. Acá sólo se
## junta el pedido.
class_name Venta
extends RefCounted

## Las líneas se acumulan por `producto.id` y nunca por instancia, por el mismo motivo que en el
## inventario: dos llamadas al catálogo dan objetos distintos del mismo producto.
var _unidades_por_id: Dictionary = {}

## En el orden en que entraron a la venta, que es el orden en que se lee el ticket.
var _productos: Array[Producto] = []


## Sobre un producto que ya está en la venta **acumula**. Una línea por llamada haría que el
## mismo producto apareciera dos veces en el ticket: un bug de pantalla nacido acá.
##
## Una cantidad que no es positiva se ignora en silencio, como los segundos negativos de
## `Turno.consumir()`: el dominio no tiene con quién hablar. No es prolijidad — sin el corte, un
## `agregar(p, -3)` pasa el control de stock de `Inventario.cobrar()` (`-3 > 0` es falso) y el
## cobro termina **sumando** tres unidades a la góndola. Una pantalla que implemente «sacar una
## unidad del ticket» como un `agregar` negativo fabricaría mercadería. Y un `agregar(p, 0)`
## dejaría una línea vacía en el ticket.
func agregar(producto: Producto, cuantas: int) -> void:
	if cuantas <= 0:
		return
	if not _unidades_por_id.has(producto.id):
		_unidades_por_id[producto.id] = 0
		_productos.append(producto)
	_unidades_por_id[producto.id] += cuantas


func unidades_de(producto: Producto) -> int:
	var cuantas: int = _unidades_por_id.get(producto.id, 0)
	return cuantas


## Devuelve los productos y no el diccionario para que `Inventario` pueda recorrer la venta sin
## conocer su representación, y para que la pantalla liste el ticket sin destriparla. La copia
## es para que quien la recorra no pueda agregarle una línea por la puerta de atrás.
func productos() -> Array[Producto]:
	return _productos.duplicate()


func total() -> int:
	var suma := 0
	for producto in _productos:
		suma += producto.precio * unidades_de(producto)
	return suma
