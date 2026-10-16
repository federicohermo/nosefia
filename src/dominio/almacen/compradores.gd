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

const DIALOGOS := preload("res://assets/dialogos/compradores_jornada_1.tres")
const DIALOGOS_SEGUNDA := preload("res://assets/dialogos/compradores_jornada_2.tres")

## Cada fila es `[nombre, líneas del pedido, cuánto paga de más]`, y una línea es
## `[Producto.Id, unidades]`.
##
## Lo que paga se declara como **desvío** y no como número absoluto para que rebalancear el
## catálogo no deje a medio padrón pagando cualquier cosa: el que paga justo sigue pagando justo
## el día que un producto cambie de valor.
const FILAS := [
	["Marta", [[Producto.Id.ACTRONCITO, 2], [Producto.Id.ZUCARACHAS, 1]], 0],
	["Rubén", [[Producto.Id.BURBALOO, 1], [Producto.Id.DUREXTRA, 2]], -500],
	["Nélida", [[Producto.Id.MALBARDO, 1], [Producto.Id.LAYSNTT, 1]], 300],
	["El pibe del kiosco", [[Producto.Id.BURBALOO, 3]], 0],
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


## Las dos primeras noches tienen contenido propio; las demás usan el padrón vigente.
static func de_la_jornada(jornada: int) -> Array[Comprador]:
	if jornada == ReglasDeLaPartida.PRIMERA_JORNADA:
		return _primera_noche()
	if jornada == 2:
		var segunda := segunda_jornada_definida()
		for comprador: Comprador in segunda:
			comprador.dialogos = DIALOGOS_SEGUNDA
		return segunda
	var lista: Array[Comprador] = []
	for comprador in padron():
		if lista.size() >= ReglasDeLaVentanilla.COMPRADORES_POR_JORNADA:
			break
		lista.append(comprador)
	return lista


static func _primera_noche() -> Array[Comprador]:
	var tin := _comprador_de(
		[
			"Tin",
			[[Producto.Id.MAROLINI, 1], [Producto.Id.CORACOLA, 1], [Producto.Id.MALBARDO, 1]],
			0
		]
	)
	var tia := _comprador_de(["Tia", [[Producto.Id.ZUCARACHAS, 1], [Producto.Id.PEPITOS, 1]], 0])
	tin.personaje = DialogosDeCompradores.Personaje.TIN
	tia.personaje = DialogosDeCompradores.Personaje.TIA
	tin.horario = Vector2(_desde_apertura(22), _desde_apertura(0))
	tia.horario = Vector2(_desde_apertura(4), _desde_apertura(6))
	tin.dialogos = DIALOGOS
	tia.dialogos = DIALOGOS
	return [tin, tia]


## Declaración preparada para J2; su entrega de contenido activa la selección productiva.
static func segunda_jornada_definida() -> Array[Comprador]:
	var fede := _comprador_de(
		["Fede", [[Producto.Id.POETICO, 1], [Producto.Id.PRONGLES, 1], [Producto.Id.DURONGA, 1]], 0]
	)
	var mia := _comprador_de(
		[
			"Mía",
			[[Producto.Id.TERMINATOR, 1], [Producto.Id.FERNET_GOD, 1], [Producto.Id.ACTRONCITO, 1]],
			0
		]
	)
	fede.personaje = DialogosDeCompradores.Personaje.FEDE
	mia.personaje = DialogosDeCompradores.Personaje.MIA
	fede.horario = Vector2(_desde_apertura(20, 30), _desde_apertura(23, 30))
	mia.horario = Vector2(_desde_apertura(5), _desde_apertura(8))
	return [fede, mia]


static func _desde_apertura(hora: int, minuto: int = 0) -> float:
	return float(
		(
			(
				(
					posmod(hora - Reglas.HORA_DE_APERTURA, Marcador.HORAS_POR_DIA)
					* Marcador.MINUTOS_POR_HORA
				)
				+ minuto
			)
			* Marcador.SEGUNDOS_POR_MINUTO
		)
	)


## Un dato inválido rechaza al comprador completo: nunca publica un pedido parcial.
static func _comprador_de(fila: Array) -> Comprador:
	var nombre: String = fila[0]
	var lineas: Array = fila[1]
	var desvio: int = fila[2]
	var pedido := Venta.new()
	for linea: Array in lineas:
		var producto := Catalogo.de(linea[0])
		if producto == null:
			push_error("El pedido requiere un producto sin catálogo: %s" % linea[0])
			return null
		pedido.agregar(producto, linea[1])
	return Comprador.new(nombre, pedido, pedido.total() + desvio)
