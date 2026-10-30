## El padrón de compradores del almacén: quiénes pueden aparecer y qué pide cada uno.
##
## **El padrón es fijo y no se sortea.** No es prolijidad: un sorteo acá haría que el mismo balance
## diera noches distintas, y ningún test de la ventanilla se podría escribir sin sembrar una
## semilla. El azar en un prototipo cuya tensión es aritmética esconde justo lo que hay que
## mirar — si el tiempo alcanza. Las jornadas 3 a 5 son la excepción, y la semilla es la de la
## partida: sortean qué piden, no cuándo vienen ni cuántos.
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
## Las jornadas de Tin y Tia: `jornada → [llegada de Tin, límite de Tin]`, cada hora como
## `Vector2i(hora, minuto)`. Tia llega después de que Tin se retira.
const HORARIOS_DE_TIN: Dictionary[int, Array] = {
	ReglasDeLaPartida.PRIMERA_JORNADA: [Vector2i(20, 30), Vector2i(23, 0)],
}
const MINUTOS_DE_TIA_TRAS_TIN := 30
const MINUTOS_DE_TIA_EN_LA_VENTANILLA := 150

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

## Cuántos tipos distintos, de una unidad cada uno, puede pedir un comprador al azar.
const TIPOS_MINIMOS_POR_PEDIDO := 2
const TIPOS_MAXIMOS_POR_PEDIDO := 3

## Qué puede pedir cada comprador de las jornadas al azar.
const GRUPOS: Dictionary[int, Array] = {
	DialogosDeCompradores.Personaje.TIN:
	[
		Producto.Id.MAROLINI,
		Producto.Id.PURA_COLA,
		Producto.Id.MALBARDO,
		Producto.Id.MAYONCHIS,
		Producto.Id.ARVECOR,
		Producto.Id.UAKALAS,
		Producto.Id.DON_SATURADOS,
		Producto.Id.AMARGADITO,
	],
	DialogosDeCompradores.Personaje.TIA:
	[
		Producto.Id.ZUCARACHAS,
		Producto.Id.PEPITO,
		Producto.Id.MARRANOS,
		Producto.Id.ARVECOR,
		Producto.Id.MAYONCHIS,
		Producto.Id.JORGILLO,
		Producto.Id.MAROLINI,
		Producto.Id.SALADICK,
		Producto.Id.DON_SATURADOS,
		Producto.Id.LAYSNNT,
		Producto.Id.CHISITOS,
		Producto.Id.MALBARDO,
	],
	DialogosDeCompradores.Personaje.FEDE:
	[
		Producto.Id.POETICO,
		Producto.Id.PROGRES,
		Producto.Id.DURONGA,
		Producto.Id.BURBALOO,
		Producto.Id.MALBARDO,
		Producto.Id.FERNET_GOD,
		Producto.Id.TERMINATOR,
	],
	DialogosDeCompradores.Personaje.MIA:
	[
		Producto.Id.BURBALOO,
		Producto.Id.FERNET_GOD,
		Producto.Id.TERMINATOR,
		Producto.Id.ACTRONCITO,
		Producto.Id.AMARGADITO,
		Producto.Id.PURA_COLA,
		Producto.Id.UAKALAS,
		Producto.Id.MARRANOS,
	],
	DialogosDeCompradores.Personaje.CAMI:
	[
		Producto.Id.BURBALOO,
		Producto.Id.ZUCARACHAS,
		Producto.Id.FROT_LUPS,
		Producto.Id.JORGILLO,
		Producto.Id.PEPITO,
		Producto.Id.OREMOS,
		Producto.Id.PETISAS,
		Producto.Id.MACUMBAS,
		Producto.Id.FLIM_POF,
		Producto.Id.CINDOLOR,
		Producto.Id.COSA_DE_MANI,
		Producto.Id.FEEL_RICKY_FORT,
		Producto.Id.OAAAA,
	],
}

