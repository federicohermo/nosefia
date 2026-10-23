extends GdUnitTestSuite

const CLAVE := "semilla"
const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA + 2
const PARTIDAS := 20


func _pedidos(partida: Partida, jornada: int) -> Array:
	var firma: Array = []
	for comprador in Compradores.de_la_jornada(jornada, partida.semilla):
		for producto in comprador.pedido().productos():
			firma.append(producto.id)
	return firma


func test_cada_partida_nueva_trae_su_semilla() -> void:  # AC-CTR-072
	var semillas: Dictionary = {}
	for _i in PARTIDAS:
		var semilla := Partida.nueva().semilla
		assert_int(semilla).is_greater(0)
		semillas[semilla] = true
	assert_int(semillas.size()).is_greater(1)


func test_guardar_y_retomar_conserva_la_semilla_y_los_pedidos() -> void:  # AC-CTR-072
	var partida := Partida.nueva()
	var retomada := Partida.desde(PoliticaDeGuardado.datos(partida))
	assert_int(retomada.semilla).is_equal(partida.semilla)
	assert_array(_pedidos(retomada, TERCERA)).is_equal(_pedidos(partida, TERCERA))


func test_retomar_dos_veces_el_mismo_guardado_da_los_mismos_pedidos() -> void:  # AC-CTR-072
	var datos := PoliticaDeGuardado.datos(Partida.nueva())
	assert_array(_pedidos(Partida.desde(datos), TERCERA)).is_equal(
		_pedidos(Partida.desde(datos), TERCERA)
	)


func test_un_guardado_sin_semilla_o_mal_tipado_estrena_una() -> void:  # AC-CTR-072
	var sin_el_campo := PoliticaDeGuardado.datos(Partida.nueva())
	sin_el_campo.erase(CLAVE)
	assert_int(Partida.desde(sin_el_campo).semilla).is_greater(0)
	var mal_tipado := PoliticaDeGuardado.datos(Partida.nueva())
	mal_tipado[CLAVE] = "abc"
	assert_int(Partida.desde(mal_tipado).semilla).is_greater(0)
	assert_int(Partida.desde({}).semilla).is_greater(0)


func test_el_guardado_lleva_la_semilla() -> void:  # AC-CTR-072
	var partida := Partida.nueva()
	assert_int(PoliticaDeGuardado.datos(partida)[CLAVE]).is_equal(partida.semilla)
