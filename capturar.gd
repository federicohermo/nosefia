extends SceneTree


func _initialize() -> void:
	_capturar.call_deferred()


func _capturar() -> void:
	var opciones := OS.get_cmdline_user_args()
	var etiqueta := opciones[0] if opciones.size() > 0 else "antes"
	var jornada := int(opciones[1]) if opciones.size() > 1 else 4
	var lateral := opciones.size() > 2
	var almacen := load("res://src/escenas/almacen.tscn").instantiate() as Node3D
	almacen.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	root.add_child(almacen)
	current_scene = almacen
	await create_timer(2.0).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var jugador := almacen.get_node("Jugador") as CharacterBody3D
	jugador.process_mode = Node.PROCESS_MODE_DISABLED
	jugador.global_position = Vector3(10.9, 0.102237, 4.55)
	if lateral:
		jugador.global_position = Vector3(10.48, 0.102237, 5.18)
	var camara := jugador.get_node("Giro/Camara") as Camera3D
	camara.look_at(Vector3(10.94, 1.7, 6.27))
	camara.current = true
	for control: CanvasLayer in almacen.find_children("*", "CanvasLayer", true, false):
		control.hide()
	for control: Control in almacen.find_children("*", "Control", true, false):
		if control.get_parent() is CanvasLayer:
			control.hide()
	almacen.process_mode = Node.PROCESS_MODE_DISABLED
	print("CAMARA ", camara.global_position, " ", camara.global_basis)
	var mancha := (
		almacen.get_node("LimpiezaDelAlmacen/ManchaEnLaParedDelOtroInodoro/Malla") as MeshInstance3D
	)
	print("MANCHA ", mancha.global_transform, " visible=", mancha.is_visible_in_tree())
	for nombre: String in ["nota baño inodoro", "nota baño inodoro 2", "almacen"]:
		var malla := almacen.get_node("Estructura/" + nombre) as MeshInstance3D
		print(
			"GEOMETRIA ",
			nombre,
			" ",
			malla.global_transform,
			" ",
			malla.global_transform * malla.get_aabb()
		)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var ruta := "res://tmp/mancha-cartel/" + etiqueta + ".png"
	var resultado := root.get_texture().get_image().save_png(ruta)
	print("CAPTURA ", ruta, " resultado=", resultado)
	quit()
