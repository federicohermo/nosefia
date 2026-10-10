extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")


func after_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _pantalla() -> PantallaDelCelular:
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	return pantalla


func _conversacion(cantidad: int = 2) -> Conversacion:
	var conversacion := Conversacion.new()
	conversacion.nombre = "Nombre del contacto"
	for indice in cantidad:
		var mensaje := Mensaje.new()
		mensaje.de_quien = conversacion.nombre
		mensaje.texto = "Mensaje %d. Texto de prueba para desplazar un historial largo." % indice
		conversacion.mensajes.append(mensaje)
	return conversacion


func test_subir_bajar_miden_tiempo_real_y_revertir_conserva_posicion() -> void:  # AC-INV-033
	var pantalla := _pantalla()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	var telefono: Control = pantalla.get("_telefono")
	var velo: Control = pantalla.get("_velo")
	pantalla.subir()
	var abajo := telefono.position
	ahora[0] = 125000
	pantalla._process(0.0)
	var medio := telefono.position
	assert_float(medio.y).is_less(abajo.y)
	pantalla.bajar()
	assert_vector(telefono.position).is_equal(medio)
	ahora[0] += 125000
	pantalla._process(0.0)
	assert_vector(telefono.position).is_equal(abajo)
	assert_bool(velo.visible).is_false()
	pantalla.subir()
	ahora[0] += 249000
	pantalla._process(0.0)
	assert_bool(pantalla.is_processing()).is_true()
	ahora[0] += 1000
	pantalla._process(0.0)
	assert_bool(pantalla.is_processing()).is_false()
	assert_vector(telefono.position + telefono.size / 2).is_equal(Vector2(960, 540))
	assert_float(telefono.size.x / telefono.size.y).is_equal(9.0 / 16.0)
	pantalla.bajar()
	ahora[0] += 250000
	pantalla._process(0.0)
	assert_bool(velo.visible).is_false()
	assert_float(telefono.position.y).is_greater_equal(1080)


func test_menu_usa_imagen_nombre_y_cuenta_solo_si_hay_no_leidos() -> void:  # AC-INV-038
	var pantalla := _pantalla()
	var conversacion := _conversacion()
	conversacion.imagen = GradientTexture2D.new()
	var bandeja := Bandeja.new([conversacion])
	pantalla.mostrar_menu(bandeja)
	var lista: VBoxContainer = pantalla.get("_mensajes")
	assert_int(lista.get_child_count()).is_equal(1)
	var boton: Button = lista.get_child(0)
	assert_str(boton.tooltip_text).is_equal(conversacion.nombre)
	var fila := boton.get_child(0)
	var imagen: TextureRect = fila.get_child(0).get_child(0)
	assert_object(imagen.texture).is_same(conversacion.imagen)
	assert_str((fila.get_child(1) as Label).text).is_equal(conversacion.nombre.to_upper())
	assert_str((fila.get_child(2) as Label).text).is_equal("2")
	var pedidos: Array[Conversacion.Interlocutor] = []
	pantalla.chat_pedido.connect(
		func(quien: Conversacion.Interlocutor) -> void: pedidos.append(quien)
	)
	boton.pressed.emit()
	assert_array(pedidos).is_equal([conversacion.interlocutor])
	conversacion.imagen = null
	bandeja.marcar_leida(conversacion.interlocutor)
	pantalla.mostrar_menu(bandeja)
	fila = lista.get_child(0).get_child(0)
	assert_int(fila.get_child_count()).is_equal(2)
	var avatar: PanelContainer = fila.get_child(0)
	var estilo := avatar.get_theme_stylebox("panel") as StyleBoxFlat
	assert_int(estilo.corner_radius_top_left).is_greater(0)
	assert_int(avatar.get_child_count()).is_zero()
	pantalla.mostrar_menu(Bandeja.new([]))
	assert_int(lista.get_child_count()).is_zero()


