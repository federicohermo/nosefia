extends GdUnitTestSuite

const Avance := preload("res://test/avance_de_devolucion.gd")
const JEFE := Conversacion.Interlocutor.JEFE
const YASMIN := Conversacion.Interlocutor.YASMIN
var _almacen: Node3D
var _ruta_anterior: String
var _tamano_anterior: Vector2i


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	_tamano_anterior = get_window().size
	get_window().size = Vector2i(1920, 1080)
	Guardado.ruta_por_defecto = "user://chats_jornada_2_430.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_almacen):
		_almacen.hide()
		await _cuadros(2)
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await _cuadros(3)
	_almacen = null
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_anterior
	get_window().size = _tamano_anterior


func _cuadros(cuantos: int) -> void:
	for _cuadro: int in cuantos:
		await get_tree().process_frame


func _abrir(partida: Partida = null) -> void:
	var escena := load("res://src/escenas/almacen.tscn") as PackedScene
	_almacen = escena.instantiate()
	if partida != null:
		_almacen.set("_partida", partida)
	add_child(_almacen)
	(_almacen.get_node("Interfaz/PersianaDeLaNoche") as PersianaDeLaNoche).terminar()
	(_almacen.get("_reloj") as Node).set_process(false)
	await _cuadros(3)


func _celular() -> CelularDelEmpleado:
	return _almacen.get("_celular")


func _pantalla() -> PantallaDelCelular:
	return _almacen.get("_pantalla_del_celular")


func _q() -> void:
	var tecla := InputEventAction.new()
	tecla.action = Celular.ACCION
	tecla.pressed = true
	_almacen.call("_unhandled_input", tecla)
	Avance.terminar_movimiento(_almacen.get("_pantalla") as PantallaDeDevolucion)
	await _cuadros(3)


func _clic(punto: Vector2) -> void:
	for apretado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = apretado
		evento.position = punto
		get_viewport().push_input(evento)
	await _cuadros(3)


func _checkpoint() -> Partida:
	var partida := Partida.nueva()
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		tarea.completar()
	partida.cerrar_la_jornada(partida.obligatorias().size())
	return partida


# AC-INV-039, AC-INV-056, AC-SAV-027
func test_checkpoint_real_abre_dos_chats_sin_intro_y_con_devolucion_fechada() -> void:
	assert_bool(Guardado.new().escribir(PoliticaDeGuardado.datos(_checkpoint()))).is_true()
	await _abrir()
	assert_int((_almacen.get("_partida") as Partida).jornada()).is_equal(2)
	assert_bool((_almacen.get("_instrucciones") as CanvasLayer).visible).is_false()
	var bandeja := _celular().bandeja()
	assert_int(bandeja.no_leidos(YASMIN)).is_equal(15)
	var jefe := bandeja.mensajes_de(JEFE)
	assert_int(jefe.size()).is_equal(23)
	assert_bool(jefe[19].identidad.begins_with("DEVOLUCION_J1_")).is_true()
	assert_str(jefe[21].identidad).is_equal("J2_CONTENEDOR_FOTO")
	await _q()
	var lista: VBoxContainer = _pantalla().get("_mensajes")
	assert_int(lista.get_child_count()).is_equal(2)
	var fila := lista.get_child(1).get_child(0)
	assert_str((fila.find_child("NoLeidos", true, false).get_child(0) as Label).text).is_equal("15")
	await _clic((lista.get_child(1) as Button).get_global_rect().get_center())
	assert_int(_celular().celular().chat()).is_equal(YASMIN)
	assert_int(bandeja.no_leidos(YASMIN)).is_zero()
	assert_int(bandeja.no_leidos(JEFE)).is_equal(23)
	var reloj := _almacen.get("_reloj") as RelojDelTurno
	var turno := reloj.get("_turno") as Turno
	var antes := turno.tiempo_restante()
	reloj.avanzar(30.0)
	assert_float(turno.tiempo_restante()).is_equal(antes - Ritmo.escalar(30.0))


# AC-INV-041, AC-INV-042
func test_solo_el_tramo_real_pide_pista_y_foto_vuelve_al_mismo_scroll() -> void:
	await _abrir(_checkpoint())
	var pedidos: Array[String] = []
	_celular().tramo_de_pista_pedido.connect(func(id: String) -> void: pedidos.append(id))
	await _q()
	var lista: VBoxContainer = _pantalla().get("_mensajes")
	await _clic((lista.get_child(1) as Button).get_global_rect().get_center())
	var texto := (
		lista.get_child(5).find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
	)
	var scroll: ScrollContainer = _pantalla().get("_scroll")
	scroll.ensure_control_visible(texto)
	await _cuadros(4)
	assert_str(texto.get_parsed_text()).is_equal(
		"y te aviso q acá siempre falta algo o anda todo a medias"
	)
	var fuente := texto.get_theme_font("normal_font")
	var tamano := texto.get_theme_font_size("normal_font_size")
	var alto := fuente.get_height(tamano) / 2.0
	var prefijo := fuente.get_string_size("y te aviso q ", HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var punto := texto.get_global_transform() * Vector2(prefijo + 8.0, alto)
	assert_bool(scroll.get_global_rect().has_point(punto)).is_true()
	await _clic(texto.get_global_transform() * Vector2(8.0, alto))
	assert_array(pedidos).is_empty()
	await _clic(punto)
	assert_array(pedidos).is_equal(["2A"])
	await _clic(punto)
	assert_array(pedidos).is_equal(["2A", "2A"])
	var jugador: Node = _almacen.get("_jugador")
	assert_int((jugador.get("examen") as Examen).hallazgos().cantidad()).is_zero()
	_celular().pedir_volver()
	_celular().pedir_chat(JEFE)
	await _cuadros(4)
	var foto := (
		lista.get_child(21).find_children("*", "TextureButton", true, false)[0] as TextureButton
	)
	scroll.ensure_control_visible(foto)
	await _cuadros(4)
	var posicion := scroll.scroll_vertical
	var telefono: Control = _pantalla().get("_telefono")
	var tamano_del_telefono := telefono.size
	var cambios: Array[Vector2] = []
	telefono.resized.connect(func() -> void: cambios.append(telefono.size))
	await _clic(foto.get_global_rect().get_center())
	assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.FOTO)
	assert_str((_pantalla().get("_adjunto") as RichTextLabel).text).is_equal(
		(
			"Buen día, pibe. Hoy te pido que tires la basura de todos los tachos del local "
			+ "en el contenedor. Saludos"
		)
	)
	await _clic((_pantalla().get("_telefono") as Control).get_global_rect().get_center())
	assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.CHAT)
	assert_int(_celular().celular().chat()).is_equal(JEFE)
	assert_int(scroll.scroll_vertical).is_equal(posicion)
	for cambio: Vector2 in cambios:
		assert_bool(cambio.is_equal_approx(tamano_del_telefono)).is_true()
