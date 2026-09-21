extends GdUnitTestSuite

const Medicion := preload("res://test/performance/medir_luces.gd")


func test_las_luces_se_reparten_adentro_del_techo_sin_encimarse() -> void:
	for cantidad in Medicion.CANTIDADES:
		var puntos := Medicion.posiciones(cantidad)
		assert_int(puntos.size()).is_equal(cantidad)
		var vistos := {}
		for punto in puntos:
			assert_bool(Medicion.TECHO.has_point(Vector2(punto.x, punto.z))).is_true()
			assert_float(punto.y).is_equal_approx(Medicion.ALTURA, 0.001)
			vistos[punto] = true
		assert_int(vistos.size()).is_equal(cantidad)


func test_cada_caso_crea_la_cantidad_el_tipo_y_la_sombra_que_dice() -> void:
	var clases := {
		Medicion.Tipo.OMNI: "OmniLight3D",
		Medicion.Tipo.SPOT: "SpotLight3D",
		Medicion.Tipo.AREA: "AreaLight3D",
	}
	for tipo: Medicion.Tipo in Medicion.Tipo.values():
		for con_sombra: bool in [false, true]:
			var lote: Node3D = auto_free(Medicion.crear(tipo, 4, con_sombra))
			assert_int(lote.get_child_count()).is_equal(4)
			for luz: Light3D in lote.get_children():
				assert_str(luz.get_class()).is_equal(clases[tipo])
				assert_bool(luz.shadow_enabled).is_equal(con_sombra)
