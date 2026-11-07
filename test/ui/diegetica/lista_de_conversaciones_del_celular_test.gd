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


func _menu_con_todas_las_conversaciones(pantalla: PantallaDelCelular) -> ScrollContainer:
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
	var conversaciones: Array[Conversacion] = []
	for quien: int in Conversacion.Interlocutor.values():
		var conversacion := _conversacion(1)
		conversacion.interlocutor = quien as Conversacion.Interlocutor
		conversacion.nombre = "Contacto %d" % quien
		conversaciones.append(conversacion)
	pantalla.mostrar_menu(Bandeja.new(conversaciones))
	for cuadro in 4:
		await get_tree().process_frame
	return pantalla.get("_scroll")


func test_la_lista_larga_abre_arriba_con_la_primera_fila_entera_dentro_del_telefono() -> void:
	var pantalla := _pantalla()
	var scroll := await _menu_con_todas_las_conversaciones(pantalla)
	var lista: VBoxContainer = pantalla.get("_mensajes")
	var telefono: Control = pantalla.get("_telefono")
	assert_float(lista.size.y).is_greater(scroll.size.y)
	assert_int(scroll.scroll_vertical).is_zero()
	var primera := lista.get_child(0) as Control
	assert_float(primera.get_global_rect().position.y).is_greater_equal(
		scroll.get_global_rect().position.y
	)
	assert_float(scroll.get_global_rect().end.y).is_less_equal(telefono.get_global_rect().end.y)


func test_la_rueda_baja_la_lista_hasta_la_ultima_conversacion() -> void:
	var pantalla := _pantalla()
	var scroll := await _menu_con_todas_las_conversaciones(pantalla)
	var lista: VBoxContainer = pantalla.get("_mensajes")
	var ultima := lista.get_child(lista.get_child_count() - 1) as Control
	assert_bool(ultima.get_global_rect().end.y > scroll.get_global_rect().end.y).is_true()
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_DOWN
	rueda.pressed = true
	rueda.position = scroll.get_global_rect().get_center()
	for giro in 60:
		get_viewport().push_input(rueda, true)
		await get_tree().process_frame
	assert_int(scroll.scroll_vertical).is_greater(0)
	assert_float(ultima.get_global_rect().end.y).is_less_equal(scroll.get_global_rect().end.y + 1.0)
