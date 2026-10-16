extends SceneTree

var _local: Node3D


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	await _ejercitar()
	for _cuadro in 4:
		await process_frame
	print("PAQUETE427_FINAL")
	quit(0)


func _ejercitar() -> void:
	var partida: Script = load("res://src/dominio/empleo/partida.gd")
	var escena: PackedScene = load("res://src/escenas/almacen.tscn")
	if partida == null or escena == null:
		push_error("PAQUETE427 no contiene partida y almacén")
		quit(1)
		return
	_local = escena.instantiate()
	_local.set("_partida", partida.call("desde", {"jornada": 2, "medios": 0}))
	root.add_child(_local)
	_local.get_node("Interfaz/PersianaDeLaNoche").call("terminar")
	(_local.get("_reloj") as Node).set_process(false)
	var jugador: Node3D = _local.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var puesto: Node = _local.get("_reposicion_manual")
	var efecto: Node3D = puesto.get("_desenfoque")
	if not efecto.has_method("_pose_dibujada"):
		push_error("PAQUETE427 no contiene la corrección de pose")
		quit(1)
		return
	for _cuadro in 5:
		await physics_frame
		await process_frame
		efecto.call("_process", 0.0)
		var mascara: Camera3D = efecto.get("_camara")
		var pose: Transform3D = efecto.call("_pose_dibujada", camara)
		if not mascara.global_transform.is_equal_approx(pose):
			push_error("PAQUETE427 la máscara no sigue la pose")
			quit(1)
			return
	var modelos: Array = puesto.get("_modelos")
	for modelo: Mesh in modelos:
		if modelo == null or modelo.get_surface_count() == 0:
			push_error("PAQUETE427 contiene un modelo de producto vacío")
			quit(1)
			return
	print("PAQUETE427_MODELOS ", modelos.size())
	for audio: Node in _local.find_children("*", "Node", true, false):
		if audio is AudioStreamPlayer or audio is AudioStreamPlayer3D:
			audio.call("stop")
			audio.set("stream", null)
	camara = null
	jugador = null
	puesto = null
	efecto = null
	_local.queue_free()
	_local = null
