extends SceneTree


func _initialize() -> void:
	call_deferred("_medir")


func _medir() -> void:
	var almacen := load("res://src/escenas/almacen.tscn").instantiate() as Node3D
	root.add_child(almacen)
	almacen.get("_reloj").set_process(false)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	for cuadro in 8:
		await physics_frame
	var gondola: MeshInstance3D = almacen.get_node("Estructura/gondolanueva2")
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var d: DisposicionDeLaGondola = puesto.get("disposicion")
	var bloque := d.principales[Producto.Id.SALADIK]
	var frente := Vector3.FORWARD
	var caja := gondola.global_transform * gondola.get_aabb()
	var vieja: Vector3 = gondola.get_node("saladix-2oeste2").global_position
	var nueva := (puesto.global_transform * DisposicionDeLaGondola.copia(bloque, 0)).origin
	var candidatos: Array[Vector3] = [vieja, nueva]
	for indice in 2:
		candidatos[indice].y = caja.end.y - 0.03
	var caras := gondola.mesh.get_faces()
	for i in range(0, caras.size(), 3):
		var a := gondola.to_global(caras[i])
		var b := gondola.to_global(caras[i + 1])
		var c := gondola.to_global(caras[i + 2])
		var normal := (b - a).cross(c - a).normalized()
		var centro := (a + b + c) / 3.0
		if absf(normal.y) > 0.9 and centro.y > caja.end.y - 0.15:
			if (centro - caja.get_center()).dot(frente) > caja.size.z * 0.35:
				candidatos.append(centro)
	var medidas: Array[Dictionary] = []
	var fisica := almacen.get_world_3d().direct_space_state
	for objetivo in candidatos:
		var pie := objetivo + frente * 1.2
		var suelo := fisica.intersect_ray(
			PhysicsRayQueryParameters3D.create(
				Vector3(pie.x, 0.8, pie.z), Vector3(pie.x, -1, pie.z), 1
			)
		)
		if suelo.is_empty():
			continue
		var ojo: Vector3 = (
			suelo.position + Vector3.UP * (ReglasDelJugador.ALTURA_DE_LA_CAMARA + 0.005)
		)
		var rayo := fisica.intersect_ray(
			PhysicsRayQueryParameters3D.create(
				ojo, ojo + ojo.direction_to(objetivo) * ReglasDelJugador.ALCANCE_DE_LA_MIRA, 1
			)
		)
		medidas.append(
			{
				"objetivo": str(objetivo),
				"ojo": str(ojo),
				"suelo": str(suelo.collider.get_path()),
				"golpe": str(rayo.get("position")),
				"cuerpo": str(rayo.get("collider"))
			}
		)
	print(
		(
			"434_BORDE_DATOS:"
			+ JSON.stringify(
				{
					"vieja": str(vieja),
					"nueva": str(nueva),
					"frente": str(frente),
					"aabb": str(caja),
					"candidatos": medidas
				}
			)
		)
	)
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in almacen.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	d = null
	almacen.queue_free()
	for cuadro in 4:
		await physics_frame
	print("434_BORDE_OBSERVER03_OK")
	await process_frame
	quit(0)
