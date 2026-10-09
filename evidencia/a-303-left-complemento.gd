extends SceneTree

var _fallo: bool = false

func _initialize() -> void:
	call_deferred("_montar")

func _montar() -> void:
	print("SONDA303_PROPIA ", JSON.stringify({"pid": OS.get_process_id(), "proyecto": ProjectSettings.globalize_path("res://")}))
	await _ejercer()
	print("SONDA303_LEFT_SCOPE_LIBERADO")
	call_deferred("quit", 1 if _fallo else 0)

func _ejercer() -> void:
	var almacen: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
	root.add_child(almacen)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	jugador.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var caja: CajaRegistradora = almacen.get_node("Servicios/CajaRegistradora")
	var puesto: StaticBody3D = almacen.get_node("Estructura/cajaregistradora/StaticBody3D")
	var programa: ProgramaDeTickets = almacen.get_node("Interfaz/ProgramaDeTickets")
	var agarre: Agarre = almacen.get("_agarre")
	for _cuadro in 4:
		await physics_frame
	almacen.call("_al_abrir_la_jornada", 3)
	var unidad: ObjetoAgarrable = load("res://src/escenas/objetos/objeto_agarrable.tscn").instantiate()
	unidad.datos = UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI))
	almacen.add_child(unidad)
	_exigir(agarre.pedir_agarrar(unidad.datos, unidad), "Unidad agarrada")
	for pantalla: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = pantalla
		programa.call("_ajustar")
		caja.pedir_borrar()
		puesto.call("abrir")
		for _cuadro in 4:
			await process_frame
		var selector: OptionButton = programa.selectores[0]
		selector.show_popup()
		for _cuadro in 4:
			await process_frame
		var popup := selector.get_popup()
		if not popup.window_input.is_connected(_registrar):
			popup.window_input.connect(_registrar)
		print("LEFT_VENTANA root=", root.size, " visible=", root.get_visible_rect(), " escala=", root.content_scale_factor, " base=", root.content_scale_size, " mouse=", root.get_mouse_position())
		var nativo := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, popup.get_window_id())
		var fuente := popup.get_theme_font("font")
		print("LEFT_METRICA font=", popup.get_theme_font_size("font_size"), " alto=", fuente.get_height(popup.get_theme_font_size("font_size")), " sep=", popup.get_theme_constant("v_separation"), " margen=", popup.get_theme_stylebox("panel").get_content_margin(SIDE_TOP))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/fede_/orca/workspaces/nosefia/darter/.claude/scratch/batch-64-309/303-left-popup-" + str(pantalla.x) + ".png")
		var raiz := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, root.get_window_id())
		print("SONDA303_POPUP_LISTO 2 ", nativo, " ", raiz, " ", popup.position, " ", popup.size, " factor=", popup.content_scale_factor)
		var inicio := Time.get_ticks_msec()
		while caja.generador().en_el_renglon(0) == null and Time.get_ticks_msec() - inicio < 5000:
			await process_frame
		for _cuadro in 4:
			await process_frame
		print("LEFT_SELECCION_REAL indice=", selector.selected, " nombre=", selector.get_item_text(selector.selected))
		var elegida := caja.generador().en_el_renglon(0)
		_exigir(elegida != null, "LEFT real llega al dominio " + str(pantalla.x))
		if elegida == null:
			return
		_exigir(elegida.id == Catalogo.todos()[0].id, "LEFT elige primer producto por ID " + str(pantalla.x))
		_exigir(agarre.manos().sostenido() == unidad.datos, "LEFT conserva mano " + str(pantalla.x))
		_exigir(programa.visible and not popup.visible, "LEFT cierra solo popup " + str(pantalla.x))
		_exigir((jugador.get("_control") as ControlDelJugador).esta_suspendido(), "LEFT conserva control suspendido " + str(pantalla.x))
		puesto.call("cerrar")
	jugador.suspender()
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for voz in almacen.find_children("*", tipo, true, false):
			voz.stop()
			voz.stream = null
	await create_timer(0.2).timeout
	almacen.queue_free()
	for _cuadro in 4:
		await physics_frame
	print("SONDA303_LEFT_MONTAJE_LIBERADO")

func _exigir(valida: bool, descripcion: String) -> void:
	print("SONDA303_LEFT_VALIDACION ", descripcion, " = ", valida)
	if not valida:
		push_error(descripcion)
		_fallo = true

func _registrar(evento: InputEvent) -> void:
	if evento is InputEventMouseButton or evento is InputEventMouseMotion:
		print("LEFT_EVENTO ", evento.as_text(), " posicion=", evento.position)
