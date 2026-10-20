extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")
const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")

var _tamano_de_ventana: Vector2i


func before_test() -> void:
	_tamano_de_ventana = get_window().size
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame


func after_test() -> void:
	get_window().size = _tamano_de_ventana
	await get_tree().process_frame
	await get_tree().process_frame


func _pantalla() -> PantallaDelCelular:
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	assert_vector(pantalla.get_viewport().get_visible_rect().size).is_equal(Vector2(1920, 1080))
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


func _burbuja(pantalla: PantallaDelCelular, indice: int) -> PanelContainer:
	var lista: VBoxContainer = pantalla.get("_mensajes")
	for hijo: Node in lista.get_children():
		if hijo.has_meta("indice_de_mensaje") and int(hijo.get_meta("indice_de_mensaje")) == indice:
			return hijo as PanelContainer
	return null


func test_subir_bajar_miden_tiempo_real_y_revertir_conserva_posicion() -> void:  # AC-INV-033
	var pantalla := _pantalla()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	var telefono: Control = pantalla.get("_telefono")
	var velo: Control = pantalla.get("_velo")
	pantalla.subir()
	var abajo := telefono.position
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 125000)
	var medio := telefono.position
	assert_float(medio.y).is_less(abajo.y)
	pantalla.bajar()
	assert_vector(telefono.position).is_equal(medio)
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 125000)
	assert_vector(telefono.position).is_equal(abajo)
	assert_bool(velo.visible).is_false()
	pantalla.subir()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 249000)
	assert_bool(pantalla.is_processing()).is_true()
	ahora[0] += 1000
	pantalla._process(0.0)
	assert_bool(pantalla.is_processing()).is_false()
	assert_vector(telefono.position + telefono.size / 2).is_equal(Vector2(960, 540))
	assert_float(telefono.size.x / telefono.size.y).is_equal(9.0 / 16.0)
	pantalla.bajar()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
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
	assert_str((fila.find_child("Nombre", true, false) as Label).text).is_equal(
		conversacion.nombre.to_upper()
	)
	assert_str((fila.find_child("NoLeidos", true, false).get_child(0) as Label).text).is_equal("2")
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


func test_un_cuadro_largo_no_salta_la_animacion_del_celular() -> void:  # AC-INV-033
	var pantalla := _pantalla()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	var telefono: Control = pantalla.get("_telefono")
	var abajo := telefono.position.y
	ahora[0] = 2000000
	pantalla._process(0.0)
	assert_float(telefono.position.y).is_less(abajo)
	assert_float(telefono.position.y + telefono.size.y / 2).is_greater(540.0)
	assert_bool(pantalla.is_processing()).is_true()


func test_llegar_a_la_izquierda_avisa_una_sola_vez() -> void:  # AC-INV-057
	var pantalla := _pantalla()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
	var llegadas: Array[bool] = []
	pantalla.celular_desplazado.connect(func() -> void: llegadas.append(true))
	pantalla.desplazar_a_la_izquierda()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
	assert_bool(pantalla.is_processing()).is_false()
	assert_array(llegadas).is_equal([true])
	pantalla._process(0.0)
	assert_array(llegadas).is_equal([true])


func test_scroll_y_foto_conservan_lugar() -> void:  # AC-INV-027, AC-INV-031
	var pantalla := _pantalla()
	var conversacion := _conversacion(24)
	conversacion.mensajes[2].foto = GradientTexture2D.new()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, false, 1)
	for cuadro in 4:
		await get_tree().process_frame
	var scroll: ScrollContainer = pantalla.get("_scroll")
	assert_int(scroll.scroll_vertical).is_greater(0)
	var ultimo := scroll.scroll_vertical
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_UP
	rueda.pressed = true
	rueda.position = scroll.get_global_rect().get_center()
	get_viewport().push_input(rueda, true)
	await get_tree().process_frame
	assert_int(scroll.scroll_vertical).is_less(ultimo)
	var antes := scroll.scroll_vertical
	var pedidos: Array[int] = []
	pantalla.foto_pedida.connect(func(indice: int) -> void: pedidos.append(indice))
	var foto: TextureButton = (
		_burbuja(pantalla, 2).find_children("*", "TextureButton", true, false)[0]
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
	pantalla.mostrar_chat(conversacion, [conversacion.mensajes[0]], true, 1)
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
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, false, 1)
	var cuerpo := _burbuja(pantalla, 0).find_children("*", "RichTextLabel", true, false)[0]
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


