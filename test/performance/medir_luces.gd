extends Node3D

enum Tipo { OMNI, SPOT, AREA }

const CANTIDADES: Array[int] = [1, 2, 4, 8, 16]
const SEGUNDOS := 2.0
## El techo del local, que es donde van las luminarias. Las luces se reparten adentro.
const TECHO := Rect2(-5.0, -7.0, 9.0, 13.0)
const ALTURA := 3.9
## Alcanza el piso y las paredes desde el techo: es el caso caro, el de una luz que alumbra todo
## lo que se ve. Una luz de menos alcance cuesta menos, porque la pagan menos objetos.
const ALCANCE := 8.0
## Desde donde arranca el jugador: muestra el local entero, y es la vista más cara.
const OJO := Vector3(4.5, 1.8, 4.0)
const MIRA := Vector3(-3.0, 1.0, -3.0)
const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Reposicion := preload("res://test/performance/medir_reposicion.gd")


func _ready() -> void:
	_ejecutar.call_deferred()


## Una grilla lo más cuadrada posible adentro del techo, para que las luces se pisen como se
## pisan las luminarias de un local y no queden todas en un punto.
static func posiciones(cantidad: int) -> Array[Vector3]:
	var columnas := ceili(sqrt(cantidad))
	var filas := ceili(float(cantidad) / columnas)
	var puntos: Array[Vector3] = []
	for indice in cantidad:
		var en_x := (indice % columnas + 0.5) / columnas
		var en_z := (floori(float(indice) / columnas) + 0.5) / filas
		puntos.append(
			Vector3(
				TECHO.position.x + TECHO.size.x * en_x,
				ALTURA,
				TECHO.position.y + TECHO.size.y * en_z
			)
		)
	return puntos


static func crear(tipo: Tipo, cantidad: int, con_sombra: bool) -> Node3D:
	var lote := Node3D.new()
	for punto in posiciones(cantidad):
		var luz: Light3D
		match tipo:
			Tipo.OMNI:
				var omni := OmniLight3D.new()
				omni.omni_range = ALCANCE
				luz = omni
			Tipo.SPOT:
				var spot := SpotLight3D.new()
				spot.spot_range = ALCANCE
				spot.spot_angle = 60.0
				luz = spot
			Tipo.AREA:
				var area := AreaLight3D.new()
				area.area_range = ALCANCE
				area.area_size = Vector2(2.0, 1.0)
				luz = area
		luz.shadow_enabled = con_sombra
		# Tanto el foco como la luz de área alumbran hacia su -Z: se las apunta al piso.
		luz.rotation_degrees.x = -90.0
		luz.position = punto
		lote.add_child(luz)
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
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for cuerpo in almacen.find_children("*", "CharacterBody3D", true, false):
		cuerpo.process_mode = Node.PROCESS_MODE_DISABLED
	var camara := Camera3D.new()
	add_child(camara)
	camara.position = OJO
	camara.look_at(MIRA)
	camara.current = true
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

	var resultados: Array[Dictionary] = []
	var las_del_juego := almacen.find_children("*", "Light3D", true, false)
	resultados.append(await _caso("las del juego", las_del_juego.size(), false))
	for luz: Light3D in las_del_juego:
		luz.visible = false
	resultados.append(await _caso("ninguna", 0, false))
	for tipo: Tipo in Tipo.values():
		for con_sombra: bool in [false, true]:
			for cantidad in CANTIDADES:
				var lote := crear(tipo, cantidad, con_sombra)
				add_child(lote)
				resultados.append(await _caso(Tipo.keys()[tipo], cantidad, con_sombra))
				lote.queue_free()
				await get_tree().process_frame

	var revision: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], revision)
	var informe := {
		"commit": str(revision[0]).strip_edges() if not revision.is_empty() else "desconocido",
		"compilacion_debug": OS.is_debug_build(),
		"fecha_utc": Time.get_datetime_string_from_system(true),
		"godot": Engine.get_version_info().string,
		"sistema": OS.get_name(),
		"cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"renderizador": RenderingServer.get_current_rendering_method(),
		"resolucion": str(get_viewport().get_visible_rect().size),
		"luces_por_objeto":
		ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object"),
		"luces_en_total":
		ProjectSettings.get_setting("rendering/limits/opengl/max_renderable_lights"),
		"alcance_m": ALCANCE,
		"segundos_por_caso": SEGUNDOS,
		"resultados": resultados,
	}
	var ruta := "res://reports/rendimiento-luces.json"
	DirAccess.make_dir_recursive_absolute("res://reports")
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar " + ruta)
		get_tree().quit(1)
		return
	archivo.store_string(JSON.stringify(informe, "\t"))
	get_tree().quit()


func _caso(nombre: String, cantidad: int, con_sombra: bool) -> Dictionary:
	# El primer cuadro con una luz de un tipo nuevo compila su variante del shader.
	await get_tree().create_timer(1.0).timeout
	var medicion := await _medir()
	medicion["luces"] = nombre
	medicion["cantidad"] = cantidad
	medicion["con_sombra"] = con_sombra
	print(
		(
			"%-14s x%-3d sombra %-5s  gpu %.2f ms  cpu %.2f ms  cuadro %.2f ms  dibujos %d"
			% [
				nombre,
				cantidad,
				con_sombra,
				medicion["gpu_ms_p50"],
				medicion["cpu_de_dibujo_ms_p50"],
				medicion["cuadro_ms_p50"],
				medicion["dibujos_p50"],
			]
		)
	)
	return medicion


func _medir() -> Dictionary:
	var vista := get_viewport().get_viewport_rid()
	var cuadros: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var dibujos: Array[float] = []
	var inicio := Time.get_ticks_usec()
	var anterior := inicio
	while Time.get_ticks_usec() - inicio < SEGUNDOS * 1000000:
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		cuadros.append((ahora - anterior) / 1000.0)
		anterior = ahora
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vista))
		cpu.append(
			(
				RenderingServer.viewport_get_measured_render_time_cpu(vista)
				+ RenderingServer.get_frame_setup_time_cpu()
			)
		)
		dibujos.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return {
		"muestras": cuadros.size(),
		"cuadro_ms_p50": Reposicion.percentil(cuadros, 0.5),
		"cuadro_ms_p95": Reposicion.percentil(cuadros, 0.95),
		"gpu_ms_p50": Reposicion.percentil(gpu, 0.5),
		"cpu_de_dibujo_ms_p50": Reposicion.percentil(cpu, 0.5),
		"dibujos_p50": Reposicion.percentil(dibujos, 0.5),
	}
