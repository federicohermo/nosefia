extends GdUnitTestSuite


func test_solo_falta_el_azul_en_la_quinta_jornada() -> void:  # AC-ANO-001
	for jornada in range(1, 9):
		for jabon: StringName in ReglasDeLaLimpieza.JABONES:
			assert_bool(AnomaliasDeLaJornada.util_disponible(jabon, jornada)).is_equal(
				jornada != 5 or jabon != &"jabon_azul"
			)
		assert_bool(AnomaliasDeLaJornada.util_disponible(&"mopa", jornada)).is_true()
		assert_bool(AnomaliasDeLaJornada.util_disponible(&"balde", jornada)).is_true()


func test_la_sustitucion_depende_de_identidad_y_jornada() -> void:  # AC-ANO-004
	var poetico := UnidadDeProducto.new(Catalogo.de(Producto.Id.POETICO))
	var otro := UnidadDeProducto.new(Catalogo.de(Producto.Id.DURONGA))
	otro.nombre = poetico.nombre
	for jornada in range(1, 9):
		assert_bool(AnomaliasDeLaJornada.sustituye_azul(poetico.id, jornada)).is_equal(jornada == 5)
		assert_bool(AnomaliasDeLaJornada.sustituye_azul(otro.id, jornada)).is_false()
		assert_bool(AnomaliasDeLaJornada.sustituye_azul(&"Poético", jornada)).is_false()
	assert_int(ReglasDeLaLimpieza.JABONES.size()).is_equal(3)


func _jornadas() -> Array[int]:
	var todas: Array[int] = []
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	for jornada in range(primera, primera + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		todas.append(jornada)
	return todas


func _restante(transcurrido: float) -> float:
	return Reglas.DURACION_DEL_TURNO - transcurrido


func test_el_corte_llega_a_las_2058_de_la_jornada_del_corte() -> void:  # AC-ANO-015
	var corte := AnomaliasDeLaJornada.SEGUNDOS_HASTA_EL_CORTE
	var sin_corte := AnomaliasDeLaJornada.Corte.SIN_CORTE
	var cortado := AnomaliasDeLaJornada.Corte.CORTADO
	var jornada := AnomaliasDeLaJornada.JORNADA_DEL_CORTE
	(
		assert_int(AnomaliasDeLaJornada.corte_tras(sin_corte, jornada, _restante(corte - 1.0)))
		. is_equal(sin_corte)
	)
	assert_int(AnomaliasDeLaJornada.corte_tras(sin_corte, jornada, _restante(corte))).is_equal(
		cortado
	)
	for transcurrido: float in [corte * 2.0, Reglas.DURACION_DEL_TURNO]:
		(
			assert_int(AnomaliasDeLaJornada.corte_tras(sin_corte, jornada, _restante(transcurrido)))
			. is_equal(cortado)
		)
	for otra: int in _jornadas():
		if otra == jornada:
			continue
		for transcurrido: float in [corte, corte * 2.0, Reglas.DURACION_DEL_TURNO]:
			(
				assert_int(
					AnomaliasDeLaJornada.corte_tras(sin_corte, otra, _restante(transcurrido))
				)
				. is_equal(sin_corte)
			)


func test_el_corte_marca_la_hora_que_dice_el_diseno() -> void:  # AC-ANO-015
	var restante := Reglas.DURACION_DEL_TURNO - AnomaliasDeLaJornada.SEGUNDOS_HASTA_EL_CORTE
	var esperada := (
		"%02d:%02d" % [AnomaliasDeLaJornada.HORA_DEL_CORTE, AnomaliasDeLaJornada.MINUTO_DEL_CORTE]
	)
	assert_str(Marcador.hora(restante)).is_equal(esperada)
	assert_str(Marcador.hora(restante + 1.0)).is_not_equal(esperada)


func test_un_corte_ya_dado_no_se_repite() -> void:  # AC-ANO-016
	var jornada := AnomaliasDeLaJornada.JORNADA_DEL_CORTE
	var tarde := _restante(AnomaliasDeLaJornada.SEGUNDOS_HASTA_EL_CORTE * 2.0)
	for estado: AnomaliasDeLaJornada.Corte in [
		AnomaliasDeLaJornada.Corte.CORTADO, AnomaliasDeLaJornada.Corte.RESTAURADO
	]:
		for restante: float in [
			_restante(AnomaliasDeLaJornada.SEGUNDOS_HASTA_EL_CORTE), tarde, 0.0
		]:
			assert_int(AnomaliasDeLaJornada.corte_tras(estado, jornada, restante)).is_equal(estado)


func test_cortado_no_hay_luz_ni_interfaces() -> void:  # AC-ANO-017
	assert_bool(AnomaliasDeLaJornada.hay_luz(AnomaliasDeLaJornada.Corte.CORTADO)).is_false()
	assert_bool(AnomaliasDeLaJornada.hay_luz(AnomaliasDeLaJornada.Corte.SIN_CORTE)).is_true()
	assert_bool(AnomaliasDeLaJornada.hay_luz(AnomaliasDeLaJornada.Corte.RESTAURADO)).is_true()


func test_el_boton_restablece_una_sola_vez() -> void:  # AC-ANO-018
	var cortado := AnomaliasDeLaJornada.Corte.CORTADO
	var restaurado := AnomaliasDeLaJornada.Corte.RESTAURADO
	var sin_corte := AnomaliasDeLaJornada.Corte.SIN_CORTE
	assert_int(AnomaliasDeLaJornada.restablecer(cortado)).is_equal(restaurado)
	assert_int(AnomaliasDeLaJornada.restablecer(restaurado)).is_equal(restaurado)
	assert_int(AnomaliasDeLaJornada.restablecer(sin_corte)).is_equal(sin_corte)


func test_el_corte_no_toca_el_turno() -> void:  # AC-ANO-019
	var tareas: Array[Tarea] = []
	var con_corte := Turno.new(Reglas.DURACION_DEL_TURNO, tareas)
	var testigo := Turno.new(Reglas.DURACION_DEL_TURNO, tareas)
	var jornada := AnomaliasDeLaJornada.JORNADA_DEL_CORTE
	var estado := AnomaliasDeLaJornada.Corte.SIN_CORTE
	var paso := AnomaliasDeLaJornada.SEGUNDOS_HASTA_EL_CORTE / 2.0
	var cuadros := int(Reglas.DURACION_DEL_TURNO / paso) + 1
	for cuadro in cuadros:
		con_corte.consumir(paso)
		testigo.consumir(paso)
		estado = AnomaliasDeLaJornada.corte_tras(estado, jornada, con_corte.tiempo_restante())
		if cuadro == cuadros / 2:
			estado = AnomaliasDeLaJornada.restablecer(estado)
		assert_float(con_corte.tiempo_restante()).is_equal(testigo.tiempo_restante())
	assert_bool(con_corte.cerrado()).is_true()
	assert_int(estado).is_equal(AnomaliasDeLaJornada.Corte.RESTAURADO)


func test_toda_apertura_parte_sin_corte() -> void:  # AC-ANO-020
	assert_int(AnomaliasDeLaJornada.corte_al_abrir()).is_equal(AnomaliasDeLaJornada.Corte.SIN_CORTE)
	assert_bool(AnomaliasDeLaJornada.hay_luz(AnomaliasDeLaJornada.corte_al_abrir())).is_true()
