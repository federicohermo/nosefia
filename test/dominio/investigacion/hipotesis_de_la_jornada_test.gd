extends GdUnitTestSuite


func _opcion(identidad: String, exigencias: PackedStringArray) -> Hipotesis:
	var opcion := Hipotesis.new()
	opcion.identidad = identidad
	opcion.jornada = 2
	opcion.exigencias = exigencias
	return opcion


func test_predeterminada_solo_si_ninguna_opcion_esta_habilitada() -> void:  # AC-INV-050
	var jornada := HipotesisDeLaJornada.new()
	jornada.jornada = 2
	var a := _opcion("2A", PackedStringArray(["2A"]))
	var b := _opcion("2B", PackedStringArray(["2B"]))
	var predeterminada := _opcion("2P", PackedStringArray())
	jornada.opciones = [a, b]
	jornada.predeterminada = predeterminada
	assert_array(jornada.disponibles(PackedStringArray())).is_equal([predeterminada])
	assert_array(jornada.disponibles(PackedStringArray(["2A"]))).is_equal([a])
	assert_array(jornada.disponibles(PackedStringArray(["2B"]))).is_equal([b])
	assert_array(jornada.disponibles(PackedStringArray(["2B", "2A"]))).is_equal([a, b])
	var copia := jornada.disponibles(PackedStringArray(["2A", "2B"]))
	copia.reverse()
	copia.clear()
	assert_array(jornada.opciones).is_equal([a, b])
	assert_array(jornada.disponibles(PackedStringArray(["2A", "2B"]))).is_equal([a, b])


func test_jornada_sin_guion_no_inventa_una_opcion() -> void:  # AC-INV-050
	var jornada := HipotesisDeLaJornada.new()
	jornada.jornada = 1
	assert_array(jornada.disponibles(PackedStringArray())).is_empty()