func test_buscar_filtra_contactos_y_borrar_restaura_sin_cambiar_lecturas() -> void:
	var pantalla := _pantalla()
	var conversacion := _conversacion()
	var bandeja := Bandeja.new([conversacion])
	pantalla.mostrar_menu(bandeja)
	var buscar: LineEdit = pantalla.get("_busqueda")
	var lista: VBoxContainer = pantalla.get("_mensajes")
	buscar.text_changed.emit("CONTACTO")
	assert_int(lista.get_child_count()).is_equal(1)
	buscar.text_changed.emit("no existe")
	assert_int(lista.get_child_count()).is_zero()
	assert_int(bandeja.no_leidos(conversacion.interlocutor)).is_equal(2)
	buscar.text_changed.emit("")
	assert_int(lista.get_child_count()).is_equal(1)
	var vista_previa := lista.find_child("VistaPrevia", true, false) as Label
	assert_str(vista_previa.text).is_equal(conversacion.mensajes[-1].texto)
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, false, 1)
	assert_bool(buscar.visible).is_false()
	assert_bool((pantalla.get("_entrada") as LineEdit).editable).is_false()
	pantalla.mostrar_menu(bandeja)
	assert_bool(buscar.visible).is_true()
	assert_str(buscar.text).is_empty()


func test_el_izquierdo_fuera_del_telefono_pide_cerrar_y_adentro_no() -> void:  # AC-INV-033
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var cierres: Array[int] = []
	pantalla.cierre_pedido.connect(func() -> void: cierres.append(1))
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	clic.position = Vector2(10, 10)
	pantalla._input(clic)
	assert_array(cierres).is_empty()
	pantalla.subir()
	clic.position = (pantalla.get("_telefono") as Control).get_global_rect().get_center()
	pantalla._input(clic)
	assert_array(cierres).is_empty()
	clic.position = Vector2(10, 10)
	pantalla._input(clic)
	assert_int(cierres.size()).is_equal(1)


# AC-INV-039, AC-INV-041, AC-INV-042
func test_yasmin_conserva_rol_avatar_liso_y_tramo_identificado() -> void:
	var pantalla := _pantalla()
	var sistema: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	var pedidos: Array[String] = []
	sistema.tramo_de_pista_pedido.connect(
		func(identidad: String) -> void: pedidos.append(identidad)
	)
	pantalla.tramo_pedido.connect(sistema.pedir_tramo)
	sistema.abrir_jornada(5)
	sistema.pedir_alternar(false)
	sistema.pedir_chat(Conversacion.Interlocutor.YASMIN)
	var conversacion := sistema.bandeja().conversacion_de(Conversacion.Interlocutor.YASMIN)
	var mensajes := sistema.bandeja().mensajes_de(Conversacion.Interlocutor.YASMIN)
	pantalla.mostrar_chat(conversacion, mensajes, false, 5)
	assert_str((pantalla.get("_subtitulo") as Label).text).is_equal("Compañera de trabajo")
	assert_bool((pantalla.get("_subtitulo") as Label).visible).is_true()
	assert_object((pantalla.get("_avatar_del_chat") as TextureRect).texture).is_not_null()
	var texto := (
		_burbuja(pantalla, 5).find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
	)
	assert_str(texto.get_parsed_text()).is_equal(mensajes[5].texto)
	assert_array(pedidos).is_empty()
	texto.meta_clicked.emit("fuera")
	assert_array(pedidos).is_empty()
	texto.meta_clicked.emit("falta_algo")
	texto.meta_clicked.emit("falta_algo")
	assert_array(pedidos).is_equal(["2A", "2A"])
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
	var scroll: ScrollContainer = pantalla.get("_scroll")
	for cuadro in 4:
		await get_tree().process_frame
	scroll.ensure_control_visible(texto)
	for cuadro in 4:
		await get_tree().process_frame
	var fuente := texto.get_theme_font("normal_font")
	var tamano := texto.get_theme_font_size("normal_font_size")
	var prefijo := fuente.get_string_size("y te aviso q ", HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var punto := (
		texto.get_global_transform() * Vector2(prefijo + 8.0, fuente.get_height(tamano) / 4.0)
	)
	var relativo := Vector2(0, 12)
	assert_bool(scroll.get_global_rect().has_point(punto)).is_true()
	assert_bool(texto.get_global_rect().has_point(punto + relativo)).is_true()
	var antes := scroll.scroll_vertical
	pedidos.clear()
	get_viewport().push_input(_boton_del_mouse(punto, true), true)
	get_viewport().push_input(_movimiento(punto + relativo, relativo), true)
	get_viewport().push_input(_boton_del_mouse(punto + relativo, false), true)
	await get_tree().process_frame
	assert_array(pedidos).is_equal(["2A"])
	assert_int(scroll.scroll_vertical).is_equal(antes)
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_UP
	rueda.pressed = true
	rueda.position = punto
	get_viewport().push_input(rueda, true)
	await get_tree().process_frame
	assert_int(scroll.scroll_vertical).is_less(antes)
	assert_array(pedidos).is_equal(["2A"])


func test_llegada_intercalada_conserva_indice_actual_de_la_foto() -> void:  # AC-INV-040, AC-INV-042
	var pantalla := _pantalla()
	var conversacion := _conversacion(3)
	conversacion.mensajes[1].foto = GradientTexture2D.new()
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, false, 1)
	var nuevo := Mensaje.new()
	nuevo.texto = "Un cierre anterior a la apertura"
	pantalla.recibir(nuevo, 0)
	var texto := (
		_burbuja(pantalla, 0).find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
	)
	assert_str(texto.get_parsed_text()).is_equal(nuevo.texto)
	var pedidos: Array[int] = []
	pantalla.foto_pedida.connect(func(indice: int) -> void: pedidos.append(indice))
	var fotos := _burbuja(pantalla, 2).find_children("*", "TextureButton", true, false)
	assert_int(fotos.size()).is_equal(1)
	if fotos.is_empty():
		return
	var foto := fotos[0] as TextureButton
	foto.pressed.emit()
	assert_array(pedidos).is_equal([2])


