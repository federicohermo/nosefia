## Lo que la partida recuerda de cada noche de prueba, y cómo vuelve del disco.
extends GdUnitTestSuite

const CondicionesDelJefeTest := preload("res://test/dominio/empleo/condiciones_del_jefe_test.gd")

const SEGUNDA := ReglasDeLaPartida.PRIMERA_JORNADA + 1
const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA + 2


func test_la_noche_vuelve_igual_de_sus_datos() -> void:  # AC-EMP-086
	var sin_cumplir: Array[Tarea.Tipo] = [Tarea.Tipo.REGISTRAR, Tarea.Tipo.REPONER]
	var noche := ResultadoDeLaNoche.new(2, sin_cumplir)
	var leida := ResultadoDeLaNoche.desde_datos(noche.a_datos())
	assert_int(leida.mal_atendidos).is_equal(2)
	assert_bool(leida.cumplio(Tarea.Tipo.REGISTRAR)).is_false()
	assert_bool(leida.cumplio(Tarea.Tipo.REPONER)).is_false()
	assert_bool(leida.cumplio(Tarea.Tipo.CAJA)).is_true()


func test_un_dato_de_otro_tipo_no_es_una_noche() -> void:  # AC-EMP-086
	for dato: Variant in [null, 3, "x", {}, {"mal_atendidos": "2", "sin_cumplir": []}]:
		assert_object(ResultadoDeLaNoche.desde_datos(dato)).is_null()
	var con_basura := ResultadoDeLaNoche.desde_datos(
		{"mal_atendidos": 1, "sin_cumplir": ["REGISTRAR", "INVENTADA", 7]}
	)
	assert_int(con_basura.mal_atendidos).is_equal(1)
	assert_bool(con_basura.cumplio(Tarea.Tipo.REGISTRAR)).is_false()


func test_la_fila_cruza_la_sesion() -> void:  # AC-EMP-086
	var jugada := CondicionesDelJefeTest.cerrar_la_primera(2, false)
	var datos: Dictionary = str_to_var(var_to_str(PoliticaDeGuardado.datos(jugada)))
	var retomada := Partida.desde(datos)
	assert_int(retomada.jornada()).is_equal(SEGUNDA)
	assert_array(CondicionesDelJefe.elegidas(retomada.noches_de_prueba)).is_equal(
		CondicionesDelJefe.elegidas(jugada.noches_de_prueba)
	)
	assert_array(CondicionesDelJefe.elegidas(retomada.noches_de_prueba)).is_not_empty()


func test_la_tercera_retomada_repite_su_fila() -> void:  # AC-EMP-088
	var jugada := CondicionesDelJefeTest.cerrar_la_segunda(1, true, false)
	var datos: Dictionary = str_to_var(var_to_str(PoliticaDeGuardado.datos(jugada)))
	var retomada := Partida.desde(datos)
	assert_int(retomada.jornada()).is_equal(TERCERA)
	var guion: Conversacion = load(CondicionesDelJefeTest.GUION)
	var propios := InstruccionesDelJefe.de_la_jornada(
		guion.mensajes, TERCERA, CondicionesDelJefe.elegidas(retomada.noches_de_prueba)
	)
	assert_str(propios[0].identidad).is_equal("J3_Mensaje1_AtencionYReposicionMal")
	assert_int(InstruccionesDelJefe.pasos_de(propios).size()).is_equal(2)


func test_un_guardado_sin_noches_o_roto_abre_sin_mensaje_1() -> void:  # AC-EMP-086
	var clave := PartidaSerializada.clave(PartidaSerializada.Campo.NOCHES_DE_PRUEBA)
	for roto: Variant in [
		null, [], "1", {"1": "x"}, {"x": {"mal_atendidos": 0, "sin_cumplir": []}}
	]:
		var datos := {"jornada": SEGUNDA, "medios": 2}
		if roto != null:
			datos[clave] = roto
		var partida := Partida.desde(datos)
		assert_array(CondicionesDelJefe.elegidas(partida.noches_de_prueba)).is_empty()
		assert_int(partida.jornada()).is_equal(SEGUNDA)
		assert_int(partida.medios()).is_equal(2)


func test_desde_la_primera_completa_no_se_anota() -> void:  # AC-EMP-086
	var partida := Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA})
	partida.abrir_la_jornada()
	partida.cerrar_la_jornada(0, 2)
	var clave := PartidaSerializada.clave(PartidaSerializada.Campo.NOCHES_DE_PRUEBA)
	assert_dict(PoliticaDeGuardado.datos(partida)[clave]).is_empty()


func test_un_cierre_ignorado_no_anota() -> void:  # AC-EMP-086
	var partida := Partida.nueva()
	partida.cerrar_la_jornada(0, 2)
	assert_array(CondicionesDelJefe.elegidas(partida.noches_de_prueba)).is_empty()


func test_el_que_espera_al_cerrar_no_es_mal_atendido() -> void:  # AC-EMP-086
	var compradores := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	var tarea := TareaDeAtender.new(compradores, Apertura.inventario_con_faltantes({}, {}))
	tarea.avanzar(compradores[0].horario.x)
	assert_object(tarea.en_ventanilla()).is_same(compradores[0])
	assert_int(tarea.mal_atendidos()).is_zero()
	tarea.avanzar(compradores[0].horario.y + 1.0)
	assert_int(tarea.mal_atendidos()).is_equal(1)
