extends GdUnitTestSuite


func test_umbral_y_exigencias_se_cumplen_simultaneamente() -> void:  # AC-INV-045
	var final := Desenlace.new()
	final.identidad = "prueba"
	final.umbral = 2
	final.exigencias = PackedStringArray(["C"])
	assert_bool(final.alcanzado_por(PackedStringArray(["A"]))).is_false()
	assert_bool(final.alcanzado_por(PackedStringArray(["A", "B"]))).is_false()
	assert_bool(final.alcanzado_por(PackedStringArray(["C"]))).is_false()
	assert_bool(final.alcanzado_por(PackedStringArray(["A", "C"]))).is_true()
	final.exigencias.clear()
	assert_bool(final.alcanzado_por(PackedStringArray(["A", "B"]))).is_true()
