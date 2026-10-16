extends SceneTree

var _local: Node3D
var _celular: Node
var _pantalla: Node
var _salida: String
var _prefijo: String
var _pedidos: Array[String] = []
var _fallos: Array[String] = []
var _capturas: Array[Dictionary] = []


func _initialize() -> void:
	create_timer(120.0).timeout.connect(_vencer)
	_ejercer.call_deferred()


func _vencer() -> void:
	push_error("NATIVO431: tiempo máximo sin final de recorrido")
	quit(1)


func _exigir(condicion: bool, detalle: String) -> void:
	if not condicion:
		_fallos.append(detalle)
		push_error("NATIVO431: " + detalle)


func _cuadros(cantidad: int = 4) -> void:
	for _cuadro: int in cantidad:
		await process_frame


func _clic(punto: Vector2) -> void:
	Input.warp_mouse(punto)
	await _cuadros(2)
	var movimiento := InputEventMouseMotion.new()
	movimiento.position = punto
	movimiento.global_position = punto
	root.push_input(movimiento, true)
	var hover := root.gui_get_hovered_control()
	print(
		(
			"NATIVO431_CLIC punto=%s mouse=%s hover=%s"
			% [
				punto,
				root.get_mouse_position(),
				str(hover.get_path()) if hover != null else "ninguno"
			]
		)
	)
	for pulsado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = pulsado
		evento.position = punto
		evento.global_position = punto
		root.push_input(evento, true)
		await process_frame
	await _cuadros()


func _q() -> void:
	for pulsado: bool in [true, false]:
		var evento := InputEventKey.new()
		evento.physical_keycode = KEY_Q
		evento.keycode = KEY_Q
		evento.pressed = pulsado
		root.push_input(evento, true)
		await process_frame
	for _cuadro: int in 120:
		if not _pantalla.call("is_processing"):
			break
		await process_frame
	await _cuadros()


func _rueda(indice: int) -> void:
	var scroll: ScrollContainer = _pantalla.get("_scroll")
	var punto := scroll.get_global_rect().get_center()
	Input.warp_mouse(punto)
	await _cuadros(2)
	var movimiento := InputEventMouseMotion.new()
	movimiento.position = punto
	movimiento.global_position = punto
	root.push_input(movimiento, true)
	var rueda := InputEventMouseButton.new()
	rueda.button_index = indice
	rueda.pressed = true
	rueda.position = punto
	rueda.global_position = punto
	root.push_input(rueda, true)
	var suelta := rueda.duplicate() as InputEventMouseButton
	suelta.pressed = false
	root.push_input(suelta, true)
	await _cuadros(2)


func _foto(nombre: String) -> void:
	await _cuadros()
	await RenderingServer.frame_post_draw
	var imagen := root.get_texture().get_image()
	_exigir(not imagen.is_empty() and imagen.get_size() == root.size, "captura o viewport inválido")
	_exigir(imagen.save_png(_salida.path_join(_prefijo + nombre + ".png")) == OK, "no guardó PNG")
	var scroll: ScrollContainer = _pantalla.get("_scroll")
	_capturas.append(
		{
			"nombre": _prefijo + nombre,
			"viewport": str(root.size),
			"scroll": scroll.scroll_vertical,
			"cursor": Input.mouse_mode
		}
	)


