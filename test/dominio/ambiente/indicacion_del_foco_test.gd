extends GdUnitTestSuite


func test_la_indicacion_tiene_medidas_visibles_y_colores_distintos() -> void:  # 039-AC6
	assert_float(IndicacionDelFoco.GROSOR).is_greater(0.0)
	assert_float(IndicacionDelFoco.TAMANO_DE_MIRA).is_greater(0.0)
	assert_bool(IndicacionDelFoco.COLOR != IndicacionDelFoco.COLOR_SIN_FOCO).is_true()
	assert_float(IndicacionDelFoco.COLOR.a).is_equal(1.0)
