extends GdUnitTestSuite

const CORTE := AnomaliasDeLaJornada.Corte
const ESTADO := WifiDelLocal.Estado
const LUCES := WifiDelLocal.Luces


## Lo que el wifi vive en una noche: el reloj avanza el corte, el corte avanza el wifi.
func _noche(jornada: int, transcurrido: float, tablero: bool = false) -> WifiDelLocal:
	var wifi := WifiDelLocal.new()
	var corte := AnomaliasDeLaJornada.corte_tras(
		AnomaliasDeLaJornada.corte_al_abrir(), jornada, Reglas.DURACION_DEL_TURNO - transcurrido
	)
	wifi.seguir_al_corte(corte)
	if tablero:
		corte = AnomaliasDeLaJornada.restablecer(corte)
		wifi.seguir_al_corte(corte)
	return wifi


func _jornadas_sin_corte() -> Array[int]:
	var jornadas: Array[int] = []
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	for jornada in range(primera, primera + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		if jornada != AnomaliasDeLaJornada.JORNADA_DEL_CORTE:
			jornadas.append(jornada)
	return jornadas


func _resumen(wifi: WifiDelLocal) -> Array:
	return [wifi.estado(), wifi.hay_wifi(), wifi.luces()]


func test_abre_con_wifi_y_las_luces_verdes() -> void:  # AC-ANO-021
	assert_array(_resumen(WifiDelLocal.new())).is_equal([ESTADO.CON_WIFI, true, LUCES.VERDES])


func test_en_la_jornada_del_corte_el_wifi_sigue_al_corte() -> void:  # AC-ANO-021
	var jornada := AnomaliasDeLaJornada.JORNADA_DEL_CORTE
	var corte := AnomaliasDeLaJornada.SEGUNDOS_HASTA_EL_CORTE
	assert_array(_resumen(_noche(jornada, corte - 1.0))).is_equal(
		[ESTADO.CON_WIFI, true, LUCES.VERDES]
	)
	assert_array(_resumen(_noche(jornada, corte))).is_equal(
		[ESTADO.SIN_ENERGIA, false, LUCES.APAGADAS]
	)
	assert_array(_resumen(_noche(jornada, corte, true))).is_equal(
		[ESTADO.DESCOMPUESTO, false, LUCES.ROJAS]
	)


func test_la_luz_restaurada_no_devuelve_el_wifi_en_toda_la_noche() -> void:  # AC-ANO-021
	var jornada := AnomaliasDeLaJornada.JORNADA_DEL_CORTE
	var restaurado := _noche(jornada, AnomaliasDeLaJornada.SEGUNDOS_HASTA_EL_CORTE, true)
	for transcurrido: float in [2.0 * 3600.0, Reglas.DURACION_DEL_TURNO]:
		restaurado.seguir_al_corte(CORTE.RESTAURADO)
		assert_array(_resumen(restaurado)).is_equal([ESTADO.DESCOMPUESTO, false, LUCES.ROJAS])
		assert_array(_resumen(_noche(jornada, transcurrido))).is_equal(
			[ESTADO.SIN_ENERGIA, false, LUCES.APAGADAS]
		)


func test_las_demas_jornadas_conservan_el_wifi_toda_la_noche() -> void:  # AC-ANO-021
	var corte := AnomaliasDeLaJornada.SEGUNDOS_HASTA_EL_CORTE
	for jornada in _jornadas_sin_corte():
		for transcurrido: float in [corte, 2.0 * 3600.0, Reglas.DURACION_DEL_TURNO]:
			assert_array(_resumen(_noche(jornada, transcurrido))).is_equal(
				[ESTADO.CON_WIFI, true, LUCES.VERDES]
			)


func test_apagar_y_prender_devuelve_el_wifi() -> void:  # AC-ANO-022
	var wifi := _noche(AnomaliasDeLaJornada.JORNADA_DEL_CORTE, 0.0)
	wifi.seguir_al_corte(CORTE.CORTADO)
	wifi.seguir_al_corte(CORTE.RESTAURADO)
	wifi.accionar()
	assert_array(_resumen(wifi)).is_equal([ESTADO.APAGADO, false, LUCES.APAGADAS])
	wifi.seguir_al_corte(CORTE.RESTAURADO)
	assert_array(_resumen(wifi)).is_equal([ESTADO.APAGADO, false, LUCES.APAGADAS])
	wifi.accionar()
	assert_array(_resumen(wifi)).is_equal([ESTADO.CON_WIFI, true, LUCES.VERDES])


func test_los_demas_clics_no_cambian_el_wifi() -> void:  # AC-ANO-023
	var sin_corte := WifiDelLocal.new()
	sin_corte.accionar()
	assert_array(_resumen(sin_corte)).is_equal([ESTADO.CON_WIFI, true, LUCES.VERDES])
	var cortado := WifiDelLocal.new()
	cortado.seguir_al_corte(CORTE.CORTADO)
	cortado.accionar()
	assert_array(_resumen(cortado)).is_equal([ESTADO.SIN_ENERGIA, false, LUCES.APAGADAS])
	var devuelto := _noche(AnomaliasDeLaJornada.JORNADA_DEL_CORTE, 0.0)
	devuelto.seguir_al_corte(CORTE.CORTADO)
	devuelto.seguir_al_corte(CORTE.RESTAURADO)
	devuelto.accionar()
	devuelto.accionar()
	for _clic in 3:
		devuelto.accionar()
		assert_array(_resumen(devuelto)).is_equal([ESTADO.CON_WIFI, true, LUCES.VERDES])


func test_abrir_cualquier_jornada_deja_el_wifi() -> void:  # AC-ANO-024
	var estados: Array[AnomaliasDeLaJornada.Corte] = [CORTE.CORTADO, CORTE.RESTAURADO]
	for corte in estados:
		var wifi := WifiDelLocal.new()
		wifi.seguir_al_corte(CORTE.CORTADO)
		wifi.seguir_al_corte(corte)
		assert_bool(wifi.hay_wifi()).is_false()
		wifi.abrir_jornada()
		assert_array(_resumen(wifi)).is_equal([ESTADO.CON_WIFI, true, LUCES.VERDES])
	var apagado := _noche(AnomaliasDeLaJornada.JORNADA_DEL_CORTE, 0.0)
	apagado.seguir_al_corte(CORTE.CORTADO)
	apagado.seguir_al_corte(CORTE.RESTAURADO)
	apagado.accionar()
	apagado.abrir_jornada()
	assert_array(_resumen(apagado)).is_equal([ESTADO.CON_WIFI, true, LUCES.VERDES])


func test_avisa_cada_cambio_una_sola_vez() -> void:  # AC-ANO-021
	var wifi := WifiDelLocal.new()
	var avisos: Array[int] = []
	wifi.estado_cambiado.connect(func(estado: ESTADO) -> void: avisos.append(estado))
	wifi.seguir_al_corte(CORTE.SIN_CORTE)
	wifi.accionar()
	wifi.abrir_jornada()
	assert_array(avisos).is_empty()
	wifi.seguir_al_corte(CORTE.CORTADO)
	wifi.seguir_al_corte(CORTE.CORTADO)
	wifi.seguir_al_corte(CORTE.RESTAURADO)
	wifi.seguir_al_corte(CORTE.RESTAURADO)
	wifi.accionar()
	wifi.accionar()
	assert_array(avisos).is_equal(
		[ESTADO.SIN_ENERGIA, ESTADO.DESCOMPUESTO, ESTADO.APAGADO, ESTADO.CON_WIFI]
	)


func test_el_jugador_apaga_y_prende_el_router_y_cada_gesto_avisa() -> void:
	var wifi := _noche(AnomaliasDeLaJornada.JORNADA_DEL_CORTE, 0.0)
	wifi.seguir_al_corte(CORTE.CORTADO)
	wifi.seguir_al_corte(CORTE.RESTAURADO)
	var gestos: Array[String] = []
	wifi.router_apagado.connect(func() -> void: gestos.append("apagado"))
	wifi.router_prendido.connect(func() -> void: gestos.append("prendido"))
	wifi.accionar()
	wifi.accionar()
	wifi.accionar()
	assert_array(gestos).is_equal(["apagado", "prendido"])


func test_el_corte_y_la_apertura_no_avisan_ningun_gesto_del_router() -> void:
	var wifi := WifiDelLocal.new()
	var gestos: Array[String] = []
	wifi.router_apagado.connect(func() -> void: gestos.append("apagado"))
	wifi.router_prendido.connect(func() -> void: gestos.append("prendido"))
	wifi.seguir_al_corte(CORTE.CORTADO)
	wifi.seguir_al_corte(CORTE.RESTAURADO)
	wifi.abrir_jornada()
	wifi.accionar()
	assert_array(gestos).is_empty()
