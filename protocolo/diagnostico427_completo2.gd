extends SceneTree

var _local: Node3D
var _jugador: CharacterBody3D
var _vista: Camera3D
var _efecto: DesenfoqueDeReferencias
var _salida: String
var _muestras: Array[Dictionary] = []


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	_salida = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_salida)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	Engine.max_fps = 90
	Guardado.ruta_por_defecto = "user://diagnostico427.guardado"
	_local = load("res://src/escenas/almacen.tscn").instantiate()
	_local.set("_partida", Partida.desde({"jornada": 2, "medios": 0}))
	root.add_child(_local)
	_local.get_node("Interfaz/PersianaDeLaNoche").terminar()
	(_local.get("_reloj") as Node).set_process(false)
	for capa: CanvasLayer in _local.find_children("*", "CanvasLayer", true, false):
		capa.hide()
	(_local.get("_hud") as CanvasLayer).show()
	_jugador = _local.get("_jugador")
	_vista = _jugador.get_node("Giro/Camara")
	var puesto: Node3D = _local.get("_reposicion_manual")
	_efecto = puesto.get("_desenfoque")
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var mejor_y := -INF
	var objetivo := Vector3.ZERO
	var frente := Vector3.ZERO
	var elegido := -1
	for indice in disposicion.guias.size():
		if disposicion.productos_de_las_guias[indice] != Producto.Id.ACTRONCITO:
			continue
		var bloque := disposicion.guias[indice]
		var copia := DisposicionDeLaGondola.copia(bloque, 0)
		var malla: Mesh = (puesto.get("_modelos") as Array)[Producto.Id.ACTRONCITO]
		var centro := copia * malla.get_aabb().get_center()
		if centro.y > mejor_y:
			mejor_y = centro.y
			objetivo = centro
			frente = DisposicionDeLaGondola.frente(
				bloque, disposicion.filas_de_adelante_de_las_guias[indice]
			)
			elegido = indice
	if elegido < 0 or frente.length() < 0.9:
		push_error("PROBE427 sin referencia o frente")
		quit(1)
		return
	var ojo := objetivo + frente * 1.4
	ojo.y = ReglasDelJugador.ALTURA_DE_LA_CAMARA + 0.1
	var pie := ojo - Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	var hacia := Vector3(objetivo.x, ojo.y, objetivo.z)
	_jugador.ubicar(Transform3D(Basis.looking_at(hacia - ojo, Vector3.UP), pie))
	_jugador.reanudar()
	var control: ControlDelJugador = _jugador.get("_control")
	var mirada: Mirada = control.get("_mirada")
	var pitch := atan2(objetivo.y - ojo.y, 1.4)
	control.girar(Vector2(0, -pitch / float(mirada.get("_sensibilidad"))))
	for _i in 20:
		await physics_frame
		await RenderingServer.frame_post_draw
	var protocolo := {
		"producto": "ACTRONCITO",
		"guia": elegido,
		"objetivo": str(objetivo),
		"ojo_inicial": str(ojo),
		"frente": str(frente),
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"pasos": ["quieto", "atras", "quieto", "adelante", "costado", "giro"]
	}
	print("PROBE427_PROTOCOLO ", JSON.stringify(protocolo))
	for con_mano: bool in [false, true]:
		_jugador.ubicar(Transform3D(Basis.looking_at(hacia - ojo, Vector3.UP), pie))
		_jugador.reanudar()
		control.girar(Vector2(0, -pitch / float(mirada.get("_sensibilidad"))))
		if con_mano:
			puesto.call("retirar", Producto.Id.MAROLINI)
			var agarre: Agarre = _local.get("_agarre")
			if agarre.cuerpo_sostenido() == null:
				push_error("PROBE427 no pudo retirar la unidad de prueba")
				quit(1)
				return
		for _cuadro in 20:
			await process_frame
			await RenderingServer.frame_post_draw
		_jugador.call("_aplicar_la_rotacion")
		await RenderingServer.frame_post_draw
		for tramo: String in ["quieto", "atras", "quieto_2", "adelante", "costado", "giro"]:
			var accion: StringName = &""
			if tramo == "atras":
				accion = ReglasDelJugador.ACCION_ATRAS
			if tramo == "adelante":
				accion = ReglasDelJugador.ACCION_ADELANTE
			if tramo == "costado":
				accion = ReglasDelJugador.ACCION_DERECHA
			if not accion.is_empty():
				Input.action_press(accion)
			for cuadro in 24:
				if tramo == "giro":
					(_jugador.get("_control") as ControlDelJugador).girar(Vector2(0.5, 0))
				await process_frame
				await RenderingServer.frame_post_draw
				var dibujada := _vista.get_global_transform_interpolated()
				var mascara: Camera3D = _efecto.get("_camara")
				_muestras.append(
					{
						"tramo": tramo,
						"con_mano": con_mano,
						"mirada": str(-_vista.global_basis.z),
						"error_giro":
						(
							mascara.global_basis.x.distance_to(dibujada.basis.x)
							+ mascara.global_basis.y.distance_to(dibujada.basis.y)
						),
						"cuadro": cuadro,
						"fisica": str(_vista.global_position),
						"dibujada": str(dibujada.origin),
						"mascara": str(mascara.global_position),
						"error": mascara.global_position.distance_to(dibujada.origin),
						"fraccion": Engine.get_physics_interpolation_fraction(),
						"en_cuadro":
						(
							not _vista.is_position_behind(objetivo)
							and root.get_visible_rect().has_point(
								_vista.unproject_position(objetivo)
							)
						)
					}
				)
				if cuadro in [5, 12, 20]:
					root.get_texture().get_image().save_png(
						_salida.path_join(
							"%s-%s-%02d.png" % ["mano" if con_mano else "vacia", tramo, cuadro]
						)
					)
			if not accion.is_empty():
				Input.action_release(accion)
	var pausa: ControlDePausa = _local.get_node("Interfaz/ControlDePausa")
	pausa.pausar()
	for _cuadro in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_salida.path_join("pausa.png"))
	pausa.reanudar()
	for _cuadro in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_salida.path_join("reanudar.png"))
	var archivo := FileAccess.open(_salida.path_join("muestras.json"), FileAccess.WRITE)
	archivo.store_string(JSON.stringify({"protocolo": protocolo, "muestras": _muestras}, "\t"))
	archivo.close()
	for audio: Node in _local.find_children("*", "Node", true, false):
		if not (audio is AudioStreamPlayer or audio is AudioStreamPlayer3D):
			continue
		audio.call("stop")
		audio.set("stream", null)
	_vista = null
	_jugador = null
	_efecto = null
	_local.queue_free()
	_local = null
	for _i in 4:
		await process_frame
	print("PROBE427_FINAL")
	quit(0)
