## Qué final con pantalla alcanzó la partida, y a dónde lleva la opción de su devolución.
extends GdUnitTestSuite

const CondicionesDelJefeTest := preload("res://test/dominio/empleo/condiciones_del_jefe_test.gd")
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
## Las hipótesis de la jornada 4 sin ninguna pista: sólo se ofrece la que dice que no hubo.
const JORNADA_DE_LA_HIPOTESIS := 4
const HIPOTESIS_SIN_PISTA := "2P"


func _jugar(partida: Partida, cumplidas: int) -> void:
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias().slice(0, cumplidas):
		tarea.completar()
	partida.cerrar_la_jornada(cumplidas)


func _impecable(partida: Partida) -> void:
	_jugar(partida, Apertura.cantidad_de_obligatorias(partida.jornada()))


func _contrato_cumplido() -> Partida:
	var partida := Partida.nueva()
	for _jornada in range(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		_impecable(partida)
	return partida


func _despedida_en_jornada_completa() -> Partida:
	var partida := Partida.desde({"jornada": COMPLETA})
	_jugar(partida, 0)
	_jugar(partida, 0)
	return partida


func _opcion_de(partida: Partida) -> Array[DevolucionDelJefe.Opcion]:
	return DevolucionDelJefe.new(partida.jornada(), partida).opciones()


func test_el_despido_en_una_jornada_completa_tiene_su_pantalla() -> void:  # AC-SHF-063
	var partida := _despedida_en_jornada_completa()
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)
	assert_int(FinalConPantalla.de(partida)).is_equal(FinalConPantalla.Cual.DESPEDIDO)
	assert_array(_opcion_de(partida)).is_equal([DevolucionDelJefe.Opcion.VER_EL_FINAL])


func test_el_despido_de_la_prueba_tiene_su_pantalla() -> void:  # AC-SHF-063
	var todo: Array[Tarea.Tipo] = [Tarea.Tipo.REGISTRAR, Tarea.Tipo.REPONER]
	var perdida := CondicionesDelJefeTest.cerrar_la_prueba([[2, todo], [2, todo]])
	assert_int(perdida.final()).is_equal(Partida.Final.DESPEDIDO)
	assert_bool(perdida.jornada() < COMPLETA).is_true()
	assert_int(FinalConPantalla.de(perdida)).is_equal(FinalConPantalla.Cual.DESPEDIDO)
	assert_array(_opcion_de(perdida)).is_equal([DevolucionDelJefe.Opcion.VER_EL_FINAL])


func test_el_contrato_cumplido_sin_pistas_es_empleado_estresado() -> void:  # AC-SHF-064, AC-INV-127
	var partida := _contrato_cumplido()
	assert_int(partida.final()).is_equal(Partida.Final.CONTRATO_CUMPLIDO)
	assert_int(FinalConPantalla.de(partida)).is_equal(FinalConPantalla.Cual.EMPLEADO_ESTRESADO)
	assert_array(_opcion_de(partida)).is_equal([DevolucionDelJefe.Opcion.VER_EL_FINAL])


