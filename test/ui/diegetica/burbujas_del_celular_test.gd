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


func _mensaje(texto: String, hora: String) -> Mensaje:
	var mensaje := Mensaje.new()
	mensaje.jornada = 2
	mensaje.texto = texto
	mensaje.hora = hora
	return mensaje


func _chat(interlocutor: Conversacion.Interlocutor, mensajes: Array[Mensaje]) -> Conversacion:
	var chat := Conversacion.new()
	chat.nombre = "Contacto"
	chat.interlocutor = interlocutor
	chat.mensajes = mensajes
	return chat


func _burbujas(pantalla: PantallaDelCelular) -> Array[PanelContainer]:
	var burbujas: Array[PanelContainer] = []
	var lista: VBoxContainer = pantalla.get("_mensajes")
	for hijo: Node in lista.get_children():
		if hijo is PanelContainer:
			burbujas.append(hijo)
	return burbujas


func _textos_de_las_etiquetas(burbuja: PanelContainer) -> Array[String]:
	var textos: Array[String] = []
	for etiqueta: Node in burbuja.find_children("*", "Label", true, false):
		textos.append((etiqueta as Label).text)
	return textos


func test_cada_burbuja_muestra_solo_su_hora_debajo_del_texto() -> void:
	var pantalla := _pantalla()
	var mensajes: Array[Mensaje] = [_mensaje("Hola", "17:34"), _mensaje("Chau", "")]
	pantalla.mostrar_chat(_chat(Conversacion.Interlocutor.YASMIN, mensajes), mensajes, false, 2)
	var burbujas := _burbujas(pantalla)
	assert_array(_textos_de_las_etiquetas(burbujas[0])).is_equal(["17:34"])
	assert_array(_textos_de_las_etiquetas(burbujas[1])).is_empty()


func test_lo_recibido_va_a_la_izquierda_y_las_notas_a_la_derecha() -> void:
	var pantalla := _pantalla()
	var mensajes: Array[Mensaje] = [_mensaje("Hola", "17:34")]
	pantalla.mostrar_chat(_chat(Conversacion.Interlocutor.JEFE, mensajes), mensajes, false, 2)
	assert_int(_burbujas(pantalla)[0].size_flags_horizontal).is_equal(Control.SIZE_SHRINK_BEGIN)
	pantalla.mostrar_chat(_chat(Conversacion.Interlocutor.NOTAS, mensajes), mensajes, false, 2)
	assert_int(_burbujas(pantalla)[0].size_flags_horizontal).is_equal(Control.SIZE_SHRINK_END)


func test_la_burbuja_se_ajusta_al_texto_hasta_un_maximo() -> void:
	var pantalla := _pantalla()
	var largo := "una palabra tras otra hasta llenar bastante más de un renglón de la burbuja"
	var mensajes: Array[Mensaje] = [_mensaje("Hola", ""), _mensaje(largo, ""), _mensaje(largo, "")]
	pantalla.mostrar_chat(_chat(Conversacion.Interlocutor.JEFE, mensajes), mensajes, false, 2)
	await _cuadros()
	var burbujas := _burbujas(pantalla)
	var corta := burbujas[0].get_combined_minimum_size().x
	var larga := burbujas[1].get_combined_minimum_size().x
	assert_float(corta).is_less(larga)
	assert_float(burbujas[2].get_combined_minimum_size().x).is_equal(larga)


func test_el_campo_sigue_sin_poder_escribirse_y_lleva_la_flecha() -> void:
	var pantalla := _pantalla()
	var entrada: LineEdit = pantalla.get("_entrada")
	assert_bool(entrada.editable).is_false()
	assert_object(entrada.find_child("Enviar", false, false)).is_not_null()
