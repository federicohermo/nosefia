## El Esc que cierra el celular, por el camino que recorre en el juego: un evento de teclado que
## cruza el árbol del almacén. En la web ese Esc también suelta el cursor, y la pausa no puede
## leerlo como un pedido propio.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

var _almacen: Node3D
var _ruta_guardado: String


func before_test() -> void:
	_ruta_guardado = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://esc_con_el_celular.guardado"
	Guardado.new().borrar()
	_almacen = ALMACEN.instantiate()
	_almacen.set(
		"_partida",
		Partida.desde(
			PartidaSerializada.sanear({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA})
		)
	)
	get_tree().root.add_child(_almacen)


func after_test() -> void:
	get_tree().paused = false
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in _almacen.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	_almacen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_guardado


func _tecla(codigo: Key) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = true
	Input.parse_input_event(evento)
	await get_tree().process_frame
	evento.pressed = false
	Input.parse_input_event(evento)


func _celular() -> CelularDelEmpleado:
	return _almacen.get_node("Interfaz/CelularDelEmpleado")


func _pausa() -> ControlDePausa:
	return _almacen.get_node("Interfaz/ControlDePausa")


## Lo que hace el navegador tras el Esc: el cursor que el juego tenía tomado queda suelto, y el
## nodo lo mide en el cuadro de física siguiente. En headless el motor nunca lo tiene tomado, así
## que lo de antes se escribe a mano, como en `control_de_pausa_test`.
func _el_navegador_suelta_el_cursor() -> void:
	_pausa().set("_cursor_antes", true)
	_pausa().call("_mirar_el_cursor")


func _clic_izquierdo() -> InputEventMouseButton:
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	return evento


## Un navegador que sólo da el cursor ante un clic o una tecla distinta de Esc: `rechaza[0]` lo
## niega, y el modo no cambia. Devuelve las escrituras que llegaron a tomar el cursor.
func _con_un_navegador_que_rechaza(rechaza: Array[bool]) -> Array[Input.MouseMode]:
	var jugador: Node3D = _almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set("_en_web", true)
	var modo: Array[Input.MouseMode] = [Input.MOUSE_MODE_VISIBLE]
	var tomas: Array[Input.MouseMode] = []
	jugador.set("_leer_cursor", func() -> Input.MouseMode: return modo[0])
	jugador.set(
		"_escribir_cursor",
		func(pedido: Input.MouseMode) -> void:
			if pedido == Input.MOUSE_MODE_CAPTURED:
				tomas.append(pedido)
			if not (rechaza[0] and pedido == Input.MOUSE_MODE_CAPTURED):
				modo[0] = pedido
	)
	return tomas


func test_el_primer_clic_tras_el_esc_toma_el_cursor_y_no_hace_nada_mas() -> void:  # AC-INV-070
	var rechaza: Array[bool] = [false]
	var tomas := _con_un_navegador_que_rechaza(rechaza)
	var jugador: Node3D = _almacen.get("_jugador")
	await _tecla(KEY_Q)
	rechaza[0] = true
	await _tecla(KEY_ESCAPE)
	assert_bool(_celular().celular().abierto()).is_false()
	tomas.clear()
	rechaza[0] = false
	jugador.call("_unhandled_input", _clic_izquierdo())
	assert_array(tomas).is_equal([Input.MOUSE_MODE_CAPTURED])
	assert_bool(jugador.call("uso_es_primario")).is_false()
	jugador.call("_unhandled_input", _clic_izquierdo())
	assert_bool(jugador.call("uso_es_primario")).is_true()


func test_tomar_el_cursor_en_la_web_pide_la_pantalla_completa() -> void:  # AC-SAV-036
	var rechaza: Array[bool] = [false]
	_con_un_navegador_que_rechaza(rechaza)
	var jugador: Node3D = _almacen.get("_jugador")
	var pedidos: Array[int] = [0]
	jugador.set("_pedir_pantalla_completa", func() -> void: pedidos[0] += 1)
	jugador.call("_unhandled_input", _clic_izquierdo())
	assert_int(pedidos[0]).is_equal(1)
	jugador.call("_unhandled_input", _clic_izquierdo())
	assert_int(pedidos[0]).is_equal(1)


func test_el_cursor_que_suelta_el_esc_del_celular_no_pausa() -> void:  # AC-INV-070
	await _tecla(KEY_Q)
	assert_bool(_celular().celular().abierto()).is_true()
	await _tecla(KEY_ESCAPE)
	assert_bool(_celular().celular().abierto()).is_false()
	_el_navegador_suelta_el_cursor()
	assert_bool(get_tree().paused).is_false()
	assert_bool((_almacen.get_node("Interfaz/MenuDePausa") as CanvasLayer).visible).is_false()


func test_pasada_la_gracia_un_cursor_perdido_y_el_esc_siguiente_pausan() -> void:  # AC-INV-070
	await _tecla(KEY_Q)
	await _tecla(KEY_ESCAPE)
	_pausa()._physics_process(Pausa.GRACIA_TRAS_ESC)
	_el_navegador_suelta_el_cursor()
	assert_bool(get_tree().paused).is_true()
	get_tree().paused = false
	await _tecla(KEY_ESCAPE)
	assert_bool(get_tree().paused).is_true()