# AC-INV-039, AC-INV-042
func test_el_guion_incluye_sus_glifos_sin_depender_de_fuentes_del_sistema() -> void:
	var tema := load("res://assets/ui/manada/tema.tres") as Theme
	var primaria := tema.default_font
	var respaldos := primaria.fallbacks.duplicate()
	var caracteres := primaria.get_supported_chars()
	var pantalla := _pantalla()
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(5)
	pantalla.mostrar_menu(bandeja)
	var lista: VBoxContainer = pantalla.get("_mensajes")
	var resumen := lista.get_child(1).find_child("VistaPrevia", true, false) as Label
	var fuente := resumen.get_theme_font("font")
	for codigo: int in [0x2728, 0x1f4aa]:
		assert_bool(fuente.get_supported_chars().contains(String.chr(codigo))).is_true()
	var conversacion := bandeja.conversacion_de(Conversacion.Interlocutor.YASMIN)
	pantalla.mostrar_chat(conversacion, bandeja.mensajes_de(conversacion.interlocutor), false, 5)
	for caso: Vector2i in [Vector2i(0, 0x2728), Vector2i(14, 0x1f4aa)]:
		var texto := (
			_burbuja(pantalla, caso.x).find_children("*", "RichTextLabel", true, false)[0]
			as RichTextLabel
		)
		var glifos := texto.get_theme_font("normal_font").get_supported_chars()
		assert_bool(glifos.contains(String.chr(caso.y))).is_true()
	assert_object(tema.default_font).is_same(primaria)
	assert_array(primaria.fallbacks).is_equal(respaldos)
	assert_str(primaria.get_supported_chars()).is_equal(caracteres)
	assert_object((fuente as FontVariation).base_font).is_same(primaria)


func _boton_del_mouse(posicion: Vector2, apretado: bool) -> InputEventMouseButton:
	var boton := InputEventMouseButton.new()
	boton.button_index = MOUSE_BUTTON_LEFT
	boton.button_mask = MOUSE_BUTTON_MASK_LEFT if apretado else 0
	boton.pressed = apretado
	boton.position = posicion
	boton.global_position = posicion
	return boton


func _movimiento(posicion: Vector2, relativo: Vector2) -> InputEventMouseMotion:
	var movimiento := InputEventMouseMotion.new()
	movimiento.button_mask = MOUSE_BUTTON_MASK_LEFT
	movimiento.position = posicion
	movimiento.global_position = posicion
	movimiento.relative = relativo
	return movimiento


