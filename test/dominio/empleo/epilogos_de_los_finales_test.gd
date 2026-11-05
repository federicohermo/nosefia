## Las placas del epílogo de cada final: cuántas, en qué orden, con qué fondo y cuáles se muestran.
extends GdUnitTestSuite

const FINALES_CON_EPILOGO: Array[FinalConPantalla.Cual] = [
	FinalConPantalla.Cual.EMPLEADO_ESTRESADO,
	FinalConPantalla.Cual.LOCURA_PARANOICA,
	FinalConPantalla.Cual.JEFE_INCOMPETENTE,
]


func _renglones(placa: EpilogosDeLosFinales.Placa) -> int:
	return placa.texto.split("\n").size()


func test_el_final_1_tiene_seis_placas_con_el_renglonado_de_la_ficha() -> void:  # AC-SHF-134
	var placas := EpilogosDeLosFinales.placas_de(FinalConPantalla.Cual.EMPLEADO_ESTRESADO)
	assert_int(placas.size()).is_equal(6)
	assert_int(_renglones(placas[0])).is_equal(3)
	assert_int(_renglones(placas[1])).is_equal(1)


func test_el_final_2_tiene_dos_placas_con_otro_fondo_que_el_final_1() -> void:  # AC-SHF-135
	var placas := EpilogosDeLosFinales.placas_de(FinalConPantalla.Cual.LOCURA_PARANOICA)
	assert_int(placas.size()).is_equal(2)
	assert_int(_renglones(placas[0])).is_equal(2)
	var del_final_1 := EpilogosDeLosFinales.placas_de(FinalConPantalla.Cual.EMPLEADO_ESTRESADO)
	assert_object(placas[0].fondo).is_not_same(del_final_1[0].fondo)


func test_el_final_5_tiene_siete_placas() -> void:  # AC-SHF-136
	var placas := EpilogosDeLosFinales.placas_de(FinalConPantalla.Cual.JEFE_INCOMPETENTE)
	assert_int(placas.size()).is_equal(7)
	assert_int(_renglones(placas[0])).is_equal(2)
	assert_int(_renglones(placas[6])).is_equal(2)


func test_las_placas_de_un_final_comparten_fondo_y_cada_placa_trae_texto() -> void:  # AC-SHF-134
	for final in FINALES_CON_EPILOGO:
		var placas := EpilogosDeLosFinales.placas_de(final)
		for placa in placas:
			assert_object(placa.fondo).is_not_null()
			assert_object(placa.fondo).is_same(placas[0].fondo)
			assert_str(placa.texto).is_not_empty()


func test_cada_final_usa_su_propio_fondo() -> void:  # AC-SHF-135
	var fondos: Array[Texture2D] = []
	for final in FINALES_CON_EPILOGO:
		var fondo := EpilogosDeLosFinales.placas_de(final)[0].fondo
		assert_array(fondos).not_contains([fondo])
		fondos.append(fondo)


func test_el_final_4_sin_texto_no_tiene_epilogo() -> void:  # AC-SHF-137
	assert_array(EpilogosDeLosFinales.placas_de(FinalConPantalla.Cual.JEFE_SABOTEADOR)).is_empty()


func test_el_despido_y_la_partida_en_curso_no_tienen_epilogo() -> void:  # AC-SHF-137
	assert_array(EpilogosDeLosFinales.placas_de(FinalConPantalla.Cual.DESPEDIDO)).is_empty()
	assert_array(EpilogosDeLosFinales.placas_de(FinalConPantalla.Cual.NINGUNO)).is_empty()


func test_una_placa_sin_texto_no_se_muestra() -> void:  # AC-SHF-137
	var fondo := EpilogosDeLosFinales.FONDO_DEL_FINAL_1
	var placas := EpilogosDeLosFinales.con_texto(fondo, ["uno", "", "tres"])
	assert_int(placas.size()).is_equal(2)
	assert_str(placas[0].texto).is_equal("uno")
	assert_str(placas[1].texto).is_equal("tres")
	assert_array(EpilogosDeLosFinales.con_texto(fondo, ["", ""])).is_empty()
