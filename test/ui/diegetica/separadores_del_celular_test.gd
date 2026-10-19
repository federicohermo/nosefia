extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")


func after_test() -> void:
	await _cuadros()


func _cuadros() -> void:
	for _cuadro: int in 4:
		await get_tree().process_frame


func _pantalla() -> PantallaDelCelular:
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	return pantalla


func _mensaje(jornada: int, texto: String = "Mensaje") -> Mensaje:
	var mensaje := Mensaje.new()
	mensaje.jornada = jornada
	mensaje.texto = texto
	return mensaje


func _chat(mensajes: Array[Mensaje]) -> Conversacion:
	var chat := Conversacion.new()
	chat.nombre = "Contacto"
	chat.rol = "Rol del contacto"
	chat.mensajes = mensajes
	return chat


func _rotulos(pantalla: PantallaDelCelular) -> Array[String]:
	var rotulos: Array[String] = []
	var lista: VBoxContainer = pantalla.get("_mensajes")
	for hijo: Node in lista.get_children():
		if hijo is Label:
			rotulos.append(hijo.text)
	return rotulos


func _burbujas(pantalla: PantallaDelCelular) -> Array[PanelContainer]:
	var burbujas: Array[PanelContainer] = []
	var lista: VBoxContainer = pantalla.get("_mensajes")
	for hijo: Node in lista.get_children():
		if hijo is PanelContainer:
			burbujas.append(hijo)
	return burbujas


func test_cada_bloque_conocido_separa_los_ocho_dias() -> void:
	var pantalla := _pantalla()
	var mensajes: Array[Mensaje] = []
	for jornada: int in range(1, 9):
		mensajes.append(_mensaje(jornada))
	var chat := _chat(mensajes)
	pantalla.mostrar_chat(chat, mensajes, false, 8)
	(
		assert_array(_rotulos(pantalla))
		. is_equal(
			[
				"HACE SIETE DÍAS",
				"HACE SEIS DÍAS",
				"HACE CINCO DÍAS",
				"HACE CUATRO DÍAS",
				"HACE TRES DÍAS",
				"HACE DOS DÍAS",
				"AYER",
				"HOY",
			]
		)
	)
	assert_int(_burbujas(pantalla).size()).is_equal(8)
	assert_array(chat.mensajes).is_equal(mensajes)


func test_vacio_huecos_repetidos_y_legacy_no_inventan_bloques() -> void:
	var pantalla := _pantalla()
	var legacy := Mensaje.desde_datos("Texto sin fecha")
	var mensajes: Array[Mensaje] = [legacy, _mensaje(1), _mensaje(1), _mensaje(3)]
	var chat := _chat(mensajes)
	pantalla.mostrar_chat(chat, [], false, 3)
	assert_array(_rotulos(pantalla)).is_empty()
	assert_array(_burbujas(pantalla)).is_empty()
	pantalla.mostrar_chat(chat, mensajes, false, 3)
	assert_array(_rotulos(pantalla)).is_equal(["HACE DOS DÍAS", "HOY"])
	assert_int(_burbujas(pantalla).size()).is_equal(4)
	assert_int(legacy.jornada).is_zero()
	assert_int(legacy.momento).is_equal(Mensaje.Momento.SIN_FECHA)


func test_reabrir_historial_real_de_jornada_5_conserva_lecturas_y_guion() -> void:
	var pantalla := _pantalla()
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(5)
	var chat := bandeja.conversacion_de(Conversacion.Interlocutor.JEFE)
	var mensajes := bandeja.mensajes_de(chat.interlocutor)
	var sin_leer := bandeja.no_leidos(chat.interlocutor)
	var guion := chat.mensajes.duplicate()
	for _apertura: int in 2:
		pantalla.mostrar_chat(chat, mensajes, false, 5)
		assert_array(_rotulos(pantalla)).is_equal(["HACE CUATRO DÍAS", "HOY"])
		assert_int(bandeja.no_leidos(chat.interlocutor)).is_equal(sin_leer)
		assert_array(bandeja.mensajes_de(chat.interlocutor)).is_equal(mensajes)
		assert_array(chat.mensajes).is_equal(guion)


func test_foto_y_tramo_despues_del_separador_conservan_indices_y_metadata() -> void:
	var pantalla := _pantalla()
	var foto := _mensaje(2)
	foto.foto = GradientTexture2D.new()
	var tramo := _mensaje(2, "Antes acá siempre falta algo después")
	tramo.identidad = "J2_6"
	tramo.tramo_de_pista = "falta_algo"
	tramo.texto_del_tramo = "acá siempre falta algo"
	tramo.pista = "2A"
	var mensajes: Array[Mensaje] = [_mensaje(1), foto, tramo]
	pantalla.mostrar_chat(_chat(mensajes), mensajes, false, 2)
	var fotos: Array[int] = []
	var tramos: Array[String] = []
	pantalla.foto_pedida.connect(func(indice: int) -> void: fotos.append(indice))
	pantalla.tramo_pedido.connect(
		func(identidad: String, parte: String) -> void: tramos.append(identidad + ":" + parte)
	)
	var burbujas := _burbujas(pantalla)
	var boton := burbujas[1].find_children("*", "TextureButton", true, false)[0] as TextureButton
	boton.pressed.emit()
	var texto := burbujas[2].find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
	texto.meta_clicked.emit("falta_algo")
	assert_array(fotos).is_equal([1])
	assert_array(tramos).is_equal(["J2_6:falta_algo"])
	assert_array(_rotulos(pantalla)).is_equal(["AYER", "HOY"])
	pantalla.ampliar(foto, tramo)
	assert_str((pantalla.get("_adjunto") as RichTextLabel).text).is_equal(tramo.texto)


