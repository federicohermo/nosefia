extends GdUnitTestSuite


func _candidatos(libres: Array[bool]) -> Array[Rescate.Candidato]:
	var clases: Array[Rescate.Clase] = [
		Rescate.Clase.DESHACER,
		Rescate.Clase.ALREDEDOR,
		Rescate.Clase.ENCIMA_DEL_ORIGEN,
		Rescate.Clase.ORIGEN,
	]
	var salida: Array[Rescate.Candidato] = []
	for indice in libres.size():
		salida.append(Rescate.Candidato.new(clases[indice], libres[indice]))
	return salida


func test_gana_el_primero_libre_en_el_orden() -> void:
	assert_int(Rescate.elegir(_candidatos([false, true, true, true]))).is_equal(1)
	assert_int(Rescate.elegir(_candidatos([true, true, true, true]))).is_equal(0)


func test_el_origen_es_el_ultimo_recurso() -> void:
	assert_int(Rescate.elegir(_candidatos([false, false, false, true]))).is_equal(3)


func test_sin_ningun_libre_no_hay_eleccion() -> void:
	assert_int(Rescate.elegir(_candidatos([false, false, false, false]))).is_equal(Rescate.NINGUNO)
	assert_int(Rescate.elegir([] as Array[Rescate.Candidato])).is_equal(Rescate.NINGUNO)


func test_la_racha_termina_en_el_primer_paso_sin_empujon() -> void:
	assert_bool(Rescate.termino_la_racha(false, true)).is_true()


func test_la_racha_sigue_mientras_haya_empujon() -> void:
	assert_bool(Rescate.termino_la_racha(true, true)).is_false()
	assert_bool(Rescate.termino_la_racha(true, false)).is_false()


func test_sin_racha_no_termina_nada() -> void:
	assert_bool(Rescate.termino_la_racha(false, false)).is_false()
