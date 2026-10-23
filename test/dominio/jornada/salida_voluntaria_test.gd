extends GdUnitTestSuite


func _pose(yaw: float, inclinacion: float, lugar: Vector3 = Vector3.ZERO) -> PoseDeLaVista:
	return PoseDeLaVista.new(lugar, Vector2(yaw, inclinacion))


func test_gira_antes_de_esperar_la_hoja_y_termina_una_vez() -> void:  # AC-SHF-043
	var salida := SalidaVoluntaria.new()
	assert_bool(salida.iniciar(_pose(1.0, 0.5), _pose(0.0, 0.0))).is_true()
	assert_int(salida.etapa()).is_equal(SalidaVoluntaria.Etapa.GIRANDO)
	assert_bool(salida.confirmar_apertura()).is_false()
	salida.avanzar(SalidaVoluntaria.DURACION_DEL_GIRO * 0.5)
	assert_int(salida.etapa()).is_equal(SalidaVoluntaria.Etapa.GIRANDO)
	assert_vector(salida.pose().orientacion).is_equal(Vector2(0.5, 0.25))
	salida.avanzar(100.0)
	assert_int(salida.etapa()).is_equal(SalidaVoluntaria.Etapa.ABRIENDO)
	assert_vector(salida.pose().orientacion).is_equal(Vector2.ZERO)
	salida.avanzar(100.0)
	assert_int(salida.etapa()).is_equal(SalidaVoluntaria.Etapa.ABRIENDO)
	assert_bool(salida.confirmar_apertura()).is_true()
	assert_int(salida.etapa()).is_equal(SalidaVoluntaria.Etapa.TERMINADA)
	assert_bool(salida.confirmar_apertura()).is_false()
	assert_bool(salida.iniciar(_pose(0.0, 0.0), _pose(1.0, 1.0))).is_false()


func test_cruza_los_180_grados_por_el_camino_de_dos_grados() -> void:  # AC-SHF-044
	for sentido: float in [-1.0, 1.0]:
		var salida := SalidaVoluntaria.new()
		var desde := deg_to_rad(179.0) * sentido
		salida.iniciar(_pose(desde, 0.7), _pose(-desde, -0.3))
		salida.avanzar(SalidaVoluntaria.DURACION_DEL_GIRO * 0.5)
		var recorrido := wrapf(salida.pose().orientacion.x - desde, -PI, PI)
		assert_float(rad_to_deg(recorrido)).is_equal_approx(sentido, 0.0001)
		assert_float(salida.pose().orientacion.y).is_equal_approx(0.2, 0.0001)


func test_suaviza_ambos_angulos_sin_sobrepasar_ni_avanzar_tiempo_negativo() -> void:  # AC-SHF-044
	var salida := SalidaVoluntaria.new()
	salida.iniciar(_pose(0.0, 0.0), _pose(PI, 1.0))
	salida.avanzar(-1.0)
	salida.avanzar(0.0)
	assert_vector(salida.pose().orientacion).is_equal(Vector2.ZERO)
	var pasos: Array[Vector2] = [salida.pose().orientacion]
	for _paso in 4:
		salida.avanzar(SalidaVoluntaria.DURACION_DEL_GIRO * 0.25)
		pasos.append(salida.pose().orientacion)
	for indice in range(1, pasos.size()):
		assert_float(absf(pasos[indice].x)).is_between(absf(pasos[indice - 1].x), PI)
		assert_float(pasos[indice].y).is_between(pasos[indice - 1].y, 1.0)
	assert_float(absf(pasos[1].x - pasos[0].x)).is_less(absf(pasos[2].x - pasos[1].x))
	assert_float(pasos[4].y - pasos[3].y).is_less(pasos[3].y - pasos[2].y)


func test_repetir_salida_no_cambia_la_vista_ni_reinicia_el_tiempo() -> void:  # AC-SHF-046
	var salida := SalidaVoluntaria.new()
	salida.iniciar(_pose(0.0, 0.0), _pose(1.0, 1.0))
	salida.avanzar(SalidaVoluntaria.DURACION_DEL_GIRO * 0.5)
	assert_bool(salida.iniciar(_pose(2.0, 1.0), _pose(0.0, 0.0))).is_false()
	assert_vector(salida.pose().orientacion).is_equal(Vector2(0.5, 0.5))
	salida.avanzar(SalidaVoluntaria.DURACION_DEL_GIRO * 0.5)
	assert_int(salida.etapa()).is_equal(SalidaVoluntaria.Etapa.ABRIENDO)


func test_traslada_la_posicion_con_suavizado_y_termina_en_la_pose_pedida() -> void:  # AC-SHF-047
	var salida := SalidaVoluntaria.new()
	var desde := Vector3(2.0, 0.1, 5.0)
	var hacia := Vector3(-3.0, 0.1, 1.0)
	salida.iniciar(_pose(0.3, 0.0, desde), _pose(-1.2, 0.0, hacia))
	assert_vector(salida.pose().posicion).is_equal(desde)
	var recorridos: Array[float] = []
	var anterior := desde
	for _paso in 4:
		salida.avanzar(SalidaVoluntaria.DURACION_DEL_GIRO * 0.25)
		var ahora := salida.pose().posicion
		recorridos.append(ahora.distance_to(anterior))
		anterior = ahora
	assert_float(recorridos[0]).is_less(recorridos[1])
	assert_float(recorridos[3]).is_less(recorridos[2])
	assert_vector(salida.pose().posicion).is_equal_approx(hacia, Vector3.ONE * 0.0001)
	assert_float(salida.pose().orientacion.x).is_equal_approx(-1.2, 0.0001)
