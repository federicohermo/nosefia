extends GdUnitTestSuite

const Ondas := preload("res://src/escenas/objetos/ondas_del_balde.gd")


func test_la_amplitud_sigue_el_campo_tras_avanzar_y_reiniciar() -> void:
	var ondas := Ondas.new()
	assert_float(ondas.amplitud()).is_equal(0.0)
	ondas.perturbar(Vector2(.25, -.15), .07)
	# La perturbación cambia velocidad; las alturas todavía están en reposo.
	assert_float(ondas.amplitud()).is_equal(0.0)
	for cuadro in 10:
		ondas.avanzar(1.0 / 60.0, Vector2(.4, -.2))
		var alturas: PackedFloat32Array = ondas.get("_alturas")
		var mayor := 0.0
		for altura in alturas:
			mayor = maxf(mayor, absf(altura))
		assert_float(mayor).is_greater(0.0)
		for consulta in 3:
			assert_float(ondas.amplitud()).is_equal(mayor)
	ondas.reiniciar()
	assert_float(ondas.amplitud()).is_equal(0.0)
	ondas.avanzar(1.0 / 60.0, Vector2.ZERO)
	assert_float(ondas.amplitud()).is_equal(0.0)
