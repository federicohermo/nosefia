extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pantalla: PantallaDeCarga = load("res://src/ui/interrupciones/pantalla_de_carga.tscn").instantiate()
	root.add_child(pantalla)
	pantalla.mostrar()
	pantalla.pintar(0.4)
	pantalla.contar_preparacion(4, 10)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if pantalla.presentacion != PantallaDeCarga.Presentacion.INICIAL:
		quit(1)
		return
	for nodo: Control in [pantalla.get("_fondo"), pantalla.get("_detalle")]:
		if not nodo.visible:
			quit(1)
			return
	for adorno: Control in pantalla.get("_adornos"):
		if not adorno.visible:
			quit(1)
			return
	var resultado := root.get_texture().get_image().save_png("res://build/carga-entre-noches/carga-inicial.png")
	print("EVIDENCIA carga inicial conserva fondo, adornos y detalle. captura=%d" % resultado)
	quit(resultado)
