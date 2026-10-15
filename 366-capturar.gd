extends SceneTree

var _viewport: SubViewport
var _almacen: Node3D
var _cuerpos: Array[ObjetoAgarrable] = []
var _identidades: Array[UnidadDeProducto] = []
var _suelo: StaticBody3D
var _jugador: CharacterBody3D
var _camara: Camera3D


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	_correr.call_deferred()


func _fallar(motivo: String) -> void:
	push_error("CAPTURA INVALIDA: " + motivo)
	quit(1)


func _pulsar() -> void:
	var panel: PanelDeLaVentanilla = _almacen.get_node("Estructura/Ventanilla").get("panel")
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	panel.get_node("Fisico/Blanco").gui_input.emit(evento)


func _correr() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1600, 900)
	_viewport.world_3d = World3D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var escena: PackedScene = load("res://src/escenas/almacen.tscn")
	_almacen = escena.instantiate()
	_almacen.set("_partida", Partida.nueva())
	# La sonda dibuja fuera de pantalla sin tomar el cursor de la sesión del usuario.
	var jugador_preparado := _almacen.get_node("Jugador")
	jugador_preparado.set("_escribir_cursor", func(_modo: int) -> void: pass)
	jugador_preparado.set("_leer_cursor", func() -> int: return Input.MOUSE_MODE_CAPTURED)
	_viewport.add_child(_almacen)
	_jugador = _almacen.get("_jugador")
	_camara = _jugador.get_node("Giro/Camara")
	_jugador.set_process(false)
	_jugador.set_physics_process(false)
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.set_process(false)
	_almacen.get_node("Servicios/AudioDelAlmacen/Reproductor").silenciar()
	_almacen.get_node("Interfaz/PantallaDeInstrucciones").hide()
	_suelo = _almacen.get("_reposicion_manual").get("suelo")
	for _cuadro in 4:
		await physics_frame
	var ventana: Node3D = _almacen.get_node("Estructura/Ventanilla")
	var forma_jugador: CollisionShape3D = _jugador.get_node("Cuerpo")
	var capsula := forma_jugador.shape as CapsuleShape3D
	var antepecho: MeshInstance3D = ventana.get("antepecho")
	var lugar := (
		ventana.global_position
		- ventana.global_basis.z * (capsula.radius + antepecho.get_aabb().size.z / 2.0 + 0.1)
	)
	var rayo := PhysicsRayQueryParameters3D.create(
		lugar + Vector3.UP, lugar + Vector3.DOWN * 2.0, _jugador.collision_mask
	)
	rayo.exclude = [_jugador.get_rid()]
	var piso := _jugador.get_world_3d().direct_space_state.intersect_ray(rayo)
	if piso.get("collider") != _suelo:
		_fallar("La pose inicial no encuentra el piso real.")
		return
	lugar.y = (piso["position"] as Vector3).y + 0.01
	_jugador.global_position = lugar
	for _cuadro in 3:
		await physics_frame
	reloj.avanzar(120.0)
	ventana.call("abrir")
	var atenciones: Ventanilla = _almacen.get("_atenciones")
	_pulsar()
	while not atenciones.puede_abandonar():
		_pulsar()
	var agarre: Agarre = _almacen.get("_agarre")
	for producto in atenciones.atencion().comprador().pedido().productos():
		_almacen.get("_reposicion_manual").call("retirar", producto.id)
		var cuerpo := agarre.cuerpo_sostenido() as ObjetoAgarrable
		if cuerpo == null or not cuerpo.datos is UnidadDeProducto:
			_fallar("La entrega no produjo su cuerpo físico.")
			return
		_cuerpos.append(cuerpo)
		_identidades.append(cuerpo.datos as UnidadDeProducto)
		_pulsar()
		if agarre.cuerpo_sostenido() != null:
			_fallar("El comprador no recibió el cuerpo.")
			return
	reloj.avanzar(120.0)
	for _cuadro in 90:
		await physics_frame
	ventana.call("cerrar")
	var sueltas: Array[Node3D] = _almacen.get("_reposicion_manual").call("unidades_sueltas")
	if sueltas.size() != 3:
		_fallar("No quedaron exactamente las tres unidades recibidas.")
		return
	var lector: Node3D = _almacen.get("_habitaciones")
	for indice in _cuerpos.size():
		var cuerpo := _cuerpos[indice]
		if not is_instance_valid(cuerpo) or not sueltas.has(cuerpo):
			_fallar("Se perdió un cuerpo recibido.")
			return
		if (
			cuerpo.datos != _identidades[indice]
			or lector.call("de", cuerpo.global_position) != 0
			or not cuerpo.visible
			or cuerpo.freeze
		):
			_fallar("La unidad perdió identidad, interior o física.")
			return
		var forma: CollisionShape3D = cuerpo.get_node("Forma")
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.collision_mask = cuerpo.collision_mask
		consulta.exclude = [cuerpo.get_rid(), _suelo.get_rid()]
		consulta.margin = 0.0
		if not _jugador.get_world_3d().direct_space_state.intersect_shape(consulta).is_empty():
			_fallar("Una unidad se superpone con otro cuerpo o sólido.")
			return
	if not await _encuadrar_y_enfocar(_cuerpos[0]):
		_fallar("No existe la pose accesible con foco real preparada.")
		return
	for _cuadro in 8:
		await process_frame
	_jugador.call("_leer_la_mira")
	if _jugador.get("_enfocado") != _cuerpos[0]:
		_fallar("El foco cambió antes de guardar.")
		return
	await RenderingServer.frame_post_draw
	var imagen := _viewport.get_texture().get_image()
	if imagen.is_empty() or imagen.get_size() != Vector2i(1600, 900):
		_fallar("El viewport no produjo imagen.")
		return
	var colores: Dictionary[Color, bool] = {}
	for x in range(0, 1600, 40):
		for y in range(0, 900, 40):
			colores[imagen.get_pixel(x, y)] = true
	if colores.size() < 32:
		_fallar("La imagen no contiene el dibujo del juego.")
		return
	var carpeta := "C:/Users/fede_/AppData/Local/Temp/nosefia-batch-365-366/366-capturas"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var resultado := imagen.save_png(carpeta + "/tres-unidades-adentro.png")
	if resultado != OK:
		_fallar("No se pudo guardar el PNG.")
		return
	var datos := {
		"camara": str(_camara.global_transform),
		"jugador": str(_jugador.global_position),
		"foco": str(_jugador.get("_enfocado").get_path()),
		"piso": str(_suelo.get_path()),
		"unidades": []
	}
	for cuerpo in _cuerpos:
		(datos["unidades"] as Array).append(
			{
				"producto": (cuerpo.datos as UnidadDeProducto).producto.nombre,
				"posicion": str(cuerpo.global_position),
				"identidad": cuerpo.datos.get_instance_id()
			}
		)
	var archivo := FileAccess.open(carpeta + "/pose-y-foco.json", FileAccess.WRITE)
	archivo.store_string(JSON.stringify(datos, "\t"))
	archivo.close()
	print(
		"CAPTURA_366_VALIDA: tres identidades físicas interiores, pose accesible y foco real al guardar."
	)
	_almacen.queue_free()
	for _cuadro in 6:
		await process_frame
	quit()