## Las jornadas 3 a 5: `jornada → [nombre, personaje, llegada, límite]` de cada comprador, con
## cada hora como `Vector2i(hora, minuto)`. El pedido no está acá: sale del sorteo de la apertura.
const AGENDAS_AL_AZAR: Dictionary[int, Array] = {
	ReglasDeLaPartida.PRIMERA_JORNADA + 2:
	[
		["Cami", DialogosDeCompradores.Personaje.CAMI, Vector2i(20, 3), Vector2i(22, 33)],
		["Tin", DialogosDeCompradores.Personaje.TIN, Vector2i(1, 30), Vector2i(4, 0)],
	],
	ReglasDeLaPartida.PRIMERA_JORNADA + 3:
	[
		["Tia", DialogosDeCompradores.Personaje.TIA, Vector2i(22, 0), Vector2i(0, 30)],
		["Fede", DialogosDeCompradores.Personaje.FEDE, Vector2i(4, 0), Vector2i(6, 30)],
	],
	ReglasDeLaPartida.PRIMERA_JORNADA + 4:
	[
		["Cami", DialogosDeCompradores.Personaje.CAMI, Vector2i(20, 30), Vector2i(23, 0)],
		["Mía", DialogosDeCompradores.Personaje.MIA, Vector2i(5, 0), Vector2i(7, 30)],
	],
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
##
## La semilla es la de la partida: sólo las jornadas al azar la leen, y con la misma semilla y
## la misma jornada sortean los mismos productos.
static func de_la_jornada(jornada: int, semilla: int = 0) -> Array[Comprador]:
	if AGENDAS_AL_AZAR.has(jornada):
		return _al_azar(jornada, semilla)
	if HORARIOS_DE_TIN.has(jornada):
		return _tin_y_tia(HORARIOS_DE_TIN[jornada])
	if jornada == JORNADA_DE_FEDE_Y_MIA:
		var segunda := segunda_jornada_definida()
		for comprador: Comprador in segunda:
			comprador.dialogos = DIALOGOS_SEGUNDA
		return segunda
	var lista: Array[Comprador] = []
	for fila: Array in FILAS:
		if lista.size() >= ReglasDeLaVentanilla.COMPRADORES_POR_JORNADA:
			break
		lista.append(_comprador_de(fila))
	return lista


static func _al_azar(jornada: int, semilla: int) -> Array[Comprador]:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash([semilla, jornada])
	var vendibles: Array[Producto.Id] = []
	for producto in Catalogo.de_la_jornada(jornada):
		vendibles.append(producto.id)
	var lista: Array[Comprador] = []
	for fila: Array in AGENDAS_AL_AZAR[jornada]:
		var lineas: Array = []
		var restantes := GRUPOS[fila[1]].filter(
			func(id: Producto.Id) -> bool: return id in vendibles
		)
		var tipos := azar.randi_range(TIPOS_MINIMOS_POR_PEDIDO, TIPOS_MAXIMOS_POR_PEDIDO)
		for _tipo in tipos:
			lineas.append([restantes.pop_at(azar.randi_range(0, restantes.size() - 1)), 1])
		var comprador := _comprador_de([fila[0], lineas, 0])
		comprador.personaje = fila[1]
		comprador.horario = Vector2(_desde_apertura(fila[2]), _desde_apertura(fila[3]))
		lista.append(comprador)
	return lista


static func _tin_y_tia(horario_de_tin: Array) -> Array[Comprador]:
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
	tin.horario = Vector2(_desde_apertura(horario_de_tin[0]), _desde_apertura(horario_de_tin[1]))
	tia.llega_tras = tin
	tia.demora_de_llegada = float(MINUTOS_DE_TIA_TRAS_TIN * Marcador.SEGUNDOS_POR_MINUTO)
	tia.permanencia = float(MINUTOS_DE_TIA_EN_LA_VENTANILLA * Marcador.SEGUNDOS_POR_MINUTO)
	var mas_tarde := tin.horario.y + tia.demora_de_llegada
	tia.horario = Vector2(mas_tarde, mas_tarde + tia.permanencia)
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
