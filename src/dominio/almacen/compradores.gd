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

const JORNADA_DE_FEDE_Y_MIA := ReglasDeLaPartida.PRIMERA_JORNADA + 1
## Las jornadas de Tin y Tia: `jornada → [llegada de Tin, límite de Tin, llegada de Tia, límite
## de Tia]`, cada hora como `Vector2i(hora, minuto)`.
const HORARIOS_DE_TIN_Y_TIA: Dictionary[int, Array] = {
	ReglasDeLaPartida.PRIMERA_JORNADA:
	[Vector2i(20, 30), Vector2i(23, 0), Vector2i(23, 30), Vector2i(2, 0)],
}

## Cada fila es `[nombre, líneas del pedido, cuánto paga de más]`, y una línea es
## `[Producto.Id, unidades]`.
##
## Lo que paga se declara como **desvío** y no como número absoluto para que rebalancear el
## catálogo no deje a medio padrón pagando cualquier cosa: el que paga justo sigue pagando justo
## el día que un producto cambie de valor.
const FILAS := [
	["Marta", [[Producto.Id.ACTRONCITO, 2], [Producto.Id.ZUCARACHAS, 1]], 0],
	["Rubén", [[Producto.Id.BURBALOO, 1], [Producto.Id.DUREXTRA, 2]], -500],
	["Nélida", [[Producto.Id.MALBARDO, 1], [Producto.Id.LAYSNNT, 1]], 300],
	["El pibe del kiosco", [[Producto.Id.BURBALOO, 3]], 0],
]

const FILAS_POR_JORNADA := {
	ReglasDeLaPartida.PRIMERA_JORNADA + 2:
	[FILAS[0], ["Rubén", [[Producto.Id.JORGILLO, 1], [Producto.Id.DURONGA, 2]], -500]],
}


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


## Las jornadas con contenido propio lo traen; las demás usan el padrón vigente.
static func de_la_jornada(jornada: int) -> Array[Comprador]:
	if HORARIOS_DE_TIN_Y_TIA.has(jornada):
		return _tin_y_tia(HORARIOS_DE_TIN_Y_TIA[jornada])
	if jornada == JORNADA_DE_FEDE_Y_MIA:
		var segunda := segunda_jornada_definida()
		for comprador: Comprador in segunda:
			comprador.dialogos = DIALOGOS_SEGUNDA
		return segunda
	var lista: Array[Comprador] = []
	var filas: Array = FILAS_POR_JORNADA.get(jornada, FILAS)
	for fila: Array in filas:
		if lista.size() >= ReglasDeLaVentanilla.COMPRADORES_POR_JORNADA:
			break
		lista.append(_comprador_de(fila))
	return lista


static func _tin_y_tia(horario: Array) -> Array[Comprador]:
	var tin := _comprador_de(
		[
			"Tin",
			[[Producto.Id.MAROLINI, 1], [Producto.Id.PURA_COLA, 1], [Producto.Id.MALBARDO, 1]],
			0
		]
	)
	var tia := _comprador_de(["Tia", [[Producto.Id.ZUCARACHAS, 1], [Producto.Id.PEPITO, 1]], 0])
	tin.personaje = DialogosDeCompradores.Personaje.TIN
	tia.personaje = DialogosDeCompradores.Personaje.TIA
	tin.horario = Vector2(_desde_apertura(horario[0]), _desde_apertura(horario[1]))
	tia.horario = Vector2(_desde_apertura(horario[2]), _desde_apertura(horario[3]))
	tin.dialogos = DIALOGOS
	tia.dialogos = DIALOGOS
	return [tin, tia]


static func segunda_jornada_definida() -> Array[Comprador]:
	var fede := _comprador_de(
		["Fede", [[Producto.Id.POETICO, 1], [Producto.Id.PROGRES, 1], [Producto.Id.DURONGA, 1]], 0]
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
	fede.horario = Vector2(_desde_apertura(Vector2i(21, 15)), _desde_apertura(Vector2i(23, 45)))
	mia.horario = Vector2(_desde_apertura(Vector2i(1, 0)), _desde_apertura(Vector2i(3, 30)))
	return [fede, mia]


static func _desde_apertura(hora: Vector2i) -> float:
	return float(
		(
			(
				(
					posmod(hora.x - Reglas.HORA_DE_APERTURA, Marcador.HORAS_POR_DIA)
					* Marcador.MINUTOS_POR_HORA
				)
				+ hora.y
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
