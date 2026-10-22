extends SceneTree

const AVANCE := preload("res://test/avance_de_devolucion.gd")

var _etapa := "antes"
var _almacen: Node3D
var _capturados: Dictionary[String, bool] = {}
var _vio_carga := false


func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		_etapa = OS.get_cmdline_user_args()[0]
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	Guardado.ruta_por_defecto = "res://build/carga-entre-noches/partida-%s.guardado" % _etapa
	_almacen = load("res://src/escenas/almacen.tscn").instantiate()
	_almacen.set("_partida", Partida.desde({"jornada": 2} if _etapa == "sin-pendientes" else {}))
	root.add_child(_almacen)
	current_scene = _almacen
	for _cuadro: int in 30:
		await process_frame
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.terminar()
	await create_timer(2.0).timeout
	await _capturar("devolucion")
	var pantalla: PantallaDeDevolucion = _almacen.get("_pantalla")
	AVANCE.entregar(pantalla)
	pantalla.elegir()
	AVANCE.pasar_la_reflexion(pantalla)
	var inicio := Time.get_ticks_msec()
	var encontro := false
	while Time.get_ticks_msec() - inicio < 60000:
		await process_frame
		var pantallas := _almacen.find_children("*", "PantallaDeCarga", true, false)
		for carga: PantallaDeCarga in pantallas:
			_vio_carga = _vio_carga or carga.visible
		var calentadores := _almacen.find_children("*", "CalentamientoDeShaders", true, false)
		if not calentadores.is_empty():
			encontro = true
			var calentador: CalentamientoDeShaders = calentadores[0]
			var progreso := calentador.progreso()
			if _etapa == "despues":
				if pantallas.size() != 1 or not pantallas[0].visible:
					push_error("Calentamiento sin pantalla visible")
					quit(1)
					return
				var barra: ProgressBar = pantallas[0].get("_barra")
				if not is_equal_approx(barra.value, progreso):
					push_error("La barra no sigue progreso()")
					quit(1)
					return
			if not _capturados.has("compilando"):
				print("EVIDENCIA %s J1->J2 compilando progreso=%f" % [_etapa, progreso])
				await _capturar("compilando")
			if progreso >= 0.4 and not _capturados.has("progreso"):
				print("EVIDENCIA %s J1->J2 progreso=%f" % [_etapa, progreso])
				await _capturar("progreso")
		var instrucciones: PantallaDeInstrucciones = _almacen.get("_instrucciones")
		if instrucciones.visible and (encontro or _etapa == "sin-pendientes"):
			await create_timer(0.5).timeout
			await _capturar("instrucciones")
			print("EVIDENCIA %s J1->J2 instrucciones visibles, calentadores=%d" % [_etapa, calentadores.size()])
			if _etapa == "sin-pendientes" and (_vio_carga or encontro):
				push_error("Aparecio carga sin pendientes")
				quit(1)
				return
			if not _almacen.find_children("*", "PantallaDeCarga", true, false).is_empty():
				push_error("Quedo una pantalla despues del calentamiento")
				quit(1)
				return
			print("EVIDENCIA %s carga_vista=%s, limpieza completa" % [_etapa, _vio_carga])
			quit(0)
			return
	push_error("No se completo la transicion")
	quit(1)


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var ruta := "res://build/carga-entre-noches/%s-%s.png" % [_etapa, nombre]
	var resultado := root.get_texture().get_image().save_png(ruta)
	print("CAPTURA %s resultado=%d" % [ruta, resultado])
	_capturados[nombre] = true
