extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")
const JORNADA_DEL_LECTOR := GeneradorDeTickets.JORNADA_SIN_LECTOR
const CALAVERA := 0x1F480
const CARA_APRETADA := 0x1F62C
const TAMANOS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 720)]

var _tamano_de_ventana: Vector2i


func before_test() -> void:
	_tamano_de_ventana = get_window().size
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame


func after_test() -> void:
	get_window().size = _tamano_de_ventana
	await get_tree().process_frame
	await get_tree().process_frame


func _es_del_bloque(mensaje: Mensaje) -> bool:
	return mensaje.identidad.begins_with("J3_")


func _burbuja(pantalla: PantallaDelCelular, indice: int) -> PanelContainer:
	var lista: VBoxContainer = pantalla.get("_mensajes")
	for hijo: Node in lista.get_children():
		if hijo.has_meta("indice_de_mensaje") and int(hijo.get_meta("indice_de_mensaje")) == indice:
			return hijo as PanelContainer
	return null


func _pantalla_con_el_chat(bandeja: Bandeja, tamano: Vector2i) -> PantallaDelCelular:
	get_window().size = tamano
	await get_tree().process_frame
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	assert_vector(pantalla.get_viewport().get_visible_rect().size).is_equal(Vector2(tamano))
	var conversacion := bandeja.conversacion_de(Conversacion.Interlocutor.YASMIN)
	pantalla.mostrar_chat(
		conversacion, bandeja.mensajes_de(conversacion.interlocutor), false, JORNADA_DEL_LECTOR
	)
	return pantalla


func _texto_de(burbuja: PanelContainer) -> RichTextLabel:
	return burbuja.find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel


func test_la_calavera_y_la_cara_apretada_se_dibujan_sin_fuentes_del_sistema() -> void:  # AC-INV-068
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(JORNADA_DEL_LECTOR)
	var mensajes := bandeja.mensajes_de(Conversacion.Interlocutor.YASMIN)
	for tamano: Vector2i in TAMANOS:
		var pantalla := await _pantalla_con_el_chat(bandeja, tamano)
		for caso: Array in [[CALAVERA, "J3_7"], [CARA_APRETADA, "J3_9"]]:
			var indice := mensajes.map(func(m: Mensaje) -> String: return m.identidad).find(caso[1])
			assert_int(indice).is_greater_equal(0)
			var burbuja := _burbuja(pantalla, indice)
			assert_object(burbuja).is_not_null()
			if burbuja == null:
				continue
			var glifos := _texto_de(burbuja).get_theme_font("normal_font").get_supported_chars()
			assert_bool(glifos.contains(String.chr(caso[0]))).is_true()


func test_las_diez_burbujas_del_bloque_no_tienen_tramo_de_pista_activo() -> void:  # AC-INV-068
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(JORNADA_DEL_LECTOR)
	var mensajes := bandeja.mensajes_de(Conversacion.Interlocutor.YASMIN)
	for tamano: Vector2i in TAMANOS:
		var pantalla := await _pantalla_con_el_chat(bandeja, tamano)
		var vistas := 0
		for indice in mensajes.size():
			if not _es_del_bloque(mensajes[indice]):
				continue
			var burbuja := _burbuja(pantalla, indice)
			assert_object(burbuja).is_not_null()
			if burbuja == null:
				continue
			vistas += 1
			var texto := _texto_de(burbuja)
			assert_str(texto.get_parsed_text()).is_equal(mensajes[indice].texto)
			assert_int(texto.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		assert_int(vistas).is_equal(mensajes.filter(_es_del_bloque).size())


func test_pedir_un_tramo_en_la_jornada_del_lector_no_emite_para_el_bloque() -> void:  # AC-INV-068
	var sistema: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	var pedidos: Array[String] = []
	sistema.tramo_de_pista_pedido.connect(func(pista: String) -> void: pedidos.append(pista))
	sistema.abrir_jornada(JORNADA_DEL_LECTOR)
	sistema.pedir_alternar(false)
	sistema.pedir_chat(Conversacion.Interlocutor.YASMIN)
	var mensajes := sistema.bandeja().mensajes_de(Conversacion.Interlocutor.YASMIN)
	var con_tramo := mensajes.filter(
		func(mensaje: Mensaje) -> bool: return not mensaje.tramo_de_pista.is_empty()
	)
	assert_array(con_tramo).is_not_empty()
	if con_tramo.is_empty():
		return
	var control: Mensaje = con_tramo[0]
	for mensaje: Mensaje in mensajes.filter(_es_del_bloque):
		sistema.pedir_tramo(mensaje.identidad, mensaje.tramo_de_pista)
		sistema.pedir_tramo(mensaje.identidad, control.tramo_de_pista)
	assert_array(pedidos).is_empty()
	sistema.pedir_tramo(control.identidad, control.tramo_de_pista)
	assert_array(pedidos).is_equal([control.pista])
