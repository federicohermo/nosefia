extends GdUnitTestSuite


func test_gana_el_primero_libre_en_el_orden() -> void:
	assert_int(Rescate.elegir([false, true, true, true])).is_equal(Rescate.Clase.ALREDEDOR)
	assert_int(Rescate.elegir([true, true, true, true])).is_equal(Rescate.Clase.DESHACER)


func test_el_origen_es_el_ultimo_recurso() -> void:
	assert_int(Rescate.elegir([false, false, false, true])).is_equal(Rescate.Clase.ORIGEN)


func test_sin_ningun_libre_no_hay_eleccion() -> void:
	assert_int(Rescate.elegir([false, false, false, false])).is_equal(Rescate.NINGUNO)
	assert_int(Rescate.elegir([] as Array[bool])).is_equal(Rescate.NINGUNO)


func test_la_racha_termina_en_el_primer_paso_sin_empujon() -> void:
	assert_bool(Rescate.termino_la_racha(false, true)).is_true()


func test_la_racha_sigue_mientras_haya_empujon() -> void:
	assert_bool(Rescate.termino_la_racha(true, true)).is_false()
	assert_bool(Rescate.termino_la_racha(true, false)).is_false()


func test_sin_racha_no_termina_nada() -> void:
	assert_bool(Rescate.termino_la_racha(false, false)).is_false()
