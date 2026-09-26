## Cuáles emisores del ambiente suenan, según la distancia al jugador y el tope.
extends GdUnitTestSuite


func test_suenan_los_mas_cercanos_hasta_el_tope() -> void:  # AC-AMB-017
	assert_array(EmisoresDelAmbiente.que_suenan([5.0, 1.0, 3.0], 2)).is_equal([1, 2])


func test_justo_en_el_tope_suenan_todos() -> void:  # AC-AMB-017
	assert_array(EmisoresDelAmbiente.que_suenan([5.0, 1.0, 3.0], 3)).is_equal([0, 1, 2])


func test_un_empate_en_el_borde_elige_siempre_el_primero() -> void:  # AC-AMB-017
	var distancias: Array[float] = [4.0, 1.0, 4.0]
	assert_array(EmisoresDelAmbiente.que_suenan(distancias, 2)).is_equal([0, 1])
	assert_array(EmisoresDelAmbiente.que_suenan(distancias, 2)).is_equal([0, 1])


func test_sin_emisores_no_suena_ninguno() -> void:  # AC-AMB-017
	assert_array(EmisoresDelAmbiente.que_suenan([], 3)).is_empty()
	assert_array(EmisoresDelAmbiente.que_suenan([2.0], 0)).is_empty()


func test_el_tope_del_local_deja_sonar_alguno() -> void:
	assert_int(EmisoresDelAmbiente.TOPE).is_greater(0)
	assert_float(EmisoresDelAmbiente.VOLUMEN_DB).is_less(0.0)
	assert_float(EmisoresDelAmbiente.ALCANCE).is_greater(0.0)
