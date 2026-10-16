## La foto se toma del contenedor jugable; el rayo central certifica el tema antes de guardar.
## & $env:GODOT_BIN --path . --rendering-driver opengl3 --script \
##   assets/models/generar_foto_del_contenedor.gd -- <foto.png> <encuadre.json>
extends SceneTree

const TAMANO := Vector2i(960, 540)
const CUERPO := (
	"Estructura/deposito_contenedor_grande_soporte/"
	+ "deposito_contenedor_grande_cuerpo/StaticBody3D"
)


func _initialize() -> void:
	_generar.call_deferred()


func _fallar(mensaje: String) -> void:
	push_error("FOTO430: " + mensaje)
	quit(1)


func _generar() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.size() != 2:
		_fallar("se requieren PNG e informe de encuadre")
		return
	root.size = TAMANO
	root.content_scale_size = TAMANO
	var escena := load("res://src/escenas/almacen.tscn") as PackedScene
	if escena == null:
		_fallar("no cargó el almacén")
		return
	var local := escena.instantiate() as Node3D
	local.set("_partida", Partida.desde({"jornada": 2}))
	root.add_child(local)
	local.get_node("Interfaz/PersianaDeLaNoche").terminar()
	(local.get("_reloj") as Node).set_process(false)
	var jugador := local.get("_jugador") as CharacterBody3D
	jugador.call("suspender")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	for capa: CanvasLayer in local.find_children("*", "CanvasLayer", true, false):
		capa.hide()
	for cuerpo: RigidBody3D in local.find_children("*", "RigidBody3D", true, false):
		cuerpo.freeze = true
	var contenedor := local.get_node(CUERPO) as StaticBody3D
	var malla := contenedor.get_parent() as MeshInstance3D
	if malla == null:
		_fallar("el cuerpo no pertenece a la malla del contenedor")
		return
	var limites := malla.global_transform * malla.get_aabb()
	var centro := limites.get_center()
	var camara := Camera3D.new()
	camara.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	local.add_child(camara)
	camara.fov = 55.0
	camara.look_at_from_position(centro + Vector3(1.9, 1.1, 3.8), centro)
	camara.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	for _cuadro: int in 5:
		await physics_frame
	for _cuadro: int in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var punto := Vector2(TAMANO) / 2.0
	var desde := camara.project_ray_origin(punto)
	var hacia := desde + camara.project_ray_normal(punto) * 15.0
	var rayo := PhysicsRayQueryParameters3D.create(desde, hacia)
	rayo.exclude = [jugador.get_rid()]
	var golpe := camara.get_world_3d().direct_space_state.intersect_ray(rayo)
	if golpe.is_empty() or golpe.collider != contenedor:
		_fallar("el centro del encuadre no alcanza el contenedor: %s" % golpe)
		return
	var imagen := root.get_texture().get_image()
	if (
		imagen.is_empty()
		or imagen.get_size() != TAMANO
		or not _encuadrado(camara, malla.get_parent())
	):
		_fallar("imagen vacía, tamaño incorrecto o contenedor recortado")
		return
	var datos := {
		"tema": CUERPO,
		"golpe": str(local.get_path_to(golpe.collider)),
		"centro": str(centro),
		"camara": str(camara.global_transform),
		"tamano": str(TAMANO)
	}
	if not _guardar(imagen, argumentos, datos):
		return
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in local.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	local.queue_free()
	for _cuadro: int in 4:
		await process_frame
	print("FOTO430_FINAL contenedor verificado")
	quit(0)


func _guardar(imagen: Image, argumentos: PackedStringArray, datos: Dictionary) -> bool:
	if imagen.save_png(argumentos[0]) != OK:
		_fallar("no se pudo guardar PNG")
		return false
	var informe := FileAccess.open(argumentos[1], FileAccess.WRITE)
	if informe == null:
		_fallar("no se pudo guardar el informe")
		return false
	informe.store_string(JSON.stringify(datos, "\t"))
	informe.close()
	return true


func _encuadrado(camara: Camera3D, soporte: Node) -> bool:
	var margen := Rect2(Vector2(8, 8), Vector2(TAMANO) - Vector2(16, 16))
	for malla: MeshInstance3D in soporte.find_children("*", "MeshInstance3D", true, false):
		var limites := malla.get_aabb()
		for indice: int in 8:
			var esquina := malla.to_global(limites.get_endpoint(indice))
			if (
				camara.is_position_behind(esquina)
				or not margen.has_point(camara.unproject_position(esquina))
			):
				return false
	return true
