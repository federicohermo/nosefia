extends Node3D

enum Escenario { ESTANTE, CAIDA, REPOSO }

const CANTIDADES: Array[int] = [100, 500, 2000]
const SEGUNDOS := 3.0
const ALMACEN := preload("res://src/escenas/almacen.tscn")
const GrupoDelPiso := preload("res://src/escenas/objetos/grupo_del_piso.gd")
const OBJETO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")

var modelos: Array[Mesh] = []
var formas: Array[ConvexPolygonShape3D] = []
var _fisica: Array[float] = []
var _midiendo := false


func _ready() -> void:
	_ejecutar.call_deferred()


func _physics_process(_delta: float) -> void:
	if _midiendo:
		_fisica.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)


static func percentil(valores: Array[float], proporcion: float) -> float:
	var ordenados := valores.duplicate()
	ordenados.sort()
	return ordenados[maxi(0, ceili(ordenados.size() * proporcion) - 1)]


func crear(cantidad: int, escenario: Escenario, agrupado: bool = false) -> Node3D:
	var lote := Node3D.new()
	for id in modelos.size():
		var malla := modelos[id]
		var centro := malla.get_aabb().get_center()
		var posiciones: Array[Vector3] = []
		for indice in range(id, cantidad, modelos.size()):
			posiciones.append(Vector3((indice % 45) * 0.7 - 15.4, 0.5, (indice / 45) * 0.7 - 15.4))
		if escenario == Escenario.ESTANTE:
			var grupo := MultiMeshInstance3D.new()
			var copias := MultiMesh.new()
			copias.transform_format = MultiMesh.TRANSFORM_3D
			copias.mesh = malla
			copias.instance_count = posiciones.size()
			for indice in posiciones.size():
				copias.set_instance_transform(
					indice, Transform3D(Basis.IDENTITY, posiciones[indice] - centro)
				)
			grupo.multimesh = copias
			lote.add_child(grupo)
		else:
			var grupo: GrupoDelPiso = null
			if agrupado:
				grupo = GrupoDelPiso.new()
				grupo.preparar(malla, posiciones.size())
				lote.add_child(grupo)
			for posicion in posiciones:
				var cuerpo: RigidBody3D = OBJETO.instantiate()
				cuerpo.freeze = true
				cuerpo.position = posicion + Vector3.UP * 3
				cuerpo.get_node("Forma").shape = formas[id]
				var vista: MeshInstance3D = cuerpo.get_node("Malla")
				vista.mesh = malla
				vista.position = -centro
				lote.add_child(cuerpo)
				if grupo != null:
					grupo.agregar(cuerpo)
	return lote


func _ejecutar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("La medición necesita un renderizador real; ejecutar sin --headless.")
		get_tree().quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var almacen := ALMACEN.instantiate()
	add_child(almacen)
	modelos.assign(almacen.get("_reposicion_manual").get("_modelos"))
	formas.assign(almacen.get("_reposicion_manual").get("_formas"))
	almacen.queue_free()
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camara := Camera3D.new()
	add_child(camara)
	camara.position = Vector3(0, 30, 28)
	camara.look_at(Vector3.ZERO)
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = 48
	camara.current = true
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-60, -30, 0)
	add_child(luz)
	var suelo := StaticBody3D.new()
	var colision := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(40, 0.2, 40)
	colision.shape = caja
	suelo.add_child(colision)
	add_child(suelo)
	var resultados: Array[Dictionary] = []
	for cantidad in CANTIDADES:
		for escenario: Escenario in Escenario.values():
			for agrupado: bool in [false] if escenario == Escenario.ESTANTE else [false, true]:
				var lote := crear(cantidad, escenario, agrupado)
				add_child(lote)
				# Calentar materiales antes de medir; los cuerpos todavía están congelados.
				await get_tree().create_timer(1.0).timeout
				for cuerpo: RigidBody3D in lote.find_children("*", "RigidBody3D", false, false):
					cuerpo.freeze = false
				if escenario == Escenario.REPOSO:
					await get_tree().create_timer(5.0).timeout
					for cuerpo: RigidBody3D in lote.find_children("*", "RigidBody3D", false, false):
						cuerpo.sleeping = true
					await get_tree().create_timer(0.25).timeout
				var medicion := await _medir()
				medicion["cantidad"] = cantidad
				medicion["piso_multimesh"] = agrupado
				medicion["escenario"] = Escenario.keys()[escenario]
				resultados.append(medicion)
				lote.queue_free()
				await get_tree().process_frame

	var revision: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], revision)
	var estado: Array = []
	OS.execute("git", ["status", "--porcelain"], estado)
	var informe := {
		"grupo_sha256": FileAccess.get_sha256("res://src/escenas/objetos/grupo_del_piso.gd"),
		"script_sha256": FileAccess.get_sha256("res://test/performance/medir_reposicion.gd"),
		"commit": str(revision[0]).strip_edges() if not revision.is_empty() else "desconocido",
		"cambios_sin_commit": not estado.is_empty() and not str(estado[0]).strip_edges().is_empty(),
		"compilacion_debug": OS.is_debug_build(),
		"fecha_utc": Time.get_datetime_string_from_system(true),
		"godot": Engine.get_version_info().string,
		"sistema": OS.get_name(),
		"cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"renderizador": RenderingServer.get_current_rendering_method(),
		"resolucion": str(get_viewport().get_visible_rect().size),
		"fisica_hz": Engine.physics_ticks_per_second,
		"vsync": false,
		"segundos_por_caso": SEGUNDOS,
		"resultados": resultados,
	}
	var ruta := "res://reports/rendimiento-reposicion.json"
	DirAccess.make_dir_recursive_absolute("res://reports")
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar " + ruta)
		get_tree().quit(1)
		return
	archivo.store_string(JSON.stringify(informe, "\t"))
	get_tree().quit()


func _medir() -> Dictionary:
	var cuadros: Array[float] = []
	_fisica.clear()
	_midiendo = true
	var dibujos: Array[float] = []
	var activos: Array[float] = []
	var memoria := 0.0
	var inicio := Time.get_ticks_usec()
	var anterior := inicio
	while Time.get_ticks_usec() - inicio < SEGUNDOS * 1000000:
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		cuadros.append((ahora - anterior) / 1000.0)
		anterior = ahora
		dibujos.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		activos.append(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
		memoria = maxf(memoria, Performance.get_monitor(Performance.MEMORY_STATIC))
	_midiendo = false
	return {
		"muestras": cuadros.size(),
		"cuadro_ms_p50": percentil(cuadros, 0.5),
		"cuadro_ms_p95": percentil(cuadros, 0.95),
		"cuadro_ms_p99": percentil(cuadros, 0.99),
		"cuadro_ms_max": cuadros.max(),
		"muestras_fisica": _fisica.size(),
		"fisica_ms_p95": percentil(_fisica, 0.95),
		"dibujos_p50": percentil(dibujos, 0.5),
		"cuerpos_activos_max": activos.max(),
		"memoria_estatica_mib_max": memoria / 1048576,
	}
