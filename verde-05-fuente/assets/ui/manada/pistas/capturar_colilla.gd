## Captura la colilla sobre el piso real. La salida siempre se indica fuera del checkout.
extends SceneTree

var _local: Node3D
var _fallos: Array[String] = []


func _init() -> void:
	call_deferred("_capturar")


func _exigir(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos.append(mensaje)
		printerr("FOTO22_FALLO ", mensaje)


func _cuadros(cantidad: int = 4) -> void:
	for _cuadro: int in cantidad:
		await process_frame


func _capturar() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or OS.get_environment("NOSEFIA_CAPTURA_AISLADA") != "22":
		printerr(
			"Indicar salida externa y ejecutar con APPDATA aislado y NOSEFIA_CAPTURA_AISLADA=22"
		)
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		printerr("La foto requiere un motor que dibuje")
		quit(1)
		return
	var salida := args[0]
	var proyecto := ProjectSettings.globalize_path("res://").simplify_path()
	if not salida.is_absolute_path() or salida.simplify_path().begins_with(proyecto):
		printerr("La salida debe ser absoluta y externa al checkout")
		quit(1)
		return
	root.size = Vector2i(768, 512)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var guardado: Script = load("res://src/sistemas/marco/guardado.gd")
	guardado.set("ruta_por_defecto", "user://foto_colilla_22.guardado")
	var clase: Script = load("res://src/dominio/empleo/partida.gd")
	var partida: RefCounted = clase.call("nueva")
	partida.call("abrir_la_jornada")
	var tareas: Array = partida.call("obligatorias")
	for tarea: RefCounted in tareas:
		tarea.call("completar")
	partida.call("cerrar_la_jornada", tareas.size())
	_local = (load("res://src/escenas/almacen.tscn") as PackedScene).instantiate()
	_local.set("_partida", partida)
	root.add_child(_local)
	_local.get_node("Interfaz/PersianaDeLaNoche").call("terminar")
	(_local.get("_reloj") as Node).set_process(false)
	for interfaz: Node in _local.get_node("Interfaz").get_children():
		if interfaz is CanvasLayer:
			interfaz.hide()
	var colilla := _local.get_node_or_null("Objetos/Colilla") as RigidBody3D
	_exigir(colilla != null, "Falta la colilla de producción")
	if colilla == null:
		await _terminar()
		return
	for _paso: int in 30:
		await physics_frame
	var espacio := colilla.get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(
		colilla.global_position + Vector3.UP * 0.2, colilla.global_position + Vector3.DOWN * 0.4
	)
	consulta.exclude = [colilla.get_rid()]
	var piso := espacio.intersect_ray(consulta)
	_exigir(not piso.is_empty(), "La colilla no tiene piso")
	if piso.is_empty():
		await _terminar()
		return
	_exigir(String(piso.collider.name) == "SueloSolido", "El apoyo no es el piso del local")
	var camara := Camera3D.new()
	_local.add_child(camara)
	camara.near = 0.01
	camara.fov = 40.0
	camara.global_position = colilla.global_position + Vector3(0.10, 0.12, 0.14)
	camara.look_at(colilla.global_position)
	camara.make_current()
	_exigir(camara.global_position.y > piso.position.y, "La cámara queda dentro del piso")
	var esfera := SphereShape3D.new()
	esfera.radius = camara.near
	var volumen := PhysicsShapeQueryParameters3D.new()
	volumen.shape = esfera
	volumen.transform.origin = camara.global_position
	volumen.exclude = [colilla.get_rid()]
	_exigir(espacio.intersect_shape(volumen).is_empty(), "La cámara queda dentro de un sólido")
	await _cuadros(8)
	await RenderingServer.frame_post_draw
	var imagen := root.get_texture().get_image()
	_exigir(imagen.get_size() == Vector2i(768, 512), "El encuadre no es el pedido")
	if _fallos.is_empty():
		DirAccess.make_dir_recursive_absolute(salida.get_base_dir())
		_exigir(imagen.save_png(salida) == OK, "No se puede guardar la foto")
		var registro := {
			"colilla": str(colilla.global_transform),
			"piso": str(piso.position),
			"camara": str(camara.global_transform),
			"encuadre": str(imagen.get_size()),
			"salida": salida,
		}
		var archivo := FileAccess.open(salida + ".procedencia.json", FileAccess.WRITE)
		archivo.store_string(JSON.stringify(registro, "\t"))
		archivo.close()
	await _terminar()


func _terminar() -> void:
	if is_instance_valid(_local):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _local.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_local.queue_free()
		await _cuadros()
	print("FOTO22_FINAL fallos=", _fallos.size())
	quit(0 if _fallos.is_empty() else 1)
