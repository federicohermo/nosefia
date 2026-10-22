extends GdUnitTestSuite


func test_gira_antes_de_esperar_la_hoja_y_termina_una_vez() -> void:  # AC-SHF-043
	var salida := SalidaVoluntaria.new()
	assert_bool(salida.iniciar(Vector2(1.0, 0.5), Vector2.ZERO)).is_true()
	assert_int(salida.etapa()).is_equal(SalidaVoluntaria.Etapa.GIRANDO)
	assert_bool(salida.confirmar_apertura()).is_false()
	salida.avanzar(SalidaVoluntaria.DURACION_DEL_GIRO * 0.5)
	assert_int(salida.etapa()).is_equal(SalidaVoluntaria.Etapa.GIRANDO)
	assert_vector(salida.orientacion()).is_equal(Vector2(0.5, 0.25))
	salida.avanzar(100.0)
	assert_int(salida.etapa()).is_equal(SalidaVoluntaria.Etapa.ABRIENDO)
	assert_vector(salida.orientacion()).is_equal(Vector2.ZERO)
	salida.avanzar(100.0)
	assert_int(salida.etapa()).is_equal(SalidaVoluntaria.Etapa.ABRIENDO)
	assert_bool(salida.confirmar_apertura()).is_true()
	assert_int(salida.etapa()).is_equal(SalidaVoluntaria.Etapa.TERMINADA)
	assert_bool(salida.confirmar_apertura()).is_false()
	assert_bool(salida.iniciar(Vector2.ZERO, Vector2.ONE)).is_false()


func test_cruza_los_180_grados_por_el_camino_de_dos_grados() -> void:  # AC-SHF-044
	for sentido: float in [-1.0, 1.0]:
		var salida := SalidaVoluntaria.new()
		var desde := deg_to_rad(179.0) * sentido
		salida.iniciar(Vector2(desde, 0.7), Vector2(-desde, -0.3))
		salida.avanzar(SalidaVoluntaria.DURACION_DEL_GIRO * 0.5)
		var recorrido := wrapf(salida.orientacion().x - desde, -PI, PI)
		assert_float(rad_to_deg(recorrido)).is_equal_approx(sentido, 0.0001)
		assert_float(salida.orientacion().y).is_equal_approx(0.2, 0.0001)


func test_suaviza_ambos_angulos_sin_sobrepasar_ni_avanzar_tiempo_negativo() -> void:  # AC-SHF-044
	var salida := SalidaVoluntaria.new()
	salida.iniciar(Vector2.ZERO, Vector2(PI, 1.0))
	salida.avanzar(-1.0)
	salida.avanzar(0.0)
	assert_vector(salida.orientacion()).is_equal(Vector2.ZERO)
	var pasos: Array[Vector2] = [salida.orientacion()]
	for _paso in 4:
		salida.avanzar(SalidaVoluntaria.DURACION_DEL_GIRO * 0.25)
		pasos.append(salida.orientacion())
	for indice in range(1, pasos.size()):
		assert_float(absf(pasos[indice].x)).is_between(absf(pasos[indice - 1].x), PI)
		assert_float(pasos[indice].y).is_between(pasos[indice - 1].y, 1.0)
	assert_float(absf(pasos[1].x - pasos[0].x)).is_less(absf(pasos[2].x - pasos[1].x))
	assert_float(pasos[4].y - pasos[3].y).is_less(pasos[3].y - pasos[2].y)


func test_repetir_salida_no_cambia_la_vista_ni_reinicia_el_tiempo() -> void:  # AC-SHF-046
	var salida := SalidaVoluntaria.new()
	salida.iniciar(Vector2.ZERO, Vector2.ONE)
	salida.avanzar(SalidaVoluntaria.DURACION_DEL_GIRO * 0.5)
	assert_bool(salida.iniciar(Vector2(2.0, 1.0), Vector2.ZERO)).is_false()
	assert_vector(salida.orientacion()).is_equal(Vector2(0.5, 0.5))
	salida.avanzar(SalidaVoluntaria.DURACION_DEL_GIRO * 0.5)
	assert_int(salida.etapa()).is_equal(SalidaVoluntaria.Etapa.ABRIENDO)
