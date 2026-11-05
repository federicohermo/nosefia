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
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.subir()
	AvanceDeDevolucion.animar_celular(pantalla, ahora, 250000)
	return pantalla


func _mensaje(indice: int) -> Mensaje:
	var mensaje := Mensaje.new()
	mensaje.de_quien = "Contacto"
	mensaje.texto = "Mensaje %d. Texto de prueba para ocupar la pantalla del celular." % indice
	return mensaje


func _conversacion(cantidad: int) -> Conversacion:
	var conversacion := Conversacion.new()
	conversacion.nombre = "Contacto"
	for indice in cantidad:
		conversacion.mensajes.append(_mensaje(indice))
	return conversacion


func _abrir(
	pantalla: PantallaDelCelular,
	cantidad: int,
	fijo: bool = false,
	primer_nuevo: int = Celular.AL_FINAL
) -> void:
	var conversacion := _conversacion(cantidad)
	pantalla.mostrar_chat(conversacion, conversacion.mensajes, fijo, 1, primer_nuevo)
	await _esperar()


func _esperar() -> void:
	for cuadro in 6:
		await get_tree().process_frame


## Cuántos píxeles bajo el borde superior de la lista queda el mensaje.
func _bajo_el_borde(pantalla: PantallaDelCelular, indice: int) -> float:
	var scroll: ScrollContainer = pantalla.get("_scroll")
	var lista: VBoxContainer = pantalla.get("_mensajes")
	for hijo: Node in lista.get_children():
		if hijo.has_meta("indice_de_mensaje") and int(hijo.get_meta("indice_de_mensaje")) == indice:
			return (hijo as Control).position.y - scroll.scroll_vertical
	return INF


func _fondo(pantalla: PantallaDelCelular) -> int:
	var barra := (pantalla.get("_scroll") as ScrollContainer).get_v_scroll_bar()
	return int(barra.max_value - barra.page)


func test_con_sin_leer_el_primero_queda_arriba_y_los_demas_debajo() -> void:  # AC-INV-160
	var pantalla := _pantalla()
	await _abrir(pantalla, 30, false, 27)
	assert_float(_bajo_el_borde(pantalla, 27)).is_between(-1.0, 1.0)
	assert_float(_bajo_el_borde(pantalla, 28)).is_greater(_bajo_el_borde(pantalla, 27))
	assert_float(_bajo_el_borde(pantalla, 29)).is_greater(_bajo_el_borde(pantalla, 28))


func test_con_mas_sin_leer_que_los_que_entran_la_rueda_alcanza_el_resto() -> void:  # AC-INV-160
	var pantalla := _pantalla()
	await _abrir(pantalla, 60, false, 20)
	var scroll: ScrollContainer = pantalla.get("_scroll")
	assert_float(_bajo_el_borde(pantalla, 20)).is_between(-1.0, 1.0)
	assert_int(scroll.scroll_vertical).is_less(_fondo(pantalla))
	scroll.scroll_vertical = _fondo(pantalla)
	assert_float(_bajo_el_borde(pantalla, 59)).is_less(scroll.size.y)


func test_sin_mensajes_sin_leer_abre_en_el_ultimo() -> void:  # AC-INV-161
	var pantalla := _pantalla()
	await _abrir(pantalla, 30)
	var scroll: ScrollContainer = pantalla.get("_scroll")
	assert_int(_fondo(pantalla)).is_greater(0)
	assert_int(scroll.scroll_vertical).is_equal(_fondo(pantalla))


func test_un_unico_sin_leer_que_es_el_ultimo_queda_arriba() -> void:  # AC-INV-162
	var pantalla := _pantalla()
	await _abrir(pantalla, 30, false, 29)
	assert_float(_bajo_el_borde(pantalla, 29)).is_between(-1.0, 1.0)


func test_un_chat_que_entra_entero_no_se_desplaza() -> void:  # AC-INV-162
	var pantalla := _pantalla()
	await _abrir(pantalla, 1, false, 0)
	assert_int(_fondo(pantalla)).is_less_equal(0)
	assert_int((pantalla.get("_scroll") as ScrollContainer).scroll_vertical).is_zero()


func test_en_el_cierre_el_primer_mensaje_que_llega_queda_arriba() -> void:  # AC-INV-163
	var pantalla := _pantalla()
	await _abrir(pantalla, 30, true)
	pantalla.recibir(_mensaje(30), 30, 30)
	await _esperar()
	assert_float(_bajo_el_borde(pantalla, 30)).is_between(-1.0, 1.0)
	pantalla.recibir(_mensaje(31), 31, 30)
	await _esperar()
	assert_float(_bajo_el_borde(pantalla, 30)).is_between(-1.0, 1.0)
	assert_float(_bajo_el_borde(pantalla, 31)).is_greater(0.0)


func test_en_el_cierre_la_lista_baja_lo_justo_para_ver_la_opcion() -> void:  # AC-INV-163
	var pantalla := _pantalla()
	await _abrir(pantalla, 30, true)
	var scroll: ScrollContainer = pantalla.get("_scroll")
	for indice in range(30, 42):
		pantalla.recibir(_mensaje(indice), indice, 30)
		await _esperar()
	pantalla.mostrar_opcion("CONTINUAR")
	await _esperar()
	var opcion := pantalla.opcion()
	assert_object(opcion).is_not_null()
	assert_float(opcion.position.y + opcion.size.y - scroll.scroll_vertical).is_less_equal(
		scroll.size.y + 1.0
	)
	assert_int(scroll.scroll_vertical).is_equal(_fondo(pantalla))


func test_un_mensaje_que_llega_con_el_chat_abajo_baja_hasta_el() -> void:  # AC-INV-164
	var pantalla := _pantalla()
	await _abrir(pantalla, 30)
	pantalla.recibir(_mensaje(30), 30)
	await _esperar()
	var scroll: ScrollContainer = pantalla.get("_scroll")
	assert_int(scroll.scroll_vertical).is_equal(_fondo(pantalla))
	assert_float(_bajo_el_borde(pantalla, 30)).is_less(scroll.size.y)


func test_un_mensaje_que_llega_con_la_lista_arriba_no_la_mueve() -> void:  # AC-INV-164
	var pantalla := _pantalla()
	await _abrir(pantalla, 30)
	var scroll: ScrollContainer = pantalla.get("_scroll")
	scroll.scroll_vertical = 0
	pantalla.recibir(_mensaje(30), 30)
	await _esperar()
	assert_int(scroll.scroll_vertical).is_zero()
