## El arranque de la partida de prueba: escribe el guardado una vez y prepara el turno de la
## jornada configurada, sin escena.
extends GdUnitTestSuite

## Un cuadro de la web a 60 cuadros por segundo.
const UN_CUADRO := 1.0 / 60.0
const JORNADA := 6

var _guardado: Guardado
var _cumplidas_al_cerrar := -1


func before_test() -> void:
	ArranqueDePrueba.olvidar_la_carga()
	_cumplidas_al_cerrar = -1
	_guardado = Guardado.new()
	_guardado.ruta = create_temp_dir("arranque_de_prueba").path_join("partida.guardado")
	_guardado.borrar()


func after_test() -> void:
	ArranqueDePrueba.olvidar_la_carga()


func _prueba(busqueda: String) -> PartidaDePrueba:
	var prueba := PartidaDePrueba.desde_busqueda(busqueda)
	assert_object(prueba).is_not_null()
	return prueba


func _reloj_de(jornada: int) -> RelojDelTurno:
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var obligatorias := Apertura.obligatorias(jornada)
	reloj.arrancar(Apertura.turno_de_la_jornada(obligatorias), obligatorias)
	reloj.turno_cerrado.connect(func(cumplidas: int) -> void: _cumplidas_al_cerrar = cumplidas)
	return reloj


func _arranque() -> ArranqueDePrueba:
	return auto_free(ArranqueDePrueba.new())


func _cumplidas(reloj: RelojDelTurno) -> int:
	var cumplidas := 0
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		var tarea := reloj.obligatoria(tipo)
		if tarea != null and tarea.completada():
			cumplidas += 1
	return cumplidas


# --- El guardado ---


func test_fuera_de_la_web_la_pagina_no_trae_busqueda() -> void:
	assert_str(ArranqueDePrueba.busqueda_de_la_pagina()).is_empty()


func test_sin_parametros_no_se_escribe_nada() -> void:
	var prueba := PartidaDePrueba.desde_busqueda(ArranqueDePrueba.busqueda_de_la_pagina())
	assert_bool(ArranqueDePrueba.escribir_el_guardado(prueba, _guardado)).is_false()
	assert_bool(FileAccess.file_exists(_guardado.ruta)).is_false()


func test_con_jornada_el_guardado_queda_en_esa_jornada_y_el_menu_ofrece_continuar() -> void:
	var prueba := _prueba("?jornada=%d&camino=6C" % JORNADA)
	assert_bool(ArranqueDePrueba.escribir_el_guardado(prueba, _guardado)).is_true()
	var leido := _guardado.cargar()
	assert_int(leido[PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA)]).is_equal(JORNADA)
	assert_int(Partida.desde(leido).jornada()).is_equal(JORNADA)
	(
		assert_bool(
			MenuDeInicio.new(true, _guardado.hay_guardado()).habilitada(
				MenuDeInicio.Opcion.CONTINUAR
			)
		)
		. is_true()
	)


func test_el_guardado_se_escribe_una_sola_vez_por_carga() -> void:
	var prueba := _prueba("?jornada=%d" % JORNADA)
	assert_bool(ArranqueDePrueba.escribir_el_guardado(prueba, _guardado)).is_true()
	var avanzado := PartidaSerializada.sanear(
		{PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA): JORNADA + 1}
	)
	_guardado.escribir(avanzado)
	assert_bool(ArranqueDePrueba.escribir_el_guardado(prueba, _guardado)).is_false()
	var leido := _guardado.cargar()
	assert_int(leido[PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA)]).is_equal(
		JORNADA + 1
	)


func test_sin_jornada_no_se_pisa_el_guardado_del_jugador() -> void:
	var del_jugador := PartidaSerializada.sanear(
		{PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA): JORNADA - 1}
	)
	_guardado.escribir(del_jugador)
	var prueba := _prueba("?cierre=60&completas=1")
	assert_bool(ArranqueDePrueba.escribir_el_guardado(prueba, _guardado)).is_false()
	var leido := _guardado.cargar()
	assert_int(leido[PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA)]).is_equal(
		JORNADA - 1
	)


func test_con_jornada_se_pisa_el_guardado_del_jugador() -> void:
	_guardado.escribir(PartidaSerializada.sanear({}))
	var prueba := _prueba("?jornada=%d" % JORNADA)
	assert_bool(ArranqueDePrueba.escribir_el_guardado(prueba, _guardado)).is_true()
	assert_int(Partida.desde(_guardado.cargar()).jornada()).is_equal(JORNADA)


# --- Las tareas ---


func test_con_completas_todas_las_obligatorias_arrancan_cumplidas() -> void:
	var reloj := _reloj_de(JORNADA)
	_arranque().aplicar(_prueba("?jornada=%d&completas=1" % JORNADA), reloj, JORNADA)
	assert_int(_cumplidas(reloj)).is_equal(Apertura.obligatorias(JORNADA).size())


func test_con_completas_una_tarea_descumplida_vuelve_a_quedar_cumplida() -> void:
	var reloj := _reloj_de(JORNADA)
	_arranque().aplicar(_prueba("?jornada=%d&completas=1" % JORNADA), reloj, JORNADA)
	var tipo := Apertura.obligatorias(JORNADA)[0].tipo()
	var cumplida := reloj.obligatoria(tipo)
	assert_object(cumplida).is_not_null()
	assert_bool(reloj.descumplir(cumplida)).is_true()
	assert_bool(cumplida.completada()).is_true()


