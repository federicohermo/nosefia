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
	create_timer(180.0).timeout.connect(_vencer)
	_ejercer.call_deferred()


func _vencer() -> void:
	push_error("NATIVO22: tiempo máximo sin final de recorrido")
	quit(1)


func _exigir(condicion: bool, detalle: String) -> void:
	if not condicion:
		_fallos.append(detalle)
		push_error("NATIVO22: " + detalle)


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
			"NATIVO22_CLIC punto=%s mouse=%s hover=%s"
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
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		quit(1)
		return
	_salida = args[0]
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(args[1].to_int(), args[2].to_int())
	_prefijo = "nativo-%d-" % root.size.x
	var guardado: Script = load("res://src/sistemas/marco/guardado.gd")
	guardado.set("ruta_por_defecto", "user://nativo22.guardado")
	var clase: Script = load("res://src/dominio/empleo/partida.gd")
	var partida: RefCounted = clase.call("nueva")
	partida.call("abrir_la_jornada")
	var tareas: Array = partida.call("obligatorias")
	for tarea: RefCounted in tareas:
		tarea.call("completar")
	partida.call("cerrar_la_jornada", tareas.size())
	_local = (load("res://src/escenas/almacen.tscn") as PackedScene).instantiate()
	_local.set("_partida", partida)
	root.add_child(_local)
	_local.get_node("Interfaz/PersianaDeLaNoche").call("terminar")
	(_local.get("_reloj") as Node).set_process(false)
	_celular = _local.get("_celular")
	_pantalla = _local.get("_pantalla_del_celular")
	_celular.connect("tramo_de_pista_pedido", func(id: String) -> void: _pedidos.append(id))
	await _cuadros(12)
	_exigir(root.get_visible_rect().size == Vector2(root.size), "viewport incorrecto")
	var expediente: RefCounted = partida.get("expediente")
	var colilla := _local.get_node("Objetos/Colilla") as RigidBody3D
	var jugador := _local.get("_jugador") as CharacterBody3D
	var camara: Camera3D = jugador.get("_camara")
	jugador.call(
		"ubicar", Transform3D(Basis.IDENTITY, colilla.global_position + Vector3(0, 0, 0.75))
	)
	camara.look_at(colilla.global_position)
	for _paso: int in 12:
		await physics_frame
	jugador.call("_leer_la_mira")
	var rayo := PhysicsRayQueryParameters3D.create(camara.global_position, colilla.global_position)
	rayo.exclude = [jugador.get_rid()]
	var golpe := jugador.get_world_3d().direct_space_state.intersect_ray(rayo)
	_exigir(golpe.get("collider") == colilla, "el rayo no encuentra la colilla real")
	_exigir(jugador.is_on_floor(), "el jugador no tiene piso")
	_exigir(jugador.call("enfocado") == colilla, "la mira no enfoca la colilla")
	_exigir(expediente.call("identidades").is_empty(), "mirar registró una pista")
	await _foto("colilla-en-piso")
	await _tecla(KEY_E)
	_exigir(expediente.call("identidades").is_empty(), "E registró una pista levantable")
	await _foto("colilla-pensamiento")
	await _clic(Vector2(root.size) / 2.0)
	var agarre: Node = _local.get("_agarre")
	_exigir(agarre.call("cuerpo_sostenido") == colilla, "el clic no agarró la colilla")
	_exigir(expediente.call("identidades") == PackedStringArray(["2B"]), "el agarre no anotó2B")
	await _foto("colilla-en-mano")
	agarre.call("soltar", false)
	await _q()
	var lista: VBoxContainer = _pantalla.get("_mensajes")
	_exigir(lista.get_child_count() == 2, "Notas apareció en menúJ2")
	await _foto("menu-j2-sin-notas")
	await _clic((lista.get_child(1) as Control).get_global_rect().get_center())
	var scroll: ScrollContainer = _pantalla.get("_scroll")
	scroll.scroll_vertical = 0
	await _cuadros(4)
	var texto := (
		_burbuja(lista, 5).find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
	)
	scroll.ensure_control_visible(texto)
	await _cuadros(4)
	var fuente := texto.get_theme_font("normal_font")
	var tamano := texto.get_theme_font_size("normal_font_size")
	var prefijo := fuente.get_string_size("y te aviso q ", HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	await _clic(texto.get_global_transform() * Vector2(8, fuente.get_height(tamano) / 2))
	_exigir(expediente.call("identidades") == PackedStringArray(["2B"]), "el prefijo anotó2A")
	var punto := texto.get_global_transform() * Vector2(prefijo + 8, fuente.get_height(tamano) / 2)
	_exigir(scroll.get_global_rect().has_point(punto), "el tramo queda fuera del scroll")
	await _clic(punto)
	await _clic(punto)
	_exigir(_pedidos == ["2A", "2A"], "faltan los dos pedidos reales del tramo")
	_exigir(
		expediente.call("identidades") == PackedStringArray(["2B", "2A"]),
		"el registro no es idempotente"
	)
	var notas: Array = expediente.call("mensajes_de_notas")
	_exigir(notas.size() == 4, "Notas no tiene los dos pares")
	await _foto("yasmin-tramo-registrado")
	await _q()
	var reloj: Node = _local.get("_reloj")
	var reglas: Script = load("res://src/dominio/reglas.gd")
	var ritmo: Script = load("res://src/dominio/jornada/ritmo.gd")
	reloj.call(
		"avanzar",
		(
			float(reglas.get_script_constant_map()["DURACION_DEL_TURNO"])
			/ float(ritmo.get_script_constant_map()["SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL"])
		)
	)
	await _cuadros(60)
	var devolucion: Node = _local.get("_pantalla")
	for _paso: int in 30:
		if devolucion.call("opcion_a_la_vista"):
			break
		devolucion.call("_process", 1.0)
		await _cuadros()
	_exigir(partida.call("jornada") == 3, "el cierre no dejó jornada3 pendiente")
	_celular.call("mostrar_fijo", 4)
	await _cuadros(60)
	_exigir(_celular.call("celular").call("fijo"), "Notas no abrió fija al cierre")
	_exigir(_rotulos(lista) == ["HOY"], "NotasJ2 no tiene contexto cerradoHOY")
	for indice: int in [0, 2]:
		var boton := (
			_burbuja(lista, indice).find_children("*", "TextureButton", true, false)[0]
			as TextureButton
		)
		scroll.ensure_control_visible(boton)
		await _cuadros(4)
		await _foto("notas-j2-par-%d" % indice)
		var anterior := scroll.scroll_vertical
		await _clic(boton.get_global_rect().get_center())
		_exigir(_celular.call("celular").call("pantalla") == 2, "la foto no amplía")
		_exigir(
			(_pantalla.get("_adjunto") as RichTextLabel).text == notas[indice + 1].get("texto"),
			"adjunto de otra pista"
		)
		await _foto("notas-j2-foto-%d" % indice)
		await _clic((_pantalla.get("_telefono") as Control).get_global_rect().get_center())
		_exigir(scroll.scroll_vertical == anterior, "cerrar foto altera scroll")
	await _q()
	_exigir(_celular.call("celular").call("abierto"), "Q cerró Notas fija")
	await _foto("notas-j2-q-bloqueada")
	# Preparación de la apertura siguiente, sin implementar la selección de hipótesis de436.
	(_local.get("_ciclo") as Node).call("abrir_la_jornada")
	_local.get_node("Interfaz/PersianaDeLaNoche").call("terminar")
	(_local.get("_reloj") as Node).set_process(false)
	await _cuadros(12)
	_exigir(partida.get("expediente") == expediente, "la apertura sustituyó el expediente")
	await _q()
	_exigir(lista.get_child_count() == 3, "Notas no aparece en menúJ3")
	await _foto("menu-j3-con-notas")
	await _clic((lista.get_child(2) as Control).get_global_rect().get_center())
	_exigir(_celular.call("celular").call("chat") == 4, "el botón no abrió Notas")
	_exigir(not _celular.call("celular").call("fijo"), "el chat del menú quedó fijo")
	_exigir(_rotulos(lista) == ["AYER"], "NotasJ2 no es AYER duranteJ3")
	_exigir(
		expediente.call("identidades") == PackedStringArray(["2B", "2A"]),
		"abrir otra jornada alteró pistas"
	)
	_exigir(expediente.call("mensajes_de_notas").size() == 4, "la apertura duplicó mensajes")
	await _foto("notas-j3-ayer")
	var informe := FileAccess.open(_salida.path_join(_prefijo + "recorrido.json"), FileAccess.WRITE)
	informe.store_string(
		JSON.stringify(
			{
				"capturas": _capturas,
				"pedidos": _pedidos,
				"fallos": _fallos,
				"pistas": expediente.call("identidades"),
				"notas": notas.size(),
				"jornada_final": partida.call("jornada")
			},
			"\t"
		)
	)
	informe.close()
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in _local.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	_local.queue_free()
	_local = null
	_celular = null
	_pantalla = null
	partida = null
	expediente = null
	notas.clear()
	tareas.clear()
	await _cuadros(4)
	print("NATIVO22_FINAL resolucion=%s fallos=%d" % [root.size, _fallos.size()])
	_salir.call_deferred(0 if _fallos.is_empty() else 1)


func _tecla(codigo: Key) -> void:
	for pulsado: bool in [true, false]:
		var evento := InputEventKey.new()
		evento.physical_keycode = codigo
		evento.keycode = codigo
		evento.pressed = pulsado
		root.push_input(evento, true)
		await process_frame
	await _cuadros(4)


func _salir(codigo: int) -> void:
	quit(codigo)


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
