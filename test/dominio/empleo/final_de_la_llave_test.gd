## Abrir la puerta del jefe con la llave termina la jornada y la partida en el final 5.
extends GdUnitTestSuite

const JORNADA_7 := ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
const JORNADA_6 := JORNADA_7 - 1
const JORNADA_5 := JORNADA_6 - 1
const CUARTA := JORNADA_5 - 1


func _en_la_septima(elegir_la_6c: bool = true) -> Partida:
	var partida := Partida.desde({"jornada": JORNADA_7})
	var expediente := partida.expediente
	expediente.registrar("2A")
	expediente.elegir(CUARTA, "2A")
	expediente.registrar("5B")
	expediente.elegir(JORNADA_5, "5B")
	if elegir_la_6c:
		expediente.registrar("6C")
		expediente.elegir(JORNADA_6, "6C")
	partida.abrir_la_jornada()
	return partida


func test_la_puerta_termina_la_partida_sin_evaluar_la_noche() -> void:  # AC-SHF-112
	var partida := _en_la_septima()
	var medios := partida.medios()
	var devoluciones := partida.devoluciones_del_jefe().size()
	assert_bool(partida.abrir_la_oficina_del_jefe(Partida.LLAVE, "21:30")).is_true()
	assert_int(partida.final()).is_equal(Partida.Final.JEFE_INCOMPETENTE)
	assert_bool(partida.terminada()).is_true()
	assert_array(Array(partida.expediente.identidades())).contains(["7C"])
	assert_object(partida.reflexion).is_null()
	assert_int(partida.devoluciones_del_jefe().size()).is_equal(devoluciones)
	assert_int(partida.medios()).is_equal(medios)
	assert_int(partida.jornada()).is_equal(JORNADA_7)


func test_con_todas_las_obligatorias_cumplidas_el_final_es_el_mismo() -> void:  # AC-SHF-112
	var partida := _en_la_septima()
	for tarea: Tarea in partida.obligatorias():
		tarea.completar()
	assert_bool(partida.abrir_la_oficina_del_jefe(Partida.LLAVE)).is_true()
	assert_int(partida.final()).is_equal(Partida.Final.JEFE_INCOMPETENTE)
	assert_int(partida.final()).is_not_equal(Partida.Final.CONTRATO_CUMPLIDO)
	assert_int(partida.final()).is_not_equal(Partida.Final.LOCURA_PARANOICA)  # AC-INV-191
	assert_int(partida.final()).is_not_equal(Partida.Final.DESPEDIDO)


func test_sin_la_7c_activa_o_con_la_partida_terminada_no_cambia_nada() -> void:  # AC-SHF-112
	var sin_la_6c := _en_la_septima(false)
	assert_bool(sin_la_6c.abrir_la_oficina_del_jefe(Partida.LLAVE)).is_false()
	assert_int(sin_la_6c.final()).is_equal(Partida.Final.EN_CURSO)
	assert_array(Array(sin_la_6c.expediente.identidades())).not_contains(["7C"])
	var terminada := _en_la_septima()
	assert_bool(terminada.abrir_la_oficina_del_jefe(Partida.LLAVE)).is_true()
	assert_bool(terminada.abrir_la_oficina_del_jefe(Partida.LLAVE)).is_false()
	assert_int(terminada.final()).is_equal(Partida.Final.JEFE_INCOMPETENTE)


func test_cada_objeto_lleva_a_su_final_y_a_ningun_otro() -> void:  # AC-SHF-112
	var por_la_6c := _en_la_septima()
	assert_bool(por_la_6c.abrir_la_oficina_del_jefe(Partida.PALANCA)).is_false()
	assert_bool(por_la_6c.abrir_la_oficina_del_jefe(&"mopa")).is_false()
	assert_bool(por_la_6c.abrir_la_oficina_del_jefe(ObjetoDelAlmacen.SIN_ID)).is_false()
	assert_int(por_la_6c.final()).is_equal(Partida.Final.EN_CURSO)
	var por_la_6b := Partida.desde({"jornada": JORNADA_7})
	por_la_6b.expediente.registrar("2A")
	por_la_6b.expediente.elegir(CUARTA, "2A")
	por_la_6b.expediente.registrar("5A")
	por_la_6b.expediente.elegir(JORNADA_5, "5A")
	por_la_6b.expediente.registrar("6B")
	por_la_6b.expediente.elegir(JORNADA_6, "6B")
	por_la_6b.abrir_la_jornada()
	assert_bool(por_la_6b.abrir_la_oficina_del_jefe(Partida.LLAVE)).is_false()
	assert_int(por_la_6b.final()).is_equal(Partida.Final.EN_CURSO)
	assert_bool(por_la_6b.abrir_la_oficina_del_jefe(Partida.PALANCA)).is_true()
	assert_int(por_la_6b.final()).is_equal(Partida.Final.JEFE_SABOTEADOR)


func test_antes_de_abrir_la_jornada_la_puerta_no_termina_nada() -> void:  # AC-SHF-112
	var partida := Partida.desde({"jornada": JORNADA_7})
	assert_bool(partida.abrir_la_oficina_del_jefe(Partida.LLAVE)).is_false()
	assert_int(partida.final()).is_equal(Partida.Final.EN_CURSO)


func test_el_final_5_tiene_pantalla_propia() -> void:  # AC-SHF-113
	var partida := _en_la_septima()
	assert_int(FinalConPantalla.de(partida)).is_equal(FinalConPantalla.Cual.NINGUNO)
	partida.abrir_la_oficina_del_jefe(Partida.LLAVE)
	assert_int(FinalConPantalla.de(partida)).is_equal(FinalConPantalla.Cual.JEFE_INCOMPETENTE)
	assert_int(FinalConPantalla.de(partida)).is_not_equal(FinalConPantalla.Cual.JEFE_SABOTEADOR)


func test_el_final_5_borra_el_guardado() -> void:  # AC-SAV-051
	var partida := _en_la_septima()
	assert_int(PoliticaDeGuardado.accion(partida)).is_equal(PoliticaDeGuardado.Accion.ESCRIBIR)
	partida.abrir_la_oficina_del_jefe(Partida.LLAVE)
	assert_int(PoliticaDeGuardado.accion(partida)).is_equal(PoliticaDeGuardado.Accion.BORRAR)
