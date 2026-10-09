extends SceneTree

func _initialize() -> void:
	_probar.call_deferred()

func _probar() -> void:
	var ruta := "res://no_existe.tscn"
	var drenar: bool = OS.get_cmdline_user_args().has("drenar")
	print("REQUEST=", ResourceLoader.load_threaded_request(ruta, "PackedScene"))
	var estado: int = ResourceLoader.load_threaded_get_status(ruta)
	for _cuadro in 600:
		if estado != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			break
		await process_frame
		estado = ResourceLoader.load_threaded_get_status(ruta)
	print("ESTADO_FINAL=", estado, " FAILED=", ResourceLoader.THREAD_LOAD_FAILED, " DRENAR=", drenar)
	if drenar:
		var retirada: Resource = ResourceLoader.load_threaded_get(ruta)
		print("RETIRADA_NULA=", retirada == null)
	print("ESTADO_DESPUES=", ResourceLoader.load_threaded_get_status(ruta))
	for _cuadro in 4:
		await process_frame
	quit()
