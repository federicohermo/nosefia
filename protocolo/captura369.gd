extends SceneTree

const SALIDA := "C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010/capturas369"


func _initialize() -> void:
	_capturar.call_deferred()


func _capturar() -> void:
	root.size = Vector2i(1600, 900)
	var escena: PackedScene = load("res://src/escenas/almacen.tscn")
	var local: Node3D = escena.instantiate()
	local.set("_partida", Partida.nueva())
	root.add_child(local)
	local.get_node("Interfaz/PersianaDeLaNoche").terminar()
	local.get("_reloj").set_process(false)
	var jugador: Node3D = local.get("_jugador")
	jugador.set_physics_process(false)
	for _cuadro in 8:
		await physics_frame
	var cajas: Array = local.get("_cajas_de_productos")
	assert(cajas.size() == 31)
	var centro := Vector3.ZERO
	for caja: Node3D in cajas:
		centro += caja.global_position
	centro /= float(cajas.size())
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	for puerta: Node3D in local.get("_puertas"):
		print("PUERTA369 ", puerta.get_parent().name, " ", puerta.get_parent().global_position)
	# Es la entrada que usa el recorrido físico heredado de las bolsas, dentro del depósito.
	jugador.global_position = Vector3(5.5, 0.102737, -8.7)
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	camara.look_at(centro)
	camara.fov = 70.0
	jugador.reset_physics_interpolation()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	for _cuadro in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var imagen := root.get_texture().get_image()
	assert(not imagen.is_empty())
	assert(imagen.save_png(SALIDA + "/pila-desde-la-puerta.png") == OK)
	# Vista complementaria dentro del depósito, sin mover cajas ni ocultar geometría.
	jugador.global_position = Vector3(-1.4, 0.102737, -14.2)
	camara.look_at(centro)
	jugador.reset_physics_interpolation()
	for _cuadro in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(SALIDA + "/pila-frente-al-porton.png") == OK)
	print(
		"CAPTURA369 guardada ",
		SALIDA,
		" con ",
		cajas.size(),
		" cajas; cámara ",
		camara.global_position
	)
	local.queue_free()
	for _cuadro in 4:
		await process_frame
	quit.call_deferred()