func test_intercalar_actualiza_fotos_sin_reconstruir_la_ampliada() -> void:
	var pantalla := _pantalla()
	var foto := _mensaje(2)
	foto.foto = GradientTexture2D.new()
	var adjunto := _mensaje(2, "Adjunto de la foto")
	var mensajes: Array[Mensaje] = [foto, adjunto]
	pantalla.mostrar_chat(_chat(mensajes), mensajes, false, 2)
	var burbuja := _burbujas(pantalla)[0]
	var boton := burbuja.find_children("*", "TextureButton", true, false)[0] as TextureButton
	var pedidos: Array[int] = []
	pantalla.foto_pedida.connect(func(indice: int) -> void: pedidos.append(indice))
	pantalla.ampliar(foto, adjunto)
	await _cuadros()
	var scroll: ScrollContainer = pantalla.get("_scroll")
	var antes := scroll.scroll_vertical
	pantalla.recibir(_mensaje(1, "Cierre anterior"), 0)
	await _cuadros()
	assert_array(_rotulos(pantalla)).is_equal(["AYER", "HOY"])
	assert_object(_burbujas(pantalla)[1]).is_same(burbuja)
	assert_bool((pantalla.get("_foto_ampliada") as Control).visible).is_true()
	assert_object((pantalla.get("_imagen") as TextureRect).texture).is_same(foto.foto)
	assert_str((pantalla.get("_adjunto") as RichTextLabel).text).is_equal(adjunto.texto)
	pantalla.cerrar_foto()
	boton.pressed.emit()
	assert_array(pedidos).is_equal([1])
	assert_int(scroll.scroll_vertical).is_equal(antes)


func test_recibir_en_un_bloque_no_duplica_y_conserva_la_opcion_al_final() -> void:
	var pantalla := _pantalla()
	var mensajes: Array[Mensaje] = [_mensaje(1)]
	pantalla.mostrar_chat(_chat(mensajes), mensajes, true, 2)
	pantalla.mostrar_opcion("CONTINUAR")
	pantalla.recibir(_mensaje(1), 1)
	assert_array(_rotulos(pantalla)).is_equal(["AYER"])
	pantalla.recibir(_mensaje(2), 2)
	pantalla.recibir(_mensaje(2), 3)
	assert_array(_rotulos(pantalla)).is_equal(["AYER", "HOY"])
	assert_int(_burbujas(pantalla).size()).is_equal(4)
	var lista: VBoxContainer = pantalla.get("_mensajes")
	assert_object(lista.get_child(-1)).is_same(pantalla.opcion())


func test_el_contexto_fijo_cerrado_recalcula_solo_al_abrir_otra_jornada() -> void:
	var pantalla := _pantalla()
	var mensajes: Array[Mensaje] = [_mensaje(2)]
	var chat := _chat(mensajes)
	pantalla.mostrar_chat(chat, mensajes, true, 2)
	assert_array(_rotulos(pantalla)).is_equal(["HOY"])
	assert_bool((pantalla.get("_volver") as Control).visible).is_false()
	pantalla.mostrar_chat(chat, mensajes, false, 3)
	assert_array(_rotulos(pantalla)).is_equal(["AYER"])
	assert_bool((pantalla.get("_volver") as Control).visible).is_true()


func test_cabecera_opcion_y_foto_caben_en_ambos_encuadres() -> void:
	var tamano_anterior := get_window().size
	var modo_anterior := get_window().mode
	get_window().mode = Window.MODE_WINDOWED
	var pantalla := _pantalla()
	var foto := _mensaje(2)
	foto.foto = GradientTexture2D.new()
	var texto := _mensaje(2, "Adjunto completo de la fotografía de una pista.")
	var mensajes: Array[Mensaje] = [_mensaje(1), foto, texto]
	var chat := _chat(mensajes)
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_window().size = tamano
		await _cuadros()
		pantalla.subir()
		pantalla.set("_avance", 1.0)
		pantalla.call("_pintar_posicion")
		pantalla.set_process(false)
		pantalla.mostrar_chat(chat, mensajes, true, 2)
		pantalla.mostrar_opcion("CONTINUAR")
		await _cuadros()
		var telefono: Control = pantalla.get("_telefono")
		var cabecera: Control = pantalla.get("_cabecera")
		var scroll: ScrollContainer = pantalla.get("_scroll")
		assert_bool(telefono.get_global_rect().encloses(cabecera.get_global_rect())).is_true()
		assert_str((pantalla.get("_titulo") as Label).text).is_equal("CONTACTO")
		assert_str((pantalla.get("_subtitulo") as Label).text).is_equal(chat.rol)
		assert_array(_rotulos(pantalla)).is_equal(["AYER", "HOY"])
		scroll.ensure_control_visible(pantalla.opcion())
		await _cuadros()
		(
			assert_bool(scroll.get_global_rect().encloses(pantalla.opcion().get_global_rect()))
			. is_true()
		)
		var antes := scroll.scroll_vertical
		pantalla.ampliar(foto, texto)
		await _cuadros()
		var ampliada: Control = pantalla.get("_foto_ampliada")
		assert_bool(telefono.get_global_rect().encloses(ampliada.get_global_rect())).is_true()
		assert_str((pantalla.get("_adjunto") as RichTextLabel).text).is_equal(texto.texto)
		pantalla.cerrar_foto()
		assert_int(scroll.scroll_vertical).is_equal(antes)
	get_window().size = tamano_anterior
	get_window().mode = modo_anterior
