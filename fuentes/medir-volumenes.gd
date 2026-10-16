extends SceneTree


func _initialize() -> void:
	_medir.call_deferred()


func _medir() -> void:
	var suite: Script = load("res://test/escenas/volumen_de_los_solidos_test.gd")
	var local := (load("res://src/escenas/almacen.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(local)
	for _paso: int in 3:
		await physics_frame
	var corte: float = suite.call("_corte", local)
	var faltan: Array = suite.call("_sin_volumen", local, corte)
	var medidas: Array[Dictionary] = []
	for ruta: String in faltan:
		var malla := local.get_node(ruta) as MeshInstance3D
		var caras := malla.mesh.get_faces()
		for indice: int in caras.size():
			caras[indice] = malla.global_transform * caras[indice]
		var piezas: Array = suite.call("_piezas", caras)
		var datos: Array[Dictionary] = []
		for pieza: PackedVector3Array in piezas:
			if not suite.call("_cabe", pieza, corte):
				continue
			var limites := AABB(pieza[0], Vector3.ZERO)
			for vertice: Vector3 in pieza:
				limites = limites.expand(vertice)
			var hull := ConvexPolygonShape3D.new()
			hull.points = pieza
			hull.margin = 0.001
			var frontera := hull.get_debug_mesh().get_faces()
			var afuera := 0
			var muestras := 0
			var centro := limites.get_center()
			for indice: int in range(0, frontera.size(), 3):
				var punto := (frontera[indice] + frontera[indice + 1] + frontera[indice + 2]) / 3.0
				punto += punto.direction_to(centro) * 0.001
				muestras += 1
				if not suite.call("_punto_adentro", caras, punto):
					afuera += 1
			var puntos: Array[Array] = []
			for p: Vector3 in pieza:
				var q := malla.global_transform.affine_inverse() * p
				puntos.append([q.x, q.y, q.z])
			datos.append(
				{
					"aabb": str(limites),
					"caras": pieza.size() / 3,
					"hull_caras": frontera.size() / 3,
					"muestras": muestras,
					"afuera": afuera,
					"puntos_locales": puntos
				}
			)
		medidas.append(
			{
				"ruta": ruta,
				"mesh": malla.mesh.resource_path,
				"transform": str(malla.global_transform),
				"piezas": datos
			}
		)
	var salida := OS.get_cmdline_user_args()[0]
	var archivo := FileAccess.open(salida, FileAccess.WRITE)
	archivo.store_string(
		JSON.stringify({"corte": corte, "faltan": faltan, "medidas": medidas}, "\t")
	)
	archivo.close()
	for dato: Dictionary in medidas:
		for pieza: Dictionary in dato.piezas:
			print(
				"VOLUMEN22 ",
				dato.ruta,
				" ",
				pieza.aabb,
				" caras=",
				pieza.caras,
				" afuera=",
				pieza.afuera,
				"/",
				pieza.muestras
			)
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in local.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	local.queue_free()
	await process_frame
	_salir.call_deferred()


func _salir() -> void:
	quit()