func _tecla(codigo: Key, apretada: bool) -> InputEventKey:
	var tecla := InputEventKey.new()
	tecla.keycode = codigo
	tecla.physical_keycode = codigo
	tecla.pressed = apretada
	return tecla


func _apretar_boton(boton: BaseButton, posicion: Vector2) -> void:
	assert_bool(boton.get_global_rect().has_point(posicion)).is_true()
	boton.get_viewport().push_input(_boton_del_mouse(posicion, true), true)
	assert_bool(boton.is_hovered()).is_true()
	assert_bool(boton.is_pressed()).is_true()


func test_arrastrar_el_historial_lo_desplaza_y_soltar_termina() -> void:
	var pantalla := _pantalla()
	var conversacion := _conversacion(24)
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, false, 1)
	for cuadro in 4:
		await get_tree().process_frame
	var scroll: ScrollContainer = pantalla.get("_scroll")
	var centro := scroll.get_global_rect().get_center()
	var abajo := scroll.scroll_vertical
	assert_int(abajo).is_greater(0)
	assert_int(scroll.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	get_viewport().push_input(_boton_del_mouse(centro, true), true)
	await get_tree().process_frame
	assert_int(scroll.mouse_default_cursor_shape).is_equal(Control.CURSOR_DRAG)
	get_viewport().push_input(_movimiento(centro + Vector2(0, 60), Vector2(0, 60)), true)
	await get_tree().process_frame
	var arrastrado := scroll.scroll_vertical
	assert_int(arrastrado).is_less(abajo)
	get_viewport().push_input(_movimiento(centro, Vector2(0, -100000)), true)
	await get_tree().process_frame
	var barra := scroll.get_v_scroll_bar()
	assert_int(scroll.scroll_vertical).is_equal(int(barra.max_value - barra.page))
	get_viewport().push_input(_boton_del_mouse(Vector2(1, 1), false), true)
	await get_tree().process_frame
	assert_int(scroll.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	assert_bool((pantalla.get("_telefono") as Control).visible).is_true()
	var soltado := scroll.scroll_vertical
	get_viewport().push_input(_movimiento(centro + Vector2(0, 60), Vector2(0, 60)), true)
	await get_tree().process_frame
	assert_int(scroll.scroll_vertical).is_equal(soltado)
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_UP
	rueda.pressed = true
	rueda.position = centro
	get_viewport().push_input(rueda, true)
	await get_tree().process_frame
	assert_int(scroll.scroll_vertical).is_less(soltado)


func test_ocultar_el_celular_termina_el_arrastre() -> void:
	var pantalla := _pantalla()
	var conversacion := _conversacion(24)
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, false, 1)
	for cuadro in 4:
		await get_tree().process_frame
	var scroll: ScrollContainer = pantalla.get("_scroll")
	var centro := scroll.get_global_rect().get_center()
	get_viewport().push_input(_boton_del_mouse(centro, true), true)
	await get_tree().process_frame
	assert_int(scroll.mouse_default_cursor_shape).is_equal(Control.CURSOR_DRAG)
	(pantalla.get("_telefono") as Control).hide()
	assert_int(scroll.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	(pantalla.get("_telefono") as Control).show()
	var quieto := scroll.scroll_vertical
	get_viewport().push_input(_movimiento(centro + Vector2(0, 60), Vector2(0, 60)), true)
	await get_tree().process_frame
	assert_int(scroll.scroll_vertical).is_equal(quieto)


func test_la_foto_real_abre_con_movimiento_sin_desplazar_el_chat() -> void:
	var pantalla := _pantalla()
	var sistema: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	pantalla.foto_pedida.connect(sistema.pedir_foto)
	sistema.foto_ampliada.connect(pantalla.ampliar)
	sistema.foto_cerrada.connect(pantalla.cerrar_foto)
	sistema.abrir_jornada(1)
	sistema.pedir_alternar(false)
	sistema.pedir_chat(Conversacion.Interlocutor.JEFE)
	var conversacion := sistema.bandeja().conversacion_de(Conversacion.Interlocutor.JEFE)
	var mensajes := sistema.bandeja().mensajes_de(Conversacion.Interlocutor.JEFE)
	var con_foto := 1
	assert_str(mensajes[con_foto].identidad).is_equal("J1_Foto02")
	assert_str(mensajes[con_foto].foto.resource_path).is_equal(
		"res://assets/ui/manada/fotos/intro-04.png"
	)
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
	pantalla.mostrar_chat(conversacion, mensajes, false, 1)
	for cuadro in 4:
		await get_tree().process_frame
	var scroll: ScrollContainer = pantalla.get("_scroll")
	var foto := (
		_burbuja(pantalla, con_foto).find_children("*", "TextureButton", true, false)[0]
		as TextureButton
	)
	scroll.ensure_control_visible(foto)
	for cuadro in 4:
		await get_tree().process_frame
	assert_float(scroll.get_v_scroll_bar().max_value).is_greater(scroll.get_v_scroll_bar().page)
	var antes := scroll.scroll_vertical
	var centro := foto.get_global_rect().intersection(scroll.get_global_rect()).get_center()
	for relativo: Vector2 in [Vector2(0, 12), Vector2(0, 20), Vector2(0, 60)]:
		assert_bool(foto.get_global_rect().has_point(centro + relativo)).is_true()
		assert_bool(scroll.get_global_rect().has_point(centro + relativo)).is_true()
		_apretar_boton(foto, centro)
		get_viewport().push_input(_movimiento(centro + relativo, relativo), true)
		get_viewport().push_input(_boton_del_mouse(centro + relativo, false), true)
		await get_tree().process_frame
		assert_int(sistema.celular().pantalla()).is_equal(Celular.Pantalla.FOTO)
		assert_bool((pantalla.get("_foto_ampliada") as Control).visible).is_true()
		assert_int(scroll.scroll_vertical).is_equal(antes)
		sistema.pedir_cerrar_foto()
		await get_tree().process_frame
		assert_int(sistema.celular().pantalla()).is_equal(Celular.Pantalla.CHAT)
		assert_bool((pantalla.get("_foto_ampliada") as Control).visible).is_false()
		assert_int(scroll.scroll_vertical).is_equal(antes)
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_DOWN
	rueda.pressed = true
	rueda.position = centro
	get_viewport().push_input(rueda, true)
	await get_tree().process_frame
	assert_int(scroll.scroll_vertical).is_greater(antes)


func test_contactos_conservan_clics_con_movimiento_y_no_se_desplazan() -> void:
	var pantalla := _pantalla()
	var conversacion := _conversacion()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
	pantalla.mostrar_menu(Bandeja.new([conversacion]))
	for cuadro in 4:
		await get_tree().process_frame
	var pedidos: Array[Conversacion.Interlocutor] = []
	pantalla.chat_pedido.connect(
		func(quien: Conversacion.Interlocutor) -> void: pedidos.append(quien)
	)
	var lista: VBoxContainer = pantalla.get("_mensajes")
	var scroll: ScrollContainer = pantalla.get("_scroll")
	var alto_del_historial := scroll.size.y
	var espaciador := Control.new()
	espaciador.custom_minimum_size.y = alto_del_historial * 2.0
	lista.add_child(espaciador)
	for cuadro in 4:
		await get_tree().process_frame
	assert_float(lista.size.y).is_greater(alto_del_historial)
	assert_int(scroll.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)
	var boton := lista.get_child(0) as Button
	var centro := boton.get_global_rect().get_center()
	assert_bool(scroll.get_global_rect().has_point(centro)).is_true()
	assert_int(scroll.scroll_vertical).is_zero()
	for relativo: Vector2 in [Vector2(0, 2), Vector2(0, 20), Vector2(0, -20), Vector2(20, 0)]:
		pedidos.clear()
		assert_bool(boton.get_global_rect().has_point(centro + relativo)).is_true()
		_apretar_boton(boton, centro)
		get_viewport().push_input(_movimiento(centro + relativo, relativo), true)
		get_viewport().push_input(_boton_del_mouse(centro + relativo, false), true)
		await get_tree().process_frame
		assert_int(scroll.scroll_vertical).is_zero()
		assert_int(scroll.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)
		assert_array(pedidos).is_equal([conversacion.interlocutor])
		get_viewport().push_input(_tecla(KEY_ENTER, true), true)
		get_viewport().push_input(_tecla(KEY_ENTER, false), true)
		await get_tree().process_frame
		assert_array(pedidos).is_equal([conversacion.interlocutor, conversacion.interlocutor])
		_apretar_boton(boton, centro)
		get_viewport().push_input(_boton_del_mouse(centro, false), true)
		await get_tree().process_frame
		assert_array(pedidos).is_equal(
			[conversacion.interlocutor, conversacion.interlocutor, conversacion.interlocutor]
		)
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_DOWN
	rueda.pressed = true
	rueda.position = scroll.get_global_rect().get_center()
	get_viewport().push_input(rueda, true)
	await get_tree().process_frame
	assert_int(scroll.scroll_vertical).is_zero()


func test_una_foto_sin_desborde_conserva_clics_con_movimiento() -> void:
	var pantalla := _pantalla()
	var conversacion := _conversacion(1)
	conversacion.mensajes[0].foto = GradientTexture2D.new()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, false, 1)
	for cuadro in 4:
		await get_tree().process_frame
	var pedidas: Array[int] = []
	pantalla.foto_pedida.connect(func(indice: int) -> void: pedidas.append(indice))
	var scroll: ScrollContainer = pantalla.get("_scroll")
	var foto := (
		_burbuja(pantalla, 0).find_children("*", "TextureButton", true, false)[0] as BaseButton
	)
	var centro := foto.get_global_rect().get_center()
	assert_bool(scroll.get_global_rect().has_point(centro)).is_true()
	assert_int(scroll.scroll_vertical).is_equal(0)
	assert_float(scroll.get_v_scroll_bar().max_value).is_less_equal(scroll.get_v_scroll_bar().page)
	assert_int(scroll.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)
	for relativo: Vector2 in [Vector2(0, 2), Vector2(0, 20), Vector2(20, 0)]:
		pedidas.clear()
		_apretar_boton(foto, centro)
		get_viewport().push_input(_movimiento(centro + relativo, relativo), true)
		get_viewport().push_input(_movimiento(centro, -relativo), true)
		get_viewport().push_input(_boton_del_mouse(centro, false), true)
		await get_tree().process_frame
		assert_int(scroll.scroll_vertical).is_equal(0)
		assert_int(scroll.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)
		assert_array(pedidas).is_equal([0])
		pedidas.clear()
		_apretar_boton(foto, centro)
		get_viewport().push_input(_boton_del_mouse(centro, false), true)
		await get_tree().process_frame
		assert_array(pedidas).is_equal([0])

	var nuevos := _conversacion(24).mensajes
	for indice in nuevos.size():
		pantalla.recibir(nuevos[indice], indice + 1)
	for cuadro in 4:
		await get_tree().process_frame
	assert_float(scroll.get_v_scroll_bar().max_value).is_greater(scroll.get_v_scroll_bar().page)
	assert_int(scroll.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, false, 1)
	for cuadro in 4:
		await get_tree().process_frame
	assert_int(scroll.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)
	assert_int(scroll.scroll_vertical).is_zero()


func test_una_foto_conserva_foco_y_activacion_nativa_con_teclado() -> void:
	var pantalla := _pantalla()
	var conversacion := _conversacion(24)
	var con_foto := 22
	conversacion.mensajes[con_foto].foto = GradientTexture2D.new()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, false, 1)
	for cuadro in 4:
		await get_tree().process_frame
	var foto := (
		_burbuja(pantalla, con_foto).find_children("*", "TextureButton", true, false)[0]
		as BaseButton
	)
	var pedidas: Array[int] = []
	pantalla.foto_pedida.connect(func(indice: int) -> void: pedidas.append(indice))
	var nativas: Array[int] = []
	foto.pressed.connect(func() -> void: nativas.append(1))
	var scroll: ScrollContainer = pantalla.get("_scroll")
	var antes := scroll.scroll_vertical
	assert_int(foto.focus_mode).is_equal(Control.FOCUS_ALL)
	var centro := foto.get_global_rect().intersection(scroll.get_global_rect()).get_center()
	_apretar_boton(foto, centro)
	get_viewport().push_input(_movimiento(centro + Vector2(0, 12), Vector2(0, 12)), true)
	get_viewport().push_input(_boton_del_mouse(centro + Vector2(0, 12), false), true)
	await get_tree().process_frame
	assert_bool(foto.has_focus()).is_true()
	assert_array(pedidas).is_equal([con_foto])
	assert_array(nativas).is_equal([1])
	get_viewport().push_input(_tecla(KEY_ENTER, true), true)
	get_viewport().push_input(_tecla(KEY_ENTER, false), true)
	await get_tree().process_frame
	assert_array(pedidas).is_equal([con_foto, con_foto])
	assert_array(nativas).is_equal([1, 1])
	assert_int(scroll.scroll_vertical).is_equal(antes)