func test_scroll_y_foto_conservan_lugar() -> void:  # AC-INV-027, AC-INV-031
	var pantalla := _pantalla()
	var conversacion := _conversacion(24)
	conversacion.mensajes[2].foto = GradientTexture2D.new()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	ahora[0] = 250000
	pantalla._process(0.0)
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, false)
	for cuadro in 4:
		await get_tree().process_frame
	var scroll: ScrollContainer = pantalla.get("_scroll")
	assert_int(scroll.scroll_vertical).is_greater(0)
	var ultimo := scroll.scroll_vertical
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_UP
	rueda.pressed = true
	rueda.position = scroll.get_global_rect().get_center()
	get_viewport().push_input(rueda)
	await get_tree().process_frame
	assert_int(scroll.scroll_vertical).is_less(ultimo)
	var antes := scroll.scroll_vertical
	var pedidos: Array[int] = []
	pantalla.foto_pedida.connect(func(indice: int) -> void: pedidos.append(indice))
	var foto: TextureButton = (
		(pantalla.get("_mensajes") as Node).get_child(2).get_child(0).get_child(1)
	)
	foto.pressed.emit()
	assert_array(pedidos).is_equal([2])
	pantalla.ampliar(conversacion.mensajes[2], conversacion.mensajes[3])
	assert_str((pantalla.get("_adjunto") as RichTextLabel).text).is_equal(
		conversacion.mensajes[3].texto
	)
	var cerradas: Array[int] = []
	pantalla.cierre_de_foto_pedido.connect(func() -> void: cerradas.append(1))
	pantalla.cierre_de_foto_pedido.connect(pantalla.cerrar_foto)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	clic.position = Vector2(10, 10)
	pantalla._input(clic)
	assert_int(cerradas.size()).is_equal(1)
	assert_bool((pantalla.get("_foto_ampliada") as Control).visible).is_false()
	assert_int(scroll.scroll_vertical).is_equal(antes)
	pantalla.mostrar_chat(conversacion, [conversacion.mensajes[0]], true)
	assert_bool((pantalla.get("_volver") as Control).visible).is_false()
	for cuadro in 4:
		await get_tree().process_frame
	assert_int(scroll.scroll_vertical).is_zero()


func test_recordatorio_no_depende_de_la_pantalla_abierta() -> void:  # AC-INV-035
	var pantalla := _pantalla()
	var recordatorio: Control = pantalla.get("_recordatorio")
	assert_bool(recordatorio.visible).is_false()
	pantalla.mostrar_recordatorio(true)
	assert_bool(recordatorio.visible).is_true()
	pantalla.subir()
	assert_bool(recordatorio.visible).is_true()
	pantalla.bajar()
	assert_bool(recordatorio.visible).is_true()
	pantalla.mostrar_recordatorio(false)
	assert_bool(recordatorio.visible).is_false()


func test_cuerpo_y_adjunto_conservan_texto_y_dibujan_negrita() -> void:
	var pantalla := _pantalla()
	var conversacion := _conversacion(1)
	var mensaje := conversacion.mensajes[0]
	mensaje.texto = "Texto [b]importante[/b] íntegro."
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, false)
	var cuerpo := (pantalla.get("_mensajes") as Node).get_child(0).get_child(0).get_child(1)
	assert_bool(cuerpo is RichTextLabel).is_true()
	if cuerpo is RichTextLabel:
		assert_str(cuerpo.text).is_equal(mensaje.texto)
		assert_str(cuerpo.get_parsed_text()).is_equal("Texto importante íntegro.")
		var negrita := cuerpo.get_theme_font("bold_font") as FontVariation
		assert_object(negrita).is_not_null()
		if negrita != null:
			assert_float(negrita.variation_embolden).is_greater(0.0)
	var foto := Mensaje.new()
	foto.foto = GradientTexture2D.new()
	pantalla.ampliar(foto, mensaje)
	var adjunto: Control = pantalla.get("_adjunto")
	assert_bool(adjunto is RichTextLabel).is_true()
	if adjunto is RichTextLabel:
		assert_str(adjunto.text).is_equal(mensaje.texto)
		assert_str(adjunto.get_parsed_text()).is_equal("Texto importante íntegro.")