func test_con_completas_al_cierre_cuentan_todas_como_cumplidas() -> void:
	var reloj := _reloj_de(JORNADA)
	_arranque().aplicar(_prueba("?jornada=%d&completas=1" % JORNADA), reloj, JORNADA)
	reloj.terminar()
	assert_int(_cumplidas_al_cerrar).is_equal(Apertura.obligatorias(JORNADA).size())


func test_sin_completas_las_tareas_se_juegan_normal() -> void:
	for busqueda: String in ["?jornada=%d" % JORNADA, "?jornada=%d&completas=0" % JORNADA]:
		ArranqueDePrueba.olvidar_la_carga()
		var reloj := _reloj_de(JORNADA)
		_arranque().aplicar(_prueba(busqueda), reloj, JORNADA)
		assert_int(_cumplidas(reloj)).is_equal(0)


func test_en_otra_jornada_no_se_cumple_ninguna_tarea_ni_se_toca_el_reloj() -> void:
	var reloj := _reloj_de(JORNADA - 1)
	var antes := reloj.tiempo_restante()
	_arranque().aplicar(_prueba("?jornada=%d&cierre=1&completas=1" % JORNADA), reloj, JORNADA - 1)
	assert_int(_cumplidas(reloj)).is_equal(0)
	assert_float(reloj.tiempo_restante()).is_equal(antes)


func test_la_jornada_siguiente_se_juega_normal() -> void:
	var reloj := _reloj_de(JORNADA)
	_arranque().aplicar(_prueba("?jornada=%d&completas=1" % JORNADA), reloj, JORNADA)
	var siguientes := Apertura.obligatorias(JORNADA + 1)
	reloj.arrancar(Apertura.turno_de_la_jornada(siguientes), siguientes)
	assert_int(_cumplidas(reloj)).is_equal(0)
	assert_bool(reloj.completar(siguientes[0])).is_true()
	assert_bool(reloj.descumplir(siguientes[0])).is_true()
	assert_int(_cumplidas(reloj)).is_equal(0)


# --- El reloj ---


func test_con_cierre_faltan_esos_segundos_reales_para_el_cierre() -> void:
	var reloj := _reloj_de(JORNADA)
	var segundos := 60.0
	_arranque().aplicar(_prueba("?jornada=%d&cierre=60" % JORNADA), reloj, JORNADA)
	assert_float(reloj.tiempo_restante() / reloj.ritmo()).is_equal_approx(segundos, UN_CUADRO)
	assert_bool(reloj.corriendo()).is_true()


func test_el_salto_del_reloj_ocurre_una_sola_vez_por_carga() -> void:
	var arranque := _arranque()
	var prueba := _prueba("?jornada=%d&cierre=60" % JORNADA)
	arranque.aplicar(prueba, _reloj_de(JORNADA), JORNADA)
	var otro := _reloj_de(JORNADA)
	var completo := otro.tiempo_restante()
	arranque.aplicar(prueba, otro, JORNADA)
	assert_float(otro.tiempo_restante()).is_equal(completo)


func test_un_cierre_mayor_que_el_tiempo_que_queda_no_retrocede_el_reloj() -> void:
	var reloj := _reloj_de(JORNADA)
	var antes := reloj.tiempo_restante()
	var de_mas := antes / reloj.ritmo() + 100.0
	_arranque().aplicar(_prueba("?jornada=%d&cierre=%f" % [JORNADA, de_mas]), reloj, JORNADA)
	assert_float(reloj.tiempo_restante()).is_equal(antes)


func test_con_cierre_cero_el_turno_arranca_en_el_cierre() -> void:
	var reloj := _reloj_de(JORNADA)
	_arranque().aplicar(_prueba("?jornada=%d&cierre=0" % JORNADA), reloj, JORNADA)
	assert_bool(reloj.corriendo()).is_false()
	assert_float(reloj.tiempo_restante()).is_equal(0.0)


# --- Los logros que se muestran ---


func test_con_logros_la_pantalla_muestra_todo_y_los_reales_no_cambian() -> void:
	var caso := CasoDeInvestigacion.de_la_partida()
	var reales := Logros.new()
	var mostrados := ArranqueDePrueba.logros_a_mostrar(_prueba("?logros=1"), reales, caso)
	assert_bool(mostrados.desbloqueado(Logros.Logro.values()[0])).is_true()
	assert_bool(reales.desbloqueado(Logros.Logro.values()[0])).is_false()
	assert_dict(reales.datos()).is_equal(Logros.new().datos())


func test_sin_logros_la_pantalla_muestra_los_reales() -> void:
	var caso := CasoDeInvestigacion.de_la_partida()
	var reales := Logros.new()
	assert_object(ArranqueDePrueba.logros_a_mostrar(null, reales, caso)).is_same(reales)
	var sin_logros := _prueba("?jornada=%d" % JORNADA)
	assert_object(ArranqueDePrueba.logros_a_mostrar(sin_logros, reales, caso)).is_same(reales)
