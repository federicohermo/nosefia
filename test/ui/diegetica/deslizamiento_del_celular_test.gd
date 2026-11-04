extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")
const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")
const MEDIO_RECORRIDO := 50000
const UN_CUADRO := 25000

var _tamano_de_ventana: Vector2i
var _reloj: Array[int] = [0]


func before_test() -> void:
	_tamano_de_ventana = get_window().size
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame


func after_test() -> void:
	get_window().size = _tamano_de_ventana
	await get_tree().process_frame
	await get_tree().process_frame


func _pantalla_arriba() -> PantallaDelCelular:
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	await get_tree().process_frame
	_reloj[0] = 0
	pantalla.set("_ahora", func() -> int: return _reloj[0])
	pantalla.subir()
	_avanzar(pantalla, int(RecorridoDelCelular.DURACION * 1000000.0) + UN_CUADRO)
	return pantalla


func _avanzar(pantalla: PantallaDelCelular, microsegundos: int) -> void:
	AvanceDeDevolucion.animar_celular(pantalla, _reloj, microsegundos)


func _terminar_el_deslizamiento(pantalla: PantallaDelCelular) -> void:
	_avanzar(pantalla, int(RecorridoDelCelular.DURACION * 1000000.0) + UN_CUADRO)


func _conversacion(nombre: String, quien: Conversacion.Interlocutor) -> Conversacion:
	var conversacion := Conversacion.new()
	conversacion.nombre = nombre
	conversacion.interlocutor = quien
	for indice in 3:
		var mensaje := Mensaje.new()
		mensaje.de_quien = nombre
		mensaje.texto = "Mensaje %d de %s" % [indice, nombre]
		conversacion.mensajes.append(mensaje)
	return conversacion


func _bandeja() -> Bandeja:
	var chats: Array[Conversacion] = [
		_conversacion("Ana", Conversacion.Interlocutor.JEFE),
		_conversacion("Beto", Conversacion.Interlocutor.YASMIN),
	]
	return Bandeja.new(chats)


func _abrir(
	pantalla: PantallaDelCelular, bandeja: Bandeja, indice: int, fijo: bool = false
) -> void:
	var conversacion := bandeja.conversaciones()[indice]
	pantalla.mostrar_chat(conversacion, bandeja.mensajes_de(conversacion.interlocutor), fijo, 1)


func _contenido(pantalla: PantallaDelCelular) -> Control:
	return pantalla.get("_contenido")


func _ancho(pantalla: PantallaDelCelular) -> float:
	return (pantalla.get("_capa") as Control).size.x


func _burbujas_visibles(pantalla: PantallaDelCelular) -> int:
	var cuenta := 0
	for hijo: Node in (pantalla.get("_mensajes") as VBoxContainer).get_children():
		if hijo.has_meta("indice_de_mensaje") and not hijo.is_queued_for_deletion():
			cuenta += 1
	return cuenta


func test_abrir_un_chat_lo_hace_entrar_desde_la_derecha() -> void:  # AC-INV-114
	var pantalla := await _pantalla_arriba()
	var bandeja := _bandeja()
	pantalla.mostrar_menu(bandeja)
	_abrir(pantalla, bandeja, 0)
	var ancho := _ancho(pantalla)
	assert_float(ancho).is_greater(0.0)
	assert_float(_contenido(pantalla).offset_left).is_equal(ancho)
	assert_object(pantalla.get("_lista_quieta")).is_not_null()
	_avanzar(pantalla, MEDIO_RECORRIDO)
	var a_medias := _contenido(pantalla).offset_left
	assert_float(a_medias).is_between(0.0, ancho)
	assert_float(a_medias).is_not_equal(ancho)
	_avanzar(pantalla, UN_CUADRO)
	assert_float(_contenido(pantalla).offset_left).is_less(a_medias)
	_terminar_el_deslizamiento(pantalla)
	assert_float(_contenido(pantalla).offset_left).is_equal(0.0)
	assert_object(pantalla.get("_lista_quieta")).is_null()


func test_volver_hace_salir_el_chat_por_la_derecha() -> void:  # AC-INV-115
	var pantalla := await _pantalla_arriba()
	var bandeja := _bandeja()
	pantalla.mostrar_menu(bandeja)
	_abrir(pantalla, bandeja, 0)
	_terminar_el_deslizamiento(pantalla)
	pantalla.mostrar_menu(bandeja)
	var ancho := _ancho(pantalla)
	var saliente: Control = pantalla.get("_chat_saliente")
	assert_object(saliente).is_not_null()
	assert_float(saliente.offset_left).is_equal(0.0)
	_avanzar(pantalla, MEDIO_RECORRIDO)
	var a_medias := saliente.offset_left
	assert_float(a_medias).is_between(0.0, ancho)
	assert_float(a_medias).is_greater(0.0)
	assert_float(_contenido(pantalla).offset_left).is_equal(0.0)
	_avanzar(pantalla, UN_CUADRO)
	assert_float(saliente.offset_left).is_greater(a_medias)
	assert_float(_contenido(pantalla).offset_left).is_equal(0.0)
	_terminar_el_deslizamiento(pantalla)
	assert_object(pantalla.get("_chat_saliente")).is_null()
	assert_bool((pantalla.get("_pie") as Control).visible).is_false()