func _ejercer() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.size() != 3:
		push_error("NATIVO431: se requieren salida, ancho y alto")
		quit(1)
		return
	_salida = argumentos[0]
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(argumentos[1].to_int(), argumentos[2].to_int())
	_prefijo = "nativo-%d-" % root.size.x
	_exigir(not OS.has_feature("web"), "el recorrido de escritorio usa un motor Web")
	var clase: Script = load("res://src/dominio/empleo/partida.gd")
	var partida: RefCounted = clase.call("nueva")
	partida.call("abrir_la_jornada")
	var tareas: Array = partida.call("obligatorias")
	for tarea: RefCounted in tareas:
		tarea.call("completar")
	partida.call("cerrar_la_jornada", tareas.size())
	var escena := load("res://src/escenas/almacen.tscn") as PackedScene
	_local = escena.instantiate()
	_local.set("_partida", partida)
	root.add_child(_local)
	_local.get_node("Interfaz/PersianaDeLaNoche").call("terminar")
	(_local.get("_reloj") as Node).set_process(false)
	_celular = _local.get("_celular")
	_pantalla = _local.get("_pantalla_del_celular")
	_celular.connect("tramo_de_pista_pedido", func(id: String) -> void: _pedidos.append(id))
	await _cuadros(12)
	_exigir(
		root.get_visible_rect().size == Vector2(root.size),
		"el viewport no corresponde a la resolución"
	)
	await _q()
	_exigir(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Q no soltó el cursor")
	var lista: VBoxContainer = _pantalla.get("_mensajes")
	_exigir(lista.get_child_count() == 2, "faltó un chat")
	await _foto("chats")
	await _clic((lista.get_child(1) as Control).get_global_rect().get_center())
	_exigir(_celular.call("celular").call("chat") == 3, "no abrió Yasmín por clic")
	_exigir(_rotulos(lista) == ["HOY"], "Yasmín no tiene un bloque HOY")
	await _foto("yasmin-final")
	var scroll: ScrollContainer = _pantalla.get("_scroll")
	for _paso: int in 120:
		if scroll.scroll_vertical == 0:
			break
		await _rueda(MOUSE_BUTTON_WHEEL_UP)
	_exigir(scroll.scroll_vertical == 0, "la rueda no alcanzó el inicio")
	await _foto("yasmin-inicio")
	var texto := (
		_burbuja(lista, 5).find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
	)
	var fuente := texto.get_theme_font("normal_font")
	var tamano := texto.get_theme_font_size("normal_font_size")
	var prefijo := fuente.get_string_size("y te aviso q ", HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var punto := Vector2.ZERO
	for _paso: int in 120:
		punto = texto.get_global_transform() * Vector2(prefijo + 8, fuente.get_height(tamano) / 2)
		if scroll.get_global_rect().has_point(punto):
			break
		await _rueda(MOUSE_BUTTON_WHEEL_DOWN)
	_exigir(scroll.get_global_rect().has_point(punto), "el tramo quedó fuera del historial visible")
	_exigir(_pedidos.is_empty(), "leer pidió una pista")
	await _clic(texto.get_global_transform() * Vector2(8, fuente.get_height(tamano) / 2))
	_exigir(_pedidos.is_empty(), "el prefijo pidió una pista")
	await _clic(punto)
	await _clic(punto)
	_exigir(_pedidos == ["2A", "2A"], "el tramo no emitió exactamente dos pedidos")
	print(
		(
			"NATIVO431_TRAMO rect=%s fuente_altura=%s prefijo=%s punto=%s pedidos=%s"
			% [texto.get_global_rect(), fuente.get_height(tamano), prefijo, punto, _pedidos]
		)
	)
	var examen: Node = (_local.get("_jugador") as Node).get("examen")
	_exigir(examen.call("hallazgos").call("cantidad") == 0, "el clic alteró el expediente")
	await _foto("yasmin-tramo")
	await _clic((_pantalla.get("_volver") as Control).get_global_rect().get_center())
	await _clic((lista.get_child(0) as Control).get_global_rect().get_center())
	_exigir(_celular.call("celular").call("chat") == 0, "no abrió Enrique por clic")
	_exigir(_rotulos(lista) == ["AYER", "HOY"], "Enrique no separa J1/J2")
	await _foto("enrique")
	var final_del_historial := scroll.scroll_vertical
	scroll.scroll_vertical = 0
	await _cuadros()
	await _foto("enrique-ayer")
	scroll.scroll_vertical = final_del_historial
	await _cuadros()
	if lista.get_child_count() <= 21:
		quit(1)
		return
	var foto := (
		_burbuja(lista, 21).find_children("*", "TextureButton", true, false)[0] as TextureButton
	)
	var posicion := scroll.scroll_vertical
	_exigir(
		scroll.get_global_rect().has_point(foto.get_global_rect().get_center()),
		"la foto no estaba visible"
	)
	await _clic(foto.get_global_rect().get_center())
	_exigir(_celular.call("celular").call("pantalla") == 2, "no amplió la foto")
	_exigir(scroll.scroll_vertical == posicion, "abrir alteró el scroll")
	await _foto("contenedor")
	var foto_abierta: TextureRect = _pantalla.get("_imagen")
	var textura_anterior := foto_abierta.texture
	var clase_devolucion: Script = load("res://src/dominio/empleo/devolucion_del_jefe.gd")
	var intercalado: Resource = clase_devolucion.call(
		"mensaje", "Llegada anterior intercalada", 1, 99
	)
	_celular.call("recibir", 0, intercalado)
	await _cuadros()
	_exigir(foto_abierta.texture == textura_anterior, "la llegada reemplazó la foto ampliada")
	_exigir(scroll.scroll_vertical == posicion, "la llegada con foto alteró scroll")
	_exigir(
		_burbuja(lista, 22).find_children("*", "TextureButton", true, false)[0] == foto,
		"la llegada reconstruyó la foto"
	)
	await _foto("foto-intercalada")
	await _clic((_pantalla.get("_telefono") as Control).get_global_rect().get_center())
	_exigir(_celular.call("celular").call("pantalla") == 1, "cerrar no volvió al chat")
	_exigir(scroll.scroll_vertical == posicion, "cerrar alteró el scroll")
	await _foto("foto-cerrada")
	await _q()
	_exigir(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Q no recuperó el cursor")
	var partida_actual: RefCounted = _local.get("_partida")
	var reloj_actual: Node = _local.get("_reloj")
	var reglas: Script = load("res://src/dominio/reglas.gd")
	var ritmo: Script = load("res://src/dominio/jornada/ritmo.gd")
	reloj_actual.call(
		"avanzar",
		(
			float(reglas.get_script_constant_map()["DURACION_DEL_TURNO"])
			/ float(ritmo.get_script_constant_map()["SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL"])
		)
	)
	await _cuadros(60)
	_exigir(partida_actual.call("jornada") == 3, "el cierre no dejó J3 pendiente")
	_exigir(_rotulos(lista) == ["AYER", "HOY"], "el cierre de J2 cambió a referencia futura")
	var devolucion: Node = _local.get("_pantalla")
	for _paso: int in 30:
		if devolucion.call("opcion_a_la_vista"):
			break
		devolucion.call("_process", 1.0)
		await _cuadros()
	_exigir(devolucion.call("opcion_a_la_vista"), "faltó Continuar al terminar la devolución")
	await _foto("cierre-jornada-2-hoy")
	for hijo: Node in lista.get_children():
		if hijo.has_meta("separador_de_jornada") and hijo.get_meta("separador_de_jornada") == 2:
			scroll.ensure_control_visible(hijo as Control)
	await _cuadros()
	_exigir(partida_actual.call("jornada") == 3, "la captura de HOY no tiene J3 pendiente")
	await _foto("cierre-jornada-2-rotulo-hoy")
	partida_actual = null
	var informe := FileAccess.open(_salida.path_join(_prefijo + "recorrido.json"), FileAccess.WRITE)
	informe.store_string(
		JSON.stringify({"capturas": _capturas, "pedidos": _pedidos, "fallos": _fallos}, "\t")
	)
	informe.close()
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in _local.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	_local.hide()
	await _cuadros()
	_local.queue_free()
	_local = null
	_celular = null
	_pantalla = null
	partida = null
	tareas.clear()
	await _cuadros()
	print("NATIVO431_FINAL resolucion=%s fallos=%d" % [root.size, _fallos.size()])
	quit(0 if _fallos.is_empty() else 1)


func _burbuja(lista: VBoxContainer, indice: int) -> PanelContainer:
	for hijo: Node in lista.get_children():
		if hijo.has_meta("indice_de_mensaje") and int(hijo.get_meta("indice_de_mensaje")) == indice:
			return hijo as PanelContainer
	return null


func _rotulos(lista: VBoxContainer) -> Array[String]:
	var rotulos: Array[String] = []
	for hijo: Node in lista.get_children():
		if hijo is Label:
			rotulos.append(hijo.text)
	return rotulos