func test_elegir_una_hipotesis_sin_pista_no_cuenta_como_pista() -> void:  # AC-INV-127
	var partida := Partida.nueva()
	var elegida := partida.expediente.elegir(JORNADA_DE_LA_HIPOTESIS, HIPOTESIS_SIN_PISTA)
	assert_int(elegida).is_equal(Expediente.Resultado.ANOTADA)
	for _jornada in range(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		_impecable(partida)
	assert_int(FinalConPantalla.de(partida)).is_equal(FinalConPantalla.Cual.EMPLEADO_ESTRESADO)


func test_una_sola_pista_lleva_al_final_2() -> void:  # AC-SHF-066, AC-INV-190
	var partida := Partida.nueva()
	assert_int(partida.expediente.registrar("2A")).is_equal(Expediente.Resultado.ANOTADA)
	for _jornada in range(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		_impecable(partida)
	assert_int(partida.final()).is_equal(Partida.Final.LOCURA_PARANOICA)
	assert_int(FinalConPantalla.de(partida)).is_equal(FinalConPantalla.Cual.LOCURA_PARANOICA)
	assert_array(_opcion_de(partida)).is_equal([DevolucionDelJefe.Opcion.VER_EL_FINAL])


func test_la_pista_de_la_ultima_jornada_tambien_lleva_al_final_2() -> void:  # AC-INV-190
	var partida := Partida.nueva()
	for _jornada in range(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1):
		_impecable(partida)
	partida.expediente.registrar("2A")
	_impecable(partida)
	assert_int(partida.final()).is_equal(Partida.Final.LOCURA_PARANOICA)
	assert_int(FinalConPantalla.de(partida)).is_equal(FinalConPantalla.Cual.LOCURA_PARANOICA)


func test_el_despido_en_la_ultima_jornada_gana_sobre_el_final_2() -> void:  # AC-INV-191
	var partida := Partida.nueva()
	partida.expediente.registrar("2A")
	for _jornada in range(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 2):
		_impecable(partida)
	_jugar(partida, 0)
	_jugar(partida, 0)
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)
	assert_int(FinalConPantalla.de(partida)).is_equal(FinalConPantalla.Cual.DESPEDIDO)


func test_el_despido_gana_sobre_la_falta_de_pistas() -> void:  # AC-SHF-065, AC-INV-128
	var partida := _despedida_en_jornada_completa()
	assert_array(Array(partida.expediente.identidades())).is_empty()
	assert_int(FinalConPantalla.de(partida)).is_equal(FinalConPantalla.Cual.DESPEDIDO)


func test_el_despido_con_pistas_tiene_la_pantalla_del_despido() -> void:  # AC-SHF-063
	var partida := Partida.desde({"jornada": COMPLETA})
	partida.expediente.registrar("2A")
	_jugar(partida, 0)
	_jugar(partida, 0)
	assert_int(FinalConPantalla.de(partida)).is_equal(FinalConPantalla.Cual.DESPEDIDO)


func test_una_partida_en_curso_no_tiene_final() -> void:  # AC-SHF-066, AC-INV-190
	var partida := Partida.nueva()
	partida.expediente.registrar("2A")
	_impecable(partida)
	assert_bool(partida.terminada()).is_false()
	assert_int(FinalConPantalla.de(partida)).is_equal(FinalConPantalla.Cual.NINGUNO)
	assert_array(_opcion_de(partida)).is_equal([DevolucionDelJefe.Opcion.CONTINUAR])


func _azar(semilla: int) -> RandomNumberGenerator:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	return azar


func test_el_despido_muestra_un_tip_y_con_el_tiempo_sale_cada_uno() -> void:  # AC-SHF-124
	var vistos: Dictionary[String, bool] = {}
	var azar := _azar(827)
	for _vez in range(200):
		var mensaje := FinalConPantalla.mensaje(FinalConPantalla.Cual.DESPEDIDO, azar)
		assert_array(FinalConPantalla.TIPS).contains([mensaje])
		vistos[mensaje] = true
	assert_int(vistos.size()).is_equal(FinalConPantalla.TIPS.size())


func test_los_finales_1_y_2_muestran_su_cierre_y_ningun_tip() -> void:  # AC-SHF-125
	for final: FinalConPantalla.Cual in FinalConPantalla.CIERRES:
		for semilla: int in [1, 2, 3]:
			var mensaje := FinalConPantalla.mensaje(final, _azar(semilla))
			assert_str(mensaje).is_equal(FinalConPantalla.CIERRES[final])
			assert_str(mensaje).is_not_empty()
			assert_array(FinalConPantalla.TIPS).not_contains([mensaje])
	(
		assert_array(FinalConPantalla.CIERRES.keys())
		. contains_exactly_in_any_order(
			[
				FinalConPantalla.Cual.EMPLEADO_ESTRESADO,
				FinalConPantalla.Cual.LOCURA_PARANOICA,
				FinalConPantalla.Cual.JEFE_SABOTEADOR,
				FinalConPantalla.Cual.JEFE_INCOMPETENTE,
			]
		)
	)
	var cierre_del_1 := FinalConPantalla.CIERRES[FinalConPantalla.Cual.EMPLEADO_ESTRESADO]
	assert_int(cierre_del_1.split("\n").size()).is_equal(2)


func test_los_finales_4_y_5_muestran_su_cierre_y_ningun_tip() -> void:  # AC-SHF-141
	var cierres: Array[String] = []
	for final: FinalConPantalla.Cual in [
		FinalConPantalla.Cual.JEFE_SABOTEADOR, FinalConPantalla.Cual.JEFE_INCOMPETENTE
	]:
		var primero := FinalConPantalla.mensaje(final, _azar(827))
		assert_str(primero).is_not_empty()
		assert_array(FinalConPantalla.TIPS).not_contains([primero])
		for semilla: int in [1, 2, 3]:
			assert_str(FinalConPantalla.mensaje(final, _azar(semilla))).is_equal(primero)
		cierres.append(primero)
	assert_str(cierres[0]).is_not_equal(cierres[1])
