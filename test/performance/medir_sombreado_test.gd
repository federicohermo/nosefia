extends GdUnitTestSuite

const Medicion := preload("res://test/performance/medir_sombreado.gd")
const ESCENA := preload("res://test/performance/medir_sombreado.tscn")
const CARPETA := "res://src/escenas/objetos/"
const FUENTES: Array[String] = [
	"agua_y_manchas.gdshader", "aspecto_del_agua.gdshaderinc", "aspecto_de_la_mancha.gdshaderinc"
]


func _fuente(archivo: String) -> String:
	return FileAccess.get_file_as_string(CARPETA + archivo)


func test_el_panel_ocupa_la_vista_entera() -> void:
	var escena: Node3D = auto_free(ESCENA.instantiate())
	add_child(escena)
	var camara: Camera3D = escena.get_node("Camara")
	var panel: MeshInstance3D = escena.get_node("Panel")
	var vista := get_viewport().get_visible_rect().size
	var mitad := (panel.mesh as PlaneMesh).size / 2.0
	assert_bool(camara.is_position_behind(panel.global_position)).is_false()
	for esquina: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var punto := panel.to_global(Vector3(esquina.x * mitad.x, 0.0, esquina.y * mitad.y))
		assert_vector(camara.unproject_position(punto)).is_equal_approx(
			(esquina + Vector2.ONE) / 2.0 * vista, Vector2(0.5, 0.5)
		)


func test_cada_caso_dibuja_el_shader_compartido_con_parametros_que_declara() -> void:
	var fuentes := ""
	for archivo: String in FUENTES:
		fuentes += _fuente(archivo)
	var casos := Medicion.casos()
	assert_int(casos.size()).is_greater(0)
	for nombre: String in casos:
		var pintura := Medicion.material_de(casos[nombre])
		assert_object(pintura.shader).is_same(Medicion.ASPECTO)
		for parametro: String in casos[nombre]:
			var declaracion := RegEx.create_from_string("uniform\\s+\\w+\\s+%s\\b" % parametro)
			(
				assert_object(declaracion.search(fuentes))
				. override_failure_message("`%s` no es un parámetro del shader" % parametro)
				. is_not_null()
			)
			assert_that(pintura.get_shader_parameter(parametro)).is_equal(casos[nombre][parametro])


func test_los_casos_de_agua_cubren_malla_mezcla_alfa_cero_y_ondas_de_textura() -> void:
	var casos := Medicion.casos()
	var malla: Dictionary = casos["agua_de_malla"]
	assert_bool(malla["normal_de_la_malla"]).is_true()
	assert_bool(malla.has("ondas")).is_false()
	assert_bool(malla.has("progreso_de_mezcla")).is_false()
	var mezcla: Dictionary = casos["agua_en_mezcla"]
	assert_bool(mezcla["normal_de_la_malla"]).is_true()
	assert_float(mezcla["progreso_de_mezcla"]).is_between(0.1, 0.9)
	assert_bool(mezcla["color_previo"] == mezcla["color_del_agua"]).is_false()
	var sin_color: Dictionary = casos["agua_sin_color"]
	assert_bool(sin_color["normal_de_la_malla"]).is_true()
	assert_float((sin_color["color_del_agua"] as Color).a).is_equal(0.0)
	var bano: Dictionary = casos["agua_del_bano"]
	assert_bool(bano.get("normal_de_la_malla", false)).is_false()
	var textura: Texture2D = bano["ondas"]
	assert_vector(textura.get_size()).is_equal(Vector2.ONE * Medicion.LADO_DE_LAS_ONDAS)
	assert_vector(bano["texel"]).is_equal(Vector2.ONE / Medicion.LADO_DE_LAS_ONDAS)


func test_las_ondas_del_bano_no_son_planas() -> void:
	var ondas := Medicion.ondas()
	assert_int(ondas.get_format()).is_equal(Image.FORMAT_RF)
	var minima := INF
	var maxima := -INF
	for y: int in ondas.get_height():
		for x: int in ondas.get_width():
			minima = minf(minima, ondas.get_pixel(x, y).r)
			maxima = maxf(maxima, ondas.get_pixel(x, y).r)
	assert_float(maxima - minima).is_greater(0.01)


func test_el_agua_lee_las_ondas_solo_sin_normales_de_malla() -> void:
	var fuente := _fuente("aspecto_del_agua.gdshaderinc")
	var desde := fuente.find("if (!normal_de_la_malla) {")
	assert_int(desde).is_greater(-1)
	var rama := fuente.substr(desde, fuente.find("}", desde) - desde)
	for calculo: String in ["texture(ondas", "normal_local"]:
		assert_int(fuente.count(calculo)).is_greater(0)
		(
			assert_int(rama.count(calculo))
			. override_failure_message(
				"`%s` aparece fuera de la rama sin normales de malla" % calculo
			)
			. is_equal(fuente.count(calculo))
		)


func test_los_casos_de_manchas_cubren_polvo_seco_acuoso_alfa_cero_y_los_controles() -> void:
	var casos := Medicion.casos()
	var tipos := {
		"polvo": ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		"polvo_acuoso": ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		"polvo_sin_color": ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		"moho": ReglasDeLaLimpieza.TipoDeMancha.MOHO,
		"caca": ReglasDeLaLimpieza.TipoDeMancha.CACA,
	}
	for nombre: String in tipos:
		var mancha: Dictionary = casos[nombre]
		assert_bool(mancha["es_mancha"]).is_true()
		assert_int(mancha["tipo_de_suciedad"]).is_equal(tipos[nombre])
		assert_object(mancha["guia_de_manchas"]).is_not_null()
	assert_bool(casos["polvo"]["acuosa"]).is_false()
	assert_bool(casos["polvo_acuoso"]["acuosa"]).is_true()
	assert_float(casos["polvo_acuoso"]["transparencia"]).is_less(casos["polvo"]["transparencia"])
	assert_float((casos["polvo"]["color_del_agua"] as Color).a).is_greater(0.0)
	assert_float((casos["polvo_sin_color"]["color_del_agua"] as Color).a).is_equal(0.0)


func test_el_polvo_no_calcula_el_ruido_que_usan_el_moho_y_la_caca() -> void:
	var fuente := _fuente("aspecto_de_la_mancha.gdshaderinc")
	var cortes: Array[int] = [fuente.find("void pintar_mancha(")]
	for rama: String in [
		"if (tipo_de_suciedad == 0) {", "} else if (tipo_de_suciedad == 1) {", "} else {"
	]:
		cortes.append(fuente.find(rama, cortes[-1]))
		assert_int(cortes[-1]).is_greater(cortes[-2])
	var antes_de_elegir := fuente.substr(cortes[0], cortes[1] - cortes[0])
	var moho := fuente.substr(cortes[1], cortes[2] - cortes[1])
	var caca := fuente.substr(cortes[2], cortes[3] - cortes[2])
	var polvo := fuente.substr(cortes[3])
	for tramo: String in [antes_de_elegir, polvo]:
		(
			assert_int(tramo.count("ruido("))
			. override_failure_message("el polvo calcula ruido que no usa:\n" + tramo)
			. is_equal(0)
		)
	for tramo: String in [moho, caca]:
		assert_int(tramo.count("ruido(uv * 12.0)")).is_equal(1)
		assert_int(tramo.count("ruido(uv * 57.0)")).is_equal(1)
