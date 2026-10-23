extends SceneTree

func _initialize() -> void:
	call_deferred("medir")

func medir() -> void:
	root.size = Vector2i(1280, 960)
	var argumentos := OS.get_cmdline_user_args()
	var jornada := int(argumentos[0])
	var salida := argumentos[1]
	var local: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
	local.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	root.add_child(local)
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	for i in 10:
		await process_frame
	paused = true
	for nodo in root.find_children("*", "CanvasLayer", true, false):
		nodo.hide()
	var puesto: Node3D = local.get("_reposicion_manual")
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var camara := Camera3D.new()
	root.add_child(camara)
	camara.current = true
	camara.fov = 65
	var vistas: Array[Dictionary] = [
		{"nombre": "isla-costado", "mueble": "gondolanueva", "id": Producto.Id.ARVECOR},
		{"nombre": "isla-punta", "mueble": "gondolanueva", "id": Producto.Id.FERNET_GOD},
		{"nombre": "heladera", "mueble": "heladeranueva", "id": Producto.Id.PURA_COLA},
		{"nombre": "no-comestibles", "mueble": "gondolanueva_001", "id": Producto.Id.ACTRONCITO},
	]
	vistas.append_array([
		{"nombre": "A-este", "mueble": "gondolanueva", "id": Producto.Id.TERMINATOR if jornada < 4 else Producto.Id.ZUCARACHAS},
		{"nombre": "A-sur", "mueble": "gondolanueva", "id": Producto.Id.MALBARDO},
		{"nombre": "B-este", "mueble": "gondolanueva2", "id": Producto.Id.PEPITO if jornada < 4 else Producto.Id.PETISAS},
		{"nombre": "B-oeste", "mueble": "gondolanueva2", "id": Producto.Id.PROGRES},
		{"nombre": "B-norte", "mueble": "gondolanueva2", "id": Producto.Id.JORGILLO},
		{"nombre": "B-sur", "mueble": "gondolanueva2", "id": Producto.Id.POETICO if jornada < 4 else Producto.Id.FLIM_POF},
		{"nombre": "heladera-2", "mueble": "heladeranueva_001", "id": Producto.Id.MAYONCHIS},
	])
	var mediciones: Array[Dictionary] = []
	for producto in Catalogo.de_la_jornada(jornada):
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		var unidades: Array[Dictionary] = []
		for i in grupo.multimesh.instance_count:
			var t := grupo.global_transform * grupo.multimesh.get_instance_transform(i)
			var vertices := grupo.multimesh.mesh.get_faces()
			var aabb := AABB(t * vertices[0], Vector3.ZERO)
			for vertice in vertices:
				aabb = aabb.expand(t * vertice)
			unidades.append({"limites": [aabb.position.x, aabb.position.y, aabb.position.z, aabb.size.x, aabb.size.y, aabb.size.z], "base": var_to_str(t.basis)})
		mediciones.append({"producto": producto.nombre, "cupo": disposicion.casilleros_de(producto.id), "principal": disposicion.filas_de_adelante[producto.id], "unidades": unidades})
	DirAccess.make_dir_recursive_absolute(salida)
	FileAccess.open(salida.path_join("mediciones.json"), FileAccess.WRITE).store_string(JSON.stringify(mediciones, "\t"))
	if argumentos.size() > 2 and argumentos[2] == "solo-datos":
		quit()
		return
	for vista in vistas:
		var mueble: MeshInstance3D = local.get_node("Estructura/" + vista.mueble)
		var caja := mueble.global_transform * mueble.mesh.get_aabb()
		var id: Producto.Id = vista.id
		var frente := DisposicionDeLaGondola.frente(disposicion.principales[id], disposicion.filas_de_adelante[id])
		var centro := caja.get_center()
		centro += Vector3(frente.x * caja.size.x / 2, 0, frente.z * caja.size.z / 2)
		centro.y = 1.0
		var distancia: float = 1.6 if absf(frente.x) > 0.5 else 2.0
		camara.fov = 85 if absf(frente.x) > 0.5 else 65
		camara.global_position = centro + frente * distancia + Vector3.UP * 0.45
		camara.look_at(centro)
		print(vista.nombre, " centro ", centro, " frente ", frente, " limites ", caja)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(salida.path_join(vista.nombre + ".png"))
		if vista.nombre in ["isla-costado", "A-sur", "B-oeste"]:
			camara.fov = 55
			centro.y = 1.0
			camara.global_position = centro + frente * 0.9 + Vector3.UP * 0.15
			camara.look_at(centro)
			for i in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(salida.path_join(vista.nombre + "-detalle.png"))
	quit()

