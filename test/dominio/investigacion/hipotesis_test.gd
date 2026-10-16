extends GdUnitTestSuite


func test_las_exigencias_de_una_opcion_se_cumplen_juntas() -> void:  # AC-INV-050
	var opcion := Hipotesis.new()
	opcion.identidad = "A"
	opcion.exigencias = PackedStringArray(["A", "B"])
	assert_bool(opcion.habilitada_por(PackedStringArray())).is_false()
	assert_bool(opcion.habilitada_por(PackedStringArray(["A"]))).is_false()
	assert_bool(opcion.habilitada_por(PackedStringArray(["B", "A"]))).is_true()
	assert_str(opcion.identidad).is_equal("A")
	assert_array(Array(opcion.exigencias)).is_equal(["A", "B"])
