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


func _conversacion() -> Conversacion:
	var conversacion := Conversacion.new()
	conversacion.nombre = "Contacto"
	var mensaje := Mensaje.new()
	mensaje.de_quien = conversacion.nombre
	mensaje.texto = "Mensaje"
	conversacion.mensajes.append(mensaje)
	return conversacion


func _con_marco_de_foco(pantalla: PantallaDelCelular) -> Array[String]:
	var con_marco: Array[String] = []
	for hijo: Node in pantalla.find_children("*", "Control", true, false):
		if not (hijo is Button or hijo is LineEdit):
			continue
		var control := hijo as Control
		if control.focus_mode == Control.FOCUS_NONE:
			continue
		var estilo := control.get_theme_stylebox("focus")
		if estilo is StyleBoxFlat and (estilo as StyleBoxFlat).get_border_width_min() > 0:
			con_marco.append(str(hijo.name))
	return con_marco


func test_el_menu_no_dibuja_marco_de_foco_en_sus_controles() -> void:
	var pantalla := _pantalla()
	pantalla.mostrar_menu(Bandeja.new([_conversacion()]))
	await _cuadros()
	assert_array(_con_marco_de_foco(pantalla)).is_empty()


func test_el_chat_no_dibuja_marco_de_foco_en_sus_controles() -> void:
	var pantalla := _pantalla()
	var conversacion := _conversacion()
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, false, 1, Celular.AL_FINAL, true)
	await _cuadros()
	assert_array(_con_marco_de_foco(pantalla)).is_empty()
