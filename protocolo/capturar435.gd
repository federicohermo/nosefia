extends SceneTree

var _local: Node3D
var _pila: PilaDeNotificaciones
var _salida: String
var _medidas: Array[Dictionary] = []


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	_salida = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_salida)
	Engine.max_fps = 60
	Guardado.ruta_por_defecto = "user://capturas435.guardado"
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = tamano
		root.content_scale_size = tamano
		_local = load("res://src/escenas/almacen.tscn").instantiate()
		_local.set("_partida", Partida.desde({"jornada": 2, "medios": 0}))
		root.add_child(_local)
		_local.get_node("Interfaz/PersianaDeLaNoche").terminar()
		var reloj: RelojDelTurno = _local.get("_reloj")
		reloj.set_process(false)
		_pila = _local.get_node("Interfaz/PilaDeNotificaciones")
		_pila.set_process(false)
		var computadora: PantallaDeComputadora = _local.get_node("Interfaz/PantallaDeComputadora")
		var celular: CelularDelEmpleado = _local.get_node("Interfaz/CelularDelEmpleado")
		var ventanilla: Node3D = _local.get_node("Estructura/Ventanilla")
		var pausa: ControlDePausa = _local.get_node("Interfaz/ControlDePausa")
		var prefijo := "%dx%d" % [tamano.x, tamano.y]
		reloj.avanzar(
			(Reglas.DURACION_DEL_TURNO - 3600.0) / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL
		)
		await _capturar(prefijo + "-local")
		computadora.mostrar(Computadora.App.CAJA)
		await _capturar(prefijo + "-computadora")
		computadora.ocultar()
		celular.pedir_alternar(false)
		await _capturar(prefijo + "-celular")
		celular.pedir_alternar(false)
		ventanilla.abrir()
		await _capturar(prefijo + "-ventanilla")
		ventanilla.cerrar()
		_pila._process(1.0)
		pausa.pausar()
		await _capturar(prefijo + "-pausa")
		pausa.reanudar()
		await _capturar(prefijo + "-reanudar")
		_pila._process(2.0)
		await _capturar(prefijo + "-vencido")
		for audio: Node in _local.find_children("*", "Node", true, false):
			if audio is AudioStreamPlayer or audio is AudioStreamPlayer3D:
				audio.call("stop")
				audio.set("stream", null)
		_local.queue_free()
		await process_frame
	var archivo := FileAccess.open(_salida.path_join("medidas.json"), FileAccess.WRITE)
	archivo.store_string(JSON.stringify(_medidas, "\t"))
	archivo.close()
	print("CAPTURAS435_FINAL ", _medidas.size())
	quit(0)


func _capturar(nombre: String) -> void:
	for _cuadro in 40:
		await process_frame
		await RenderingServer.frame_post_draw
	var textos: Array[String] = []
	var medidas: Array[Dictionary] = []
	for texto: Label in _pila.find_children("*", "Label", true, false):
		textos.append(texto.text)
		medidas.append({"texto": texto.text, "rect": str(texto.get_global_rect())})
	(
		_medidas
		. append(
			{
				"captura": nombre,
				"textos": textos,
				"carteles": medidas,
				"pausa": paused,
				"layer_aviso": _pila.layer,
				"layer_pausa": (_local.get_node("Interfaz/MenuDePausa") as CanvasLayer).layer,
				"cursor": Input.mouse_mode,
			}
		)
	)
	root.get_texture().get_image().save_png(_salida.path_join(nombre + ".png"))
