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


func test_ninguna_presentacion_retrocede_si_la_estimacion_baja() -> void:
	for presentacion: PantallaDeCarga.Presentacion in PantallaDeCarga.Presentacion.values():
		var pantalla := _pantalla(presentacion)
		var barra: ProgressBar = pantalla.find_children("*", "ProgressBar", true, false)[0]
		var anterior := barra.value
		for progreso: float in [0.7, 0.3, 0.8, 0.6, 0.9, 0.0, 1.0]:
			pantalla.pintar(progreso)
			assert_float(barra.value).is_greater_equal(anterior)
			anterior = barra.value
		assert_float(barra.value).is_equal(barra.max_value)


func test_cada_carga_comienza_de_cero_aunque_la_anterior_haya_terminado() -> void:
	for presentacion: PantallaDeCarga.Presentacion in PantallaDeCarga.Presentacion.values():
		var pantalla := _pantalla(presentacion)
		var barra: ProgressBar = pantalla.find_children("*", "ProgressBar", true, false)[0]
		pantalla.pintar(1.0)
		pantalla.ocultar()
		pantalla.mostrar()
		assert_float(barra.value).is_equal(barra.min_value)
		pantalla.pintar(0.3)
		assert_float(barra.value).is_greater(barra.min_value).is_less(barra.max_value)


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
