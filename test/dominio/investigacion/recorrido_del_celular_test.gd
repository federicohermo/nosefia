## El resorte del celular, contestado sin levantar una escena.
extends GdUnitTestSuite


func _recorrido_hacia(destino: float) -> RecorridoDelCelular:
	var recorrido := RecorridoDelCelular.new()
	recorrido.ir_a(destino)
	return recorrido


func _recorrer(recorrido: RecorridoDelCelular, cuadros: int) -> Array[float]:
	var posiciones: Array[float] = []
	for cuadro in cuadros:
		recorrido.avanzar(RecorridoDelCelular.DURACION / cuadros)
		posiciones.append(recorrido.posicion())
	return posiciones


func test_al_subir_pasa_del_centro_y_se_asienta_a_tiempo() -> void:  # AC-INV-073
	var recorrido := _recorrido_hacia(1.0)
	var posiciones := _recorrer(recorrido, 50)
	assert_float(posiciones.max()).is_greater(1.0)
	assert_float(posiciones.max()).is_less(1.2)
	assert_bool(recorrido.llego()).is_true()
	assert_float(recorrido.posicion()).is_equal(1.0)


func test_no_llega_antes_de_su_duracion() -> void:  # AC-INV-073
	var recorrido := _recorrido_hacia(1.0)
	recorrido.avanzar(RecorridoDelCelular.DURACION - 0.001)
	assert_bool(recorrido.llego()).is_false()
	recorrido.avanzar(0.001)
	assert_bool(recorrido.llego()).is_true()


func test_al_bajar_usa_el_mismo_resorte_y_termina_en_el_margen_inferior() -> void:  # AC-INV-073
	var recorrido := _recorrido_hacia(1.0)
	recorrido.avanzar(RecorridoDelCelular.DURACION)
	recorrido.ir_a(0.0)
	var posiciones := _recorrer(recorrido, 50)
	assert_float(posiciones.min()).is_less(0.0)
	assert_float(posiciones.min()).is_greater(-0.2)
	assert_float(posiciones.max()).is_less(1.0)
	assert_bool(recorrido.llego()).is_true()
	assert_float(recorrido.posicion()).is_equal(0.0)


func test_invertir_a_mitad_de_la_subida_parte_de_la_posicion_actual() -> void:  # AC-INV-073
	var recorrido := _recorrido_hacia(1.0)
	recorrido.avanzar(RecorridoDelCelular.DURACION / 2.0)
	var actual := recorrido.posicion()
	recorrido.ir_a(0.0)
	assert_float(recorrido.posicion()).is_equal(actual)
	assert_float(recorrido.destino()).is_equal(0.0)
	assert_bool(recorrido.llego()).is_false()


func test_un_recorrido_corto_dura_proporcionalmente_menos() -> void:  # AC-INV-073
	var recorrido := _recorrido_hacia(1.0)
	recorrido.avanzar(RecorridoDelCelular.DURACION / 10.0)
	recorrido.ir_a(0.0)
	recorrido.avanzar(RecorridoDelCelular.DURACION / 2.0)
	assert_bool(recorrido.llego()).is_true()


func test_un_recorrido_sin_empezar_esta_abajo_y_ya_llego() -> void:  # AC-INV-073
	var recorrido := RecorridoDelCelular.new()
	assert_float(recorrido.posicion()).is_equal(0.0)
	assert_bool(recorrido.llego()).is_true()
