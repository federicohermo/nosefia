extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/interrupciones/pantalla_de_carga.tscn")


func _pantalla(presentacion: PantallaDeCarga.Presentacion) -> PantallaDeCarga:
	var pantalla: PantallaDeCarga = auto_free(ESCENA.instantiate())
	pantalla.presentacion = presentacion
	var capa: CanvasLayer = auto_free(CanvasLayer.new())
	capa.add_child(pantalla)
	add_child(capa)
	pantalla.mostrar()
	pantalla.pintar(0.5)
	return pantalla


func test_entre_noches_conserva_la_barra_y_la_tipografia_de_la_inicial() -> void:
	var inicial := _pantalla(PantallaDeCarga.Presentacion.INICIAL)
	var entre_noches := _pantalla(PantallaDeCarga.Presentacion.ENTRE_NOCHES)
	await await_idle_frame()
	var barra_inicial: ProgressBar = inicial.find_children("*", "ProgressBar", true, false)[0]
	var barra_entre_noches: ProgressBar = (
		entre_noches.find_children("*", "ProgressBar", true, false)[0]
	)
	assert_vector(barra_entre_noches.get_global_rect().position).is_equal(
		barra_inicial.get_global_rect().position
	)
	assert_vector(barra_entre_noches.get_global_rect().size).is_equal(
		barra_inicial.get_global_rect().size
	)
	var texto_inicial: Label = inicial.find_children("*", "Label", true, false)[0]
	var texto_entre_noches: Label = entre_noches.find_children("*", "Label", true, false)[0]
	assert_object(texto_entre_noches.get_theme_font("font")).is_same(
		texto_inicial.get_theme_font("font")
	)
	assert_int(texto_entre_noches.get_theme_font_size("font_size")).is_equal(
		texto_inicial.get_theme_font_size("font_size")
	)


func test_en_escritorio_los_tres_puntos_laten_y_se_ocultan_con_la_pantalla() -> void:
	var pantalla := _pantalla(PantallaDeCarga.Presentacion.ENTRE_NOCHES)
	await await_idle_frame()
	var puntos: Array[ColorRect] = []
	for rectangulo: ColorRect in pantalla.find_children("*", "ColorRect", true, false):
		if rectangulo.is_visible_in_tree():
			puntos.append(rectangulo)
	assert_int(puntos.size()).is_equal(3)
	if puntos.size() != 3:
		return
	var opacidad := puntos[0].modulate.a
	await await_millis(150)
	assert_float(puntos[0].modulate.a).is_not_equal(opacidad)
	assert_float(puntos[0].modulate.a).is_not_equal(puntos[1].modulate.a)
	pantalla.ocultar()
	for punto: ColorRect in puntos:
		assert_bool(punto.is_visible_in_tree()).is_false()