func _encuadrar_y_enfocar(cuerpo: ObjetoAgarrable) -> bool:
	var espacio := _jugador.get_world_3d().direct_space_state
	var forma: CollisionShape3D = _jugador.get_node("Cuerpo")
	var excluidos: Array[RID] = [_jugador.get_rid()]
	for unidad in _cuerpos:
		excluidos.append(unidad.get_rid())
	for direccion: Vector3 in [Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT, Vector3.BACK]:
		var lugar := cuerpo.global_position + direccion
		var rayo := PhysicsRayQueryParameters3D.create(
			lugar + Vector3.UP, lugar + Vector3.DOWN * 2.0, _jugador.collision_mask
		)
		rayo.exclude = excluidos
		var piso := espacio.intersect_ray(rayo)
		if piso.get("collider") != _suelo:
			continue
		lugar.y = (piso["position"] as Vector3).y + 0.01
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = Transform3D(Basis.IDENTITY, lugar) * forma.transform
		consulta.collision_mask = _jugador.collision_mask
		consulta.exclude = [_jugador.get_rid()]
		consulta.margin = 0.0
		if not espacio.intersect_shape(consulta).is_empty():
			continue
		_jugador.global_position = lugar
		_camara.look_at(cuerpo.global_position)
		_jugador.reset_physics_interpolation()
		_camara.reset_physics_interpolation()
		for _cuadro in 3:
			await physics_frame
		_jugador.call("_leer_la_mira")
		if _jugador.get("_enfocado") == cuerpo:
			return true
	return false
