extends SceneTree


func _initialize() -> void:
	call_deferred("_probar")


func _probar() -> void:
	var escena := load("res://src/escenas/almacen.tscn") as PackedScene
	if escena == null:
		quit(1)
		return
	var almacen := escena.instantiate() as Node3D
	var partida: GDScript = load("res://src/dominio/empleo/partida.gd")
	almacen.set("_partida", partida.call("desde", {"jornada": 2, "medios": 0}))
	root.add_child(almacen)
	almacen.get("_reloj").set_process(false)
	almacen.get("_jugador").set_physics_process(false)
	for cuadro in 8:
		await physics_frame
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var cupos: Dictionary = puesto.call("casilleros")
	var disposicion: Resource = puesto.get("disposicion")
	for frente: int in disposicion.get("filas_de_adelante"):
		assert(frente > 0)
	var producto: GDScript = load("res://src/dominio/almacen/producto.gd")
	var ids: Dictionary = producto.get_script_constant_map()["Id"]
	if cupos.size() != ids.size() or cupos[ids["DURONGA"]] <= 0:
		push_error("434 paquete con cupos incorrectos")
		quit(1)
		return
	var catalogo: GDScript = load("res://src/dominio/almacen/catalogo.gd")
	var contenido: Node3D = puesto.get("contenido")
	for datos: RefCounted in catalogo.call("todos"):
		var nodo := contenido.get_child(datos.get("id")) as MeshInstance3D
		if nodo.mesh == null or nodo.mesh.get_surface_count() == 0:
			push_error("434 paquete sin malla fuente")
			quit(1)
			return
		for superficie in nodo.mesh.get_surface_count():
			if nodo.mesh.surface_get_material(superficie) == null:
				push_error("434 paquete sin material de producto")
				quit(1)
				return
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in almacen.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	almacen.queue_free()
	for cuadro in 4:
		await physics_frame
	print("434_PAQUETE_JORNADA_2_OK")
	quit(0)
