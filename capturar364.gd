extends SceneTree

var _almacen: Node3D


func _initialize() -> void:
	call_deferred("_jugar")


func _jugar() -> void:
	Guardado.ruta_por_defecto = "user://captura-364-%d.json" % Time.get_ticks_usec()
	_almacen = load("res://src/escenas/almacen.tscn").instantiate()
	root.add_child(_almacen)
	current_scene = _almacen
	for _cuadro in 40:
		await process_frame
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.avanzar(Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL)
	var pantalla: PantallaDeCierre = _almacen.get("_pantalla")
	if not pantalla.visible:
		quit(1)
		return
	var continuar: Button = pantalla.get("_continuar")
	continuar.pressed.emit()
	var persiana: PersianaDeLaNoche = _almacen.get_node("Interfaz/PersianaDeLaNoche")
	if not persiana.en_pantalla() or (_almacen.get("_partida") as Partida).jornada() != 2:
		quit(1)
		return
	await RenderingServer.frame_post_draw
	var imagen := root.get_texture().get_image()
	var ruta := "C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010/capturas364/noche-2.png"
	var error := imagen.save_png(ruta)
	print("CAPTURA NOCHE 2: ", ruta, " ", imagen.get_size(), " error=", error)
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in _almacen.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	_almacen.queue_free()
	await process_frame
	await process_frame
	quit(error)
