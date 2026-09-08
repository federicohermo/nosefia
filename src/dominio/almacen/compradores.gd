## El padrón de compradores del almacén: quiénes pueden aparecer y qué pide cada uno.
##
## **La lista es fija y no se sortea.** No es prolijidad: un sorteo acá haría que el mismo balance
## diera noches distintas, y ningún test de la ventanilla se podría escribir sin sembrar una
## semilla. El azar en un prototipo cuya tensión es aritmética esconde justo lo que hay que
## mirar — si el tiempo alcanza.
##
## **Que alguien pague distinto de lo que marca la caja está en el padrón, no librado al azar.**
## Es la única forma que tiene el juego de mentir en vivo, y un padrón donde todos pagan justo
## deja la ventanilla sin nada que mirar.
##
## Cuántos vienen por noche **no** se decide acá: lo dice `ReglasDeLaVentanilla`, y este archivo
## le entrega los primeros. Agregar una fila no cambia el balance, y subir el balance por encima
## del padrón se pone en rojo en `reglas_de_la_ventanilla_test.gd`.
class_name Compradores
extends RefCounted

## Cada fila es `[nombre, líneas del pedido, cuánto paga de más]`, y una línea es
## `[Producto.Id, unidades]`.
##
## Lo que paga se declara como **desvío** y no como número absoluto para que rebalancear el
## catálogo no deje a medio padrón pagando cualquier cosa: el que paga justo sigue pagando justo
## el día que la yerba cambie de valor.
const FILAS := [
	["Marta", [[Producto.Id.YERBA, 2], [Producto.Id.GALLETITAS, 1]], 0],
	["Rubén", [[Producto.Id.GASEOSA, 1], [Producto.Id.FIDEOS, 2]], -500],
	["Nélida", [[Producto.Id.JABON, 1], [Producto.Id.ARROZ, 1]], 300],
	["El pibe del kiosco", [[Producto.Id.GASEOSA, 3]], 0],
]


## El padrón entero, con instancias nuevas en cada llamada.
##
## Las instancias son nuevas y no compartidas por el mismo motivo que las tareas de `Apertura`:
## una atención despachada anoche llegaría despachada esta noche y la obligatoria se cumpliría
## sola a partir de la segunda jornada.
static func padron() -> Array[Comprador]:
	var lista: Array[Comprador] = []
	for fila: Array in FILAS:
		lista.append(_comprador_de(fila))
	return lista


## Los compradores de esta noche: los primeros del padrón, tantos como pida el balance.
static func de_la_jornada() -> Array[Comprador]:
	var lista: Array[Comprador] = []
	for comprador in padron():
		if lista.size() >= ReglasDeLaVentanilla.COMPRADORES_POR_JORNADA:
			break
		lista.append(comprador)
	return lista


## Un `Producto.Id` sin fila en el catálogo se saltea en vez de meter un `null` en el pedido: así
## la falta se lee como un producto que no está y no revienta al desreferenciarlo. Es la misma
## forma que `Catalogo.todos()`.
static func _comprador_de(fila: Array) -> Comprador:
	var nombre: String = fila[0]
	var lineas: Array = fila[1]
	var desvio: int = fila[2]
	var pedido := Venta.new()
	for linea: Array in lineas:
		var producto := Catalogo.de(linea[0])
		if producto == null:
			continue
		pedido.agregar(producto, linea[1])
	return Comprador.new(nombre, pedido, pedido.total() + desvio)
