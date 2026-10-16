extends GdUnitTestSuite


func test_solo_falta_el_azul_en_la_segunda_jornada() -> void:  # AC-ANO-001
	for jornada in range(1, 6):
		for jabon: StringName in ReglasDeLaLimpieza.JABONES:
			assert_bool(AnomaliasDeLaJornada.util_disponible(jabon, jornada)).is_equal(
				jornada != 2 or jabon != &"jabon_azul"
			)
		assert_bool(AnomaliasDeLaJornada.util_disponible(&"mopa", jornada)).is_true()
		assert_bool(AnomaliasDeLaJornada.util_disponible(&"balde", jornada)).is_true()


func test_la_sustitucion_depende_de_identidad_y_jornada() -> void:  # AC-ANO-004
	var poetico := UnidadDeProducto.new(Catalogo.de(Producto.Id.POETICO))
	var otro := UnidadDeProducto.new(Catalogo.de(Producto.Id.DURONGA))
	otro.nombre = poetico.nombre
	for jornada in range(1, 6):
		assert_bool(AnomaliasDeLaJornada.sustituye_azul(poetico.id, jornada)).is_equal(jornada == 2)
		assert_bool(AnomaliasDeLaJornada.sustituye_azul(otro.id, jornada)).is_false()
		assert_bool(AnomaliasDeLaJornada.sustituye_azul(&"Poético", jornada)).is_false()
	assert_int(ReglasDeLaLimpieza.JABONES.size()).is_equal(3)
