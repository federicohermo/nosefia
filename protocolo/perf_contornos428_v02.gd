## Compara consultas reales de la cápsula contra el contorno, con renderer y mundo presentes.
extends SceneTree

var almacen: Node3D
var mediciones: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_medir")


func _medir() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.show()
	Engine.max_fps = 60
	almacen = load("res://src/escenas/almacen.tscn").instantiate()
	almacen.set("_partida", Partida.desde({"jornada": 1, "medios": 0}))
	root.add_child(almacen)
	almacen.get_node("Interfaz/PersianaDeLaNoche").terminar()
	almacen.get("_reloj").set_process(false)
	for cuadro in 8:
		await physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.call("reanudar")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	var casos := [
		["gondolanueva", Vector3.RIGHT],
		["gondolanueva2", Vector3.RIGHT],
		["gondolanueva2", Vector3.BACK],
	]
	for caso: Array in casos:
		await _caminar(caso[0], caso[1], jugador)
	for cuadro in 8:
		await process_frame
	var salida := OS.get_cmdline_user_args()[0]
	var archivo := FileAccess.open(salida, FileAccess.WRITE)
	archivo.store_string(JSON.stringify({"measurements": mediciones}, "\t"))
	archivo.close()
	for audio: Node in almacen.find_children("*", "Node", true, false):
		if audio is AudioStreamPlayer or audio is AudioStreamPlayer3D:
			audio.call("stop")
			audio.set("stream", null)
	almacen.queue_free()
	almacen = null
	for cuadro in 4:
		await process_frame
	print("428_PERF_CONTORNOS_FIN ", salida)
	quit()


func _caminar(nombre: String, hacia: Vector3, jugador: CharacterBody3D) -> void:
	var malla: MeshInstance3D = almacen.get_node("Estructura/" + nombre)
	var limites := malla.global_transform * malla.get_aabb()
	var desde := limites.get_center() - hacia * (limites.size.dot(hacia.abs()) / 2.0 + 0.8)
	var consulta := PhysicsRayQueryParameters3D.create(
		Vector3(desde.x, 0.8, desde.z), Vector3(desde.x, -1.0, desde.z), jugador.collision_mask
	)
	consulta.exclude = [jugador.get_rid()]
	var piso := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	if piso.is_empty() or piso.collider != almacen.get_node("Estructura/SueloSolido"):
		push_error("Premisa de rendimiento: piso conocido ausente")
		quit(1)
		return
	desde.y = piso.position.y + 0.005
	jugador.global_position = desde
	jugador.velocity = Vector3.ZERO
	var giro: Node3D = jugador.get_node("Giro")
	giro.global_basis = Basis.looking_at(hacia)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	camara.look_at(limites.get_center())
	jugador.reset_physics_interpolation()
	camara.reset_physics_interpolation()
	if not jugador.get_collision_exceptions().has(malla.get_node("StaticBody3D")):
		push_error("Premisa de rendimiento: malla detallada no está excluida")
		quit(1)
		return
	var consulta_usec: Array[float] = []
	var fisica_ms: Array[float] = []
	var cuadros_ms: Array[float] = []
	var cuerpos: Dictionary = {}
	var anterior := Time.get_ticks_usec()
	for cuadro in 420:
		await physics_frame
		var ahora := Time.get_ticks_usec()
		var inicio := Time.get_ticks_usec()
		var choque := jugador.move_and_collide(hacia * 0.05)
		var costo := Time.get_ticks_usec() - inicio
		if choque != null:
			cuerpos[str(choque.get_collider().get_path())] = true
		if cuadro >= 120:
			consulta_usec.append(float(costo))
			fisica_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			cuadros_ms.append((ahora - anterior) / 1000.0)
		anterior = ahora
		if cuadro % 120 == 0:
			print("428_PERF_PROGRESO ", nombre, " hacia=", hacia, " cuadro=", cuadro)
	var contorno: StaticBody3D = malla.get_node("Contorno")
	if not cuerpos.has(str(contorno.get_path())):
		push_error("Premisa de rendimiento: no se ejerció el contorno")
		quit(1)
		return
	(
		mediciones
		. append(
			{
				"mesh": nombre,
				"direction": hacia,
				"camera": camara.global_transform,
				"initial_feet": desde,
				"final_feet": jugador.global_position,
				"colliders": cuerpos.keys(),
				"samples": consulta_usec.size(),
				"query_us": _resumen(consulta_usec),
				"physics_ms": _resumen(fisica_ms),
				"physics_frame_interval_ms": _resumen(cuadros_ms),
				"query_us_raw": consulta_usec,
				"physics_ms_raw": fisica_ms,
				"physics_frame_interval_ms_raw": cuadros_ms,
			}
		)
	)


func _resumen(valores: Array[float]) -> Dictionary:
	var ordenados := valores.duplicate()
	ordenados.sort()
	return {
		"p50": ordenados[int(ordenados.size() * 0.50)],
		"p95": ordenados[int(ordenados.size() * 0.95)],
		"max": ordenados[-1],
	}