func test_un_chat_fijo_aparece_sin_deslizarse() -> void:  # AC-INV-116
	var pantalla := await _pantalla_arriba()
	var bandeja := _bandeja()
	pantalla.mostrar_menu(bandeja)
	_abrir(pantalla, bandeja, 0, true)
	assert_float(_contenido(pantalla).offset_left).is_equal(0.0)
	assert_object(pantalla.get("_lista_quieta")).is_null()
	assert_object(pantalla.get("_chat_saliente")).is_null()
	assert_bool((pantalla.get("_volver") as Control).visible).is_false()


func test_volver_en_plena_entrada_sigue_desde_donde_iba() -> void:  # AC-INV-117
	var pantalla := await _pantalla_arriba()
	var bandeja := _bandeja()
	pantalla.mostrar_menu(bandeja)
	_abrir(pantalla, bandeja, 0)
	_avanzar(pantalla, MEDIO_RECORRIDO)
	var donde_iba := _contenido(pantalla).offset_left
	pantalla.mostrar_menu(bandeja)
	var saliente: Control = pantalla.get("_chat_saliente")
	assert_object(saliente).is_not_null()
	assert_object(pantalla.get("_lista_quieta")).is_null()
	assert_float(saliente.offset_left).is_equal_approx(donde_iba, 1.0)
	_terminar_el_deslizamiento(pantalla)
	assert_object(pantalla.get("_chat_saliente")).is_null()
	assert_str((pantalla.get("_titulo") as Label).text).is_equal("CHATS")
	assert_float(_contenido(pantalla).offset_left).is_equal(0.0)


func test_abrir_otro_chat_durante_la_salida_deja_un_solo_chat() -> void:  # AC-INV-117
	var pantalla := await _pantalla_arriba()
	var bandeja := _bandeja()
	pantalla.mostrar_menu(bandeja)
	_abrir(pantalla, bandeja, 0)
	_terminar_el_deslizamiento(pantalla)
	pantalla.mostrar_menu(bandeja)
	_avanzar(pantalla, MEDIO_RECORRIDO)
	_abrir(pantalla, bandeja, 1)
	assert_object(pantalla.get("_chat_saliente")).is_null()
	_terminar_el_deslizamiento(pantalla)
	assert_str((pantalla.get("_titulo") as Label).text).is_equal("BETO")
	assert_int(_burbujas_visibles(pantalla)).is_equal(3)
	assert_float(_contenido(pantalla).offset_left).is_equal(0.0)
	assert_object(pantalla.get("_lista_quieta")).is_null()


func test_abrir_otro_chat_durante_la_entrada_deja_un_solo_chat() -> void:  # AC-INV-117
	var pantalla := await _pantalla_arriba()
	var bandeja := _bandeja()
	pantalla.mostrar_menu(bandeja)
	_abrir(pantalla, bandeja, 0)
	_avanzar(pantalla, MEDIO_RECORRIDO)
	_abrir(pantalla, bandeja, 1)
	_terminar_el_deslizamiento(pantalla)
	assert_str((pantalla.get("_titulo") as Label).text).is_equal("BETO")
	assert_int(_burbujas_visibles(pantalla)).is_equal(3)
	assert_float(_contenido(pantalla).offset_left).is_equal(0.0)
	assert_object(pantalla.get("_lista_quieta")).is_null()
	assert_object(pantalla.get("_chat_saliente")).is_null()


func test_bajar_el_celular_con_un_chat_entrando_lo_deja_en_su_lugar() -> void:  # AC-INV-118
	var pantalla := await _pantalla_arriba()
	var bandeja := _bandeja()
	pantalla.mostrar_menu(bandeja)
	_abrir(pantalla, bandeja, 0)
	_avanzar(pantalla, MEDIO_RECORRIDO)
	assert_float(_contenido(pantalla).offset_left).is_greater(0.0)
	pantalla.bajar()
	assert_float(_contenido(pantalla).offset_left).is_equal(0.0)
	assert_object(pantalla.get("_lista_quieta")).is_null()
	pantalla.subir()
	_avanzar(pantalla, int(RecorridoDelCelular.DURACION * 1000000.0) + UN_CUADRO)
	assert_str((pantalla.get("_titulo") as Label).text).is_equal("ANA")
	assert_float(_contenido(pantalla).offset_left).is_equal(0.0)
	assert_object(pantalla.get("_lista_quieta")).is_null()


func test_bajar_el_celular_con_un_chat_saliendo_deja_la_lista_sola() -> void:  # AC-INV-118
	var pantalla := await _pantalla_arriba()
	var bandeja := _bandeja()
	pantalla.mostrar_menu(bandeja)
	_abrir(pantalla, bandeja, 0)
	_terminar_el_deslizamiento(pantalla)
	pantalla.mostrar_menu(bandeja)
	_avanzar(pantalla, MEDIO_RECORRIDO)
	pantalla.bajar()
	assert_object(pantalla.get("_chat_saliente")).is_null()
	pantalla.subir()
	_avanzar(pantalla, int(RecorridoDelCelular.DURACION * 1000000.0) + UN_CUADRO)
	assert_str((pantalla.get("_titulo") as Label).text).is_equal("CHATS")
	assert_object(pantalla.get("_chat_saliente")).is_null()
	assert_float(_contenido(pantalla).offset_left).is_equal(0.0)
