## La jornada que pide desechar los Cindolor vencidos: abre su góndola completa y marca cinco
## unidades. Las demás jornadas no traen ninguna.
extends GdUnitTestSuite

const SEMILLAS := 60
const JORNADA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2
const CINDOLOR := Producto.Id.CINDOLOR


func _casilleros(cuantos: int = ReglasDelEstante.UNIDADES_POR_CAJA) -> Dictionary[Producto.Id, int]:
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		casilleros[producto.id] = cuantos
	return casilleros


func _azar(semilla: int) -> RandomNumberGenerator:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	return azar


func _cindolor_falta(jornada: int, semilla: int) -> bool:
	var inventario := Apertura.inventario_de_la_jornada(
		jornada, Compradores.de_la_jornada(jornada), _casilleros(), _casilleros(), _azar(semilla)
	)
	return inventario.faltantes().any(func(otro: Producto) -> bool: return otro.id == CINDOLOR)


func test_la_jornada_de_los_vencidos_abre_cindolor_sin_faltantes() -> void:  # AC-STK-118
	for semilla in SEMILLAS:
		(
			assert_bool(_cindolor_falta(JORNADA, semilla))
			. override_failure_message("semilla %d" % semilla)
			. is_false()
		)


func test_sin_la_regla_cindolor_si_puede_faltar() -> void:  # AC-STK-118
	var faltas := 0
	for semilla in SEMILLAS:
		if _cindolor_falta(JORNADA + 1, semilla):
			faltas += 1
	assert_int(faltas).is_greater(0)


func test_marca_cinco_casilleros_distintos_de_cindolor() -> void:  # AC-STK-118
	for semilla in SEMILLAS:
		var vencidos := Apertura.vencidos_de_la_jornada(JORNADA, _casilleros(), _azar(semilla))
		assert_array(vencidos.keys()).contains_exactly([CINDOLOR])
		var elegidos: Array = vencidos[CINDOLOR]
		assert_int(elegidos.size()).is_equal(ReglasDelEstante.CINDOLOR_VENCIDOS)
		for casillero: int in elegidos:
			assert_int(casillero).is_between(0, _casilleros()[CINDOLOR] - 1)
			assert_int(elegidos.count(casillero)).is_equal(1)


func test_las_demas_jornadas_no_traen_vencidos() -> void:  # AC-STK-118, AC-STK-121
	for numero in ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA:
		var jornada := ReglasDeLaPartida.PRIMERA_JORNADA + numero
		if jornada == JORNADA:
			continue
		assert_dict(Apertura.vencidos_de_la_jornada(jornada, _casilleros(), _azar(1))).is_empty()
