extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")

var _tamano_de_ventana: Vector2i


func before_test() -> void:
	_tamano_de_ventana = get_window().size
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame


func after_test() -> void:
	get_window().size = _tamano_de_ventana
	await get_tree().process_frame
	await get_tree().process_frame


## El chat de una queja con sus dos botones y el botón de volver, como lo abre el celular.
func _pantalla_con_una_queja() -> PantallaDelCelular:
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var conversacion := Conversacion.new()
	conversacion.nombre = "El Seba"
	conversacion.rol = QuejasDeLaJornada.ROL
	var mensaje := Mensaje.new()
	mensaje.de_quien = conversacion.nombre
	mensaje.texto = "Hola, me devolviste mal el vuelto."
	var mensajes: Array[Mensaje] = [mensaje]
	pantalla.subir()
	pantalla.mostrar_chat(conversacion, mensajes, false, 7, Celular.AL_FINAL, true)
	await get_tree().process_frame
	await get_tree().process_frame
	return pantalla


## Lo que el teléfono deja ver: su rectángulo sin el marco.
func _interior_del_telefono(pantalla: PantallaDelCelular) -> Rect2:
	var telefono: Control = pantalla.get("_telefono")
	var marco := telefono.get_theme_stylebox("panel")
	var escala := telefono.get_global_transform().get_scale()
	var afuera := telefono.get_global_rect()
	return Rect2(
		afuera.position + Vector2(marco.get_margin(SIDE_LEFT), marco.get_margin(SIDE_TOP)) * escala,
		afuera.size - marco.get_minimum_size() * escala
	)


## El rectángulo que ocupa el texto de un botón, en coordenadas de pantalla.
func _rectangulo_del_texto(boton: Button) -> Rect2:
	var escala := boton.get_global_transform().get_scale()
	var medida := boton.get_theme_font("font").get_string_size(
		boton.text, HORIZONTAL_ALIGNMENT_LEFT, -1, boton.get_theme_font_size("font_size")
	)
	var margen := boton.get_theme_stylebox("normal").get_margin(SIDE_LEFT)
	var origen := boton.get_global_rect().position + Vector2(margen, 0.0) * escala
	return Rect2(origen, medida * escala)


func test_el_texto_de_cada_opcion_queda_dentro_de_su_boton_y_del_telefono() -> void:
	var pantalla := await _pantalla_con_una_queja()
	var respuestas: VBoxContainer = pantalla.get("_respuestas")
	var visible := _interior_del_telefono(pantalla)
	assert_int(respuestas.get_child_count()).is_equal(2)
	for hijo: Node in respuestas.get_children():
		var boton := hijo as Button
		var texto := _rectangulo_del_texto(boton)
		assert_bool(boton.get_global_rect().encloses(texto)).is_true()
		assert_bool(visible.encloses(boton.get_global_rect())).is_true()
		assert_bool(visible.encloses(texto)).is_true()


func test_el_rol_del_encabezado_entra_entero_en_el_encabezado() -> void:
	var pantalla := await _pantalla_con_una_queja()
	var rol: Label = pantalla.get("_subtitulo")
	var cabecera: Control = pantalla.get("_cabecera")
	assert_bool(rol.visible).is_true()
	assert_bool(cabecera.get_global_rect().encloses(rol.get_global_rect())).is_true()
	assert_bool(_interior_del_telefono(pantalla).encloses(rol.get_global_rect())).is_true()
	assert_int(rol.get_visible_line_count()).is_equal(rol.get_line_count())
	assert_float(rol.get_minimum_size().y).is_less_equal(rol.size.y)


func test_ningun_texto_del_chat_sale_del_telefono_por_los_costados() -> void:
	var pantalla := await _pantalla_con_una_queja()
	var visible := _interior_del_telefono(pantalla)
	var contenido: Control = pantalla.get("_contenido")
	assert_float(contenido.get_global_rect().position.x).is_greater_equal(visible.position.x - 1.0)
	assert_float(contenido.get_global_rect().end.x).is_less_equal(visible.end.x + 1.0)
	for hijo: Node in contenido.find_children("*", "Control", true, false):
		var control := hijo as Control
		if (
			not control.is_visible_in_tree()
			or not (control is Label or control is RichTextLabel or control is BaseButton)
		):
			continue
		var lugar := control.get_global_rect()
		assert_float(lugar.position.x).is_greater_equal(visible.position.x - 1.0)
		assert_float(lugar.end.x).is_less_equal(visible.end.x + 1.0)
