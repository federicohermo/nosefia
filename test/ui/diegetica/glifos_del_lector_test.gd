extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")
const JORNADA_DEL_LECTOR := GeneradorDeTickets.JORNADA_SIN_LECTOR
const CALAVERA := 0x1F480
const CARA_APRETADA := 0x1F62C

var _tamano_de_ventana: Vector2i


func before_test() -> void:
	_tamano_de_ventana = get_window().size
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame


func after_test() -> void:
	get_window().size = _tamano_de_ventana
	await get_tree().process_frame
	await get_tree().process_frame


func _burbuja(pantalla: PantallaDelCelular, indice: int) -> PanelContainer:
	var lista: VBoxContainer = pantalla.get("_mensajes")
	for hijo: Node in lista.get_children():
		if hijo.has_meta("indice_de_mensaje") and int(hijo.get_meta("indice_de_mensaje")) == indice:
			return hijo as PanelContainer
	return null


func test_la_calavera_y_la_cara_apretada_se_dibujan_sin_fuentes_del_sistema() -> void:  # AC-INV-068
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	assert_vector(pantalla.get_viewport().get_visible_rect().size).is_equal(Vector2(1920, 1080))
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(JORNADA_DEL_LECTOR)
	var conversacion := bandeja.conversacion_de(Conversacion.Interlocutor.YASMIN)
	var mensajes := bandeja.mensajes_de(conversacion.interlocutor)
	pantalla.mostrar_chat(conversacion, mensajes, false, JORNADA_DEL_LECTOR)
	for caso: Array in [[CALAVERA, "J3_7"], [CARA_APRETADA, "J3_9"]]:
		var indice := mensajes.map(func(m: Mensaje) -> String: return m.identidad).find(caso[1])
		assert_int(indice).is_greater_equal(0)
		var burbuja := _burbuja(pantalla, indice)
		assert_object(burbuja).is_not_null()
		if burbuja == null:
			continue
		var texto := burbuja.find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
		var glifos := texto.get_theme_font("normal_font").get_supported_chars()
		assert_bool(glifos.contains(String.chr(caso[0]))).is_true()
