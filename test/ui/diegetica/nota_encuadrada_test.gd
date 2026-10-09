extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/nota_encuadrada.tscn")


func test_el_corcho_muestra_su_dato_y_cambia_de_hoja() -> void:  # AC-PLY-068, AC-PLY-069
	var vista: NotaEncuadrada = auto_free(ESCENA.instantiate())
	add_child(vista)
	assert_bool(vista.visible).is_false()
	var ordenado := NotaPegada.de(NotaPegada.Id.LOCAL_ORDENADO)
	vista.mostrar(ordenado, null)
	assert_bool(vista.visible).is_true()
	assert_bool((vista.get("_papel") as Control).visible).is_true()
	assert_bool((vista.get("_imagen") as TextureRect).visible).is_false()
	assert_str((vista.get("_titulo") as Label).text).is_equal(ordenado.titulo())
	assert_str((vista.get("_renglones") as Label).text).is_equal(
		(
			"• No dejar productos tirados.\n• Dejar las cajas en el depósito.\n"
			+ "• Dejar los elementos de limpieza en el baño."
		)
	)
	var tareas := NotaPegada.tareas_a_realizar(
		[Tarea.new(Tarea.Tipo.REPONER), Tarea.new(Tarea.Tipo.CAJA)]
	)
	vista.mostrar(tareas, null)
	assert_str((vista.get("_titulo") as Label).text).is_equal(tareas.titulo())
	assert_str((vista.get("_renglones") as Label).text).is_equal(
		"1. Atención al cliente\n2. Reposición"
	)
	vista.ocultar()
	assert_bool(vista.visible).is_false()


func test_el_bano_amplia_la_imagen_original_completa() -> void:  # AC-PLY-070
	var vista: NotaEncuadrada = auto_free(ESCENA.instantiate())
	add_child(vista)
	var hoja := NotaPegada.de(NotaPegada.Id.JABONES_Y_MANCHAS)
	var pixeles := Image.create(21, 28, false, Image.FORMAT_RGBA8)
	pixeles.fill(Color.WHITE)
	pixeles.set_pixel(0, 0, Color.RED)
	pixeles.set_pixel(20, 27, Color.BLUE)
	var original := ImageTexture.create_from_image(pixeles)
	vista.mostrar(hoja, original)
	var imagen: TextureRect = vista.get("_imagen")
	assert_bool(imagen.visible).is_true()
	assert_bool((vista.get("_papel") as Control).visible).is_false()
	assert_object(imagen.texture).is_same(original)
	assert_int(imagen.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert_str((vista.get("_renglones") as Label).text).is_empty()
	# Volver al corcho no conserva una imagen de la hoja anterior encima de su texto.
	vista.mostrar(NotaPegada.de(NotaPegada.Id.LOCAL_ORDENADO), null)
	assert_bool(imagen.visible).is_false()
	assert_object(imagen.texture).is_null()
	assert_bool((vista.get("_papel") as Control).visible).is_true()


func test_lista_vacia_conserva_el_titulo_y_la_salida() -> void:  # AC-PLY-069
	var vista: NotaEncuadrada = auto_free(ESCENA.instantiate())
	add_child(vista)
	vista.mostrar(NotaPegada.tareas_a_realizar([]), null)
	assert_str((vista.get("_titulo") as Label).text).is_equal("TAREAS A REALIZAR")
	assert_str((vista.get("_renglones") as Label).text).is_empty()
	assert_str((vista.get("_salida") as Label).text).is_equal(LienzoDeManada.TEXTO_DE_SALIDA)
