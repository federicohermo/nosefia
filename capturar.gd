extends SceneTree

const DISPOSICION := preload("res://src/escenas/puestos/disposicion_de_la_gondola.gd")


func _initialize() -> void:
	_capturar.call_deferred()


func _capturar() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var escena := Node3D.new()
	root.add_child(escena)
	root.size = Vector2i(1000, 1000)
	var modelo := (
		(load("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb") as PackedScene).instantiate()
		as Node3D
	)
	escena.add_child(modelo)
	var contenido := (
		(load("res://src/escenas/puestos/contenido_del_estante.tscn") as PackedScene).instantiate()
		as Node3D
	)
	var disposicion: Resource = load("res://src/escenas/puestos/disposicion_de_prueba.tres")
	for nodo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var malla := nodo as MeshInstance3D
		if malla.name.begins_with("gondolanueva"):
			continue
		malla.visible = false
	for indice: int in range(contenido.get_child_count()):
		var fuente := contenido.get_child(indice) as MeshInstance3D
		_agregar(escena, fuente, disposicion.principales[indice])
	for indice: int in range(disposicion.guias.size()):
		var fuente := (
			contenido.get_child(disposicion.productos_de_las_guias[indice]) as MeshInstance3D
		)
		_agregar(escena, fuente, disposicion.guias[indice])
	contenido.free()
	var ambiente := WorldEnvironment.new()
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.12, 0.14, 0.15)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color.WHITE
	entorno.ambient_light_energy = 0.8
	ambiente.environment = entorno
	escena.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45, -25, 0)
	luz.light_energy = 1.4
	escena.add_child(luz)
	var camara := Camera3D.new()
	escena.add_child(camara)
	camara.fov = 48
	camara.position = Vector3(1.8, 1.25, 0.15)
	camara.look_at(Vector3(0.11, 1.12, -1.13))
	if args.size() > 1 and args[1] == "detalle":
		camara.fov = 30
		camara.position = Vector3(1.8, 1.27, -0.65)
		camara.look_at(Vector3(0.11, 1.27, -1.0))
	camara.current = true
	for i: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var imagen := root.get_texture().get_image()
	imagen.save_png(args[0])
	print("CAPTURA ", args[0])
	quit()


func _agregar(escena: Node3D, fuente: MeshInstance3D, bloque: PackedFloat32Array) -> void:
	if bloque.is_empty():
		return
	var instancia := MultiMeshInstance3D.new()
	var malla := MultiMesh.new()
	malla.transform_format = MultiMesh.TRANSFORM_3D
	malla.mesh = fuente.mesh
	malla.instance_count = DISPOSICION.copias(bloque)
	for i: int in range(malla.instance_count):
		malla.set_instance_transform(
			i, DISPOSICION.copia(bloque, i) * Transform3D(fuente.basis, Vector3.ZERO)
		)
	instancia.multimesh = malla
	escena.add_child(instancia)
