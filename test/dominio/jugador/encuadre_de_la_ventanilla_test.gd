## La perspectiva depende del hueco, del campo vertical y del aspecto, sin una escena.
extends GdUnitTestSuite


func test_los_tres_aspectos_encuadran_el_marco_visible() -> void:  # AC-PLY-058
	for aspecto: float in [16.0 / 9.0, 16.0 / 10.0, 4.0 / 3.0]:
		var tamano := Vector2(1.4, 1.36)
		var distancia := EncuadreDeLaVentanilla.distancia(tamano, 0.18, 75.0, aspecto)
		assert_float(distancia).is_equal_approx(0.88619326285, 0.00001)
		assert_float(EncuadreDeLaVentanilla.elevacion(tamano, 0.18, distancia)).is_equal_approx(
			0.06905942891, 0.00001
		)


func test_el_alto_del_hueco_cuadrado_limita_en_pantallas_apaisadas() -> void:  # AC-PLY-058
	for aspecto: float in [16.0 / 9.0, 16.0 / 10.0, 4.0 / 3.0]:
		(
			assert_float(EncuadreDeLaVentanilla.distancia(Vector2(1.4, 1.4), 0.0, 75.0, aspecto))
			. is_equal_approx(0.91225776099, 0.000001)
		)


func test_el_ancho_de_un_hueco_ancho_limita_la_distancia() -> void:  # AC-PLY-058
	(
		assert_float(EncuadreDeLaVentanilla.distancia(Vector2(3.0, 1.0), 0.0, 90.0, 4.0 / 3.0))
		. is_equal_approx(1.125, 0.000001)
	)
	(
		assert_float(EncuadreDeLaVentanilla.distancia(Vector2(3.0, 1.0), 0.0, 90.0, 3.0 / 4.0))
		. is_equal_approx(2.0, 0.000001)
	)


func test_los_bordes_a_distinta_profundidad_se_encuadran_juntos() -> void:  # AC-PLY-058
	# Dintel medio metro delante y antepecho medio metro detrás: el alto limita.
	var tamano := Vector2(2.0, 4.0)
	var distancia := EncuadreDeLaVentanilla.distancia(tamano, 1.0, 90.0, 2.0)
	assert_float(distancia).is_equal_approx(2.0, 0.000001)
	assert_float(EncuadreDeLaVentanilla.elevacion(tamano, 1.0, distancia)).is_equal_approx(
		0.5, 0.000001
	)
	# En una pantalla angosta, los laterales cercanos limitan y cambia la elevación.
	distancia = EncuadreDeLaVentanilla.distancia(tamano, 1.0, 90.0, 0.25)
	assert_float(distancia).is_equal_approx(4.5, 0.000001)
	assert_float(EncuadreDeLaVentanilla.elevacion(tamano, 1.0, distancia)).is_equal_approx(
		2.0 / 9.0, 0.000001
	)


func test_un_dato_no_positivo_no_pide_mover_la_camara() -> void:  # AC-PLY-058
	for valor: float in [0.0, -1.0]:
		(
			assert_float(
				EncuadreDeLaVentanilla.distancia(Vector2(valor, 1.4), 0.0, 75.0, 16.0 / 9.0)
			)
			. is_equal(0.0)
		)
		(
			assert_float(
				EncuadreDeLaVentanilla.distancia(Vector2(1.4, valor), 0.0, 75.0, 16.0 / 9.0)
			)
			. is_equal(0.0)
		)
		(
			assert_float(
				EncuadreDeLaVentanilla.distancia(Vector2(1.4, 1.4), 0.0, valor, 16.0 / 9.0)
			)
			. is_equal(0.0)
		)
		(
			assert_float(EncuadreDeLaVentanilla.distancia(Vector2(1.4, 1.4), 0.0, 75.0, valor))
			. is_equal(0.0)
		)
		assert_float(EncuadreDeLaVentanilla.elevacion(Vector2.ONE, 0.0, valor)).is_equal(0.0)
	assert_float(EncuadreDeLaVentanilla.distancia(Vector2.ONE, -1.0, 90.0, 1.0)).is_equal(0.0)
	for campo: float in [180.0, 181.0]:
		assert_float(EncuadreDeLaVentanilla.distancia(Vector2.ONE, 0.0, campo, 1.0)).is_equal(0.0)
	assert_float(EncuadreDeLaVentanilla.elevacion(Vector2.ONE, -1.0, 1.0)).is_equal(0.0)
