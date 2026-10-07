## Mide qué hace el agua del balde mientras está fuera de la cámara, y qué cuesta comprobarlo.
extends Node3D

const Malla := preload("res://test/performance/medir_malla_liquida.gd")
const Superficie := preload("res://src/escenas/objetos/superficie_liquida.gd")
const Ondas := preload("res://src/escenas/objetos/ondas_del_balde.gd")
const PASOS_FUERA := 120
const LLAMADAS_QUIETAS := 20000
const LLAMADAS_ACTIVAS := 1000
const REPETICIONES := 3
const PASO := 1.0 / 60.0
const LEJOS := Vector3(100.0, 0.0, 0.0)

var _camara := Camera3D.new()


func _ready() -> void:
	_ejecutar.call_deferred()


## Dónde está el balde en cada paso: se mueve sin salir del lugar que la cámara no ve.
static func posicion_en(paso: int) -> Vector3:
	return LEJOS + Vector3(sin(paso * 0.12) * 0.03, 0.0, 0.0)


## La cámara mira al balde desde arriba, o le da el costado desde el origen.
static func apuntar(camara: Camera3D, al_balde: bool) -> void:
	if al_balde:
		camara.look_at_from_position(LEJOS + Vector3(0.0, 2.0, 1.0), LEJOS)
	else:
		camara.transform = Transform3D.IDENTITY


## Mueve el balde y avanza un paso su simulación, sin dibujar.
static func avanzar(superficie: Superficie, paso: int) -> void:
	(superficie.get_parent() as Node3D).position = posicion_en(paso)
	superficie.call("_physics_process", PASO)


## Cuántas de las ocho esquinas de la caja de la malla entran en el encuadre.
static func esquinas_en_cuadro(camara: Camera3D, superficie: Superficie) -> int:
	var caja := (superficie.mesh as ArrayMesh).custom_aabb
	var adentro := 0
	for esquina: int in 8:
		var punto := superficie.global_transform * caja.get_endpoint(esquina)
		adentro += int(camara.is_position_in_frustum(punto))
	return adentro


## Verdadero si un mismo plano del encuadre deja afuera las ocho esquinas de la caja.
static func esta_fuera_de_cuadro(camara: Camera3D, superficie: Superficie) -> bool:
	var caja := (superficie.mesh as ArrayMesh).custom_aabb
	for plano: Plane in camara.get_frustum():
		var afuera := 0
		for esquina: int in 8:
			var punto := superficie.global_transform * caja.get_endpoint(esquina)
			afuera += int(plano.is_point_over(punto))
		if afuera == 8:
			return true
	return false


## El estado de la simulación que no depende de haber dibujado.
static func estado(superficie: Superficie) -> PackedByteArray:
	var ondas: Ondas = superficie.get("_ondas")
	return var_to_bytes(
		[
			ondas.alturas_muestreadas(),
			superficie.get("_pendiente"),
			superficie.get("_impulso"),
			superficie.get("_onda"),
		]
	)


static func sha256(bytes: PackedByteArray) -> String:
	var contexto := HashingContext.new()
	contexto.start(HashingContext.HASH_SHA256)
	contexto.update(bytes)
	return contexto.finish().hex_encode()


func _ejecutar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("La medición necesita un renderizador real; ejecutar sin --headless.")
		get_tree().quit(1)
		return
	# Interpolada, la cámara tarda un paso de física en llegar: el encuadre tiene que valer ya.
	_camara.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_camara)
	_camara.make_current()
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-60.0, -30.0, 0.0)
	add_child(luz)
	var superficie := Malla.crear(self, true)
	(superficie.get_parent() as Node3D).position = LEJOS
	var informe := {
		"compilacion_debug": OS.is_debug_build(),
		"fecha_utc": Time.get_datetime_string_from_system(true),
		"godot": Engine.get_version_info().string,
		"sistema": OS.get_name(),
		"cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"renderizador": RenderingServer.get_current_rendering_method(),
		"resolucion": str(get_viewport().get_visible_rect().size),
	}
	informe["costo"] = await _medir_el_costo(superficie)
	informe["fuera"] = await _medir_fuera(superficie)
	informe["retorno"] = await _medir_el_retorno(superficie)
	_entregar(informe)


## Lleva la cámara, deja pasar un cuadro con ese encuadre y dice si la premisa vale.
func _encuadrar(superficie: Superficie, al_balde: bool) -> bool:
	apuntar(_camara, al_balde)
	await get_tree().process_frame
	await get_tree().process_frame
	return _premisa(superficie, al_balde)


func _premisa(superficie: Superficie, adentro: bool) -> bool:
	if adentro:
		return esquinas_en_cuadro(_camara, superficie) == 8
	return esta_fuera_de_cuadro(_camara, superficie)


func _medir_el_costo(superficie: Superficie) -> Dictionary:
	var costo := {}
	for caso: Array in [
		["quieta_visible", true, false, LLAMADAS_QUIETAS],
		["activa_visible", true, true, LLAMADAS_ACTIVAS],
		["activa_fuera", false, true, LLAMADAS_ACTIVAS],
	]:
		var premisa := await _encuadrar(superficie, caso[1])
		superficie.set("_onda", 1.0 if caso[2] else 0.0)
		superficie.set("_pendiente", Malla.PENDIENTE if caso[2] else Vector2.ZERO)
		superficie.call("_process", PASO)
		var tiempos: Array[float] = []
		var subidas_por_tanda: Array[int] = []
		for repeticion: int in REPETICIONES:
			var antes := Malla.subidas()
			var inicio := Time.get_ticks_usec()
			for llamada: int in caso[3]:
				superficie.call("_process", PASO)
			tiempos.append(float(Time.get_ticks_usec() - inicio) / caso[3])
			subidas_por_tanda.append(Malla.subidas() - antes)
			await get_tree().process_frame
		costo[caso[0]] = {
			"premisa_del_encuadre": premisa and _premisa(superficie, caso[1]),
			"llamadas": caso[3],
			"us_por_llamada": tiempos,
			"subidas_por_tanda": subidas_por_tanda,
		}
	return costo


## El balde se mueve fuera del encuadre: la simulación avanza, y se cuenta lo que sube la malla.
func _medir_fuera(superficie: Superficie) -> Dictionary:
	var premisa := await _encuadrar(superficie, false)
	superficie.reiniciar()
	var cadena := HashingContext.new()
	cadena.start(HashingContext.HASH_SHA256)
	var pasos_fuera := 0
	var subidas := 0
	for paso: int in PASOS_FUERA:
		await get_tree().physics_frame
		avanzar(superficie, paso)
		cadena.update(estado(superficie))
		pasos_fuera += int(esta_fuera_de_cuadro(_camara, superficie))
		var antes := Malla.subidas()
		superficie.call("_process", PASO)
		subidas += Malla.subidas() - antes
		await get_tree().process_frame
	return {
		"premisa_del_encuadre": premisa,
		"pasos": PASOS_FUERA,
		"pasos_con_la_caja_fuera": pasos_fuera,
		"subidas_de_la_malla": subidas,
		"onda_al_final": superficie.get("_onda"),
		"estados_sha256": cadena.finish().hex_encode(),
	}


## La cámara vuelve al balde: el primer dibujo deja la malla del estado de ahora.
func _medir_el_retorno(superficie: Superficie) -> Dictionary:
	var premisa := await _encuadrar(superficie, true)
	var antes := Malla.subidas()
	superficie.call("_process", PASO)
	var subidas := Malla.subidas() - antes
	var vertices: PackedVector3Array = superficie.get("_vertices")
	var retorno := {
		"premisa_del_encuadre": premisa,
		"esquinas_en_cuadro": esquinas_en_cuadro(_camara, superficie),
		"subidas_de_la_malla": subidas,
		"estado_sha256": sha256(estado(superficie)),
		"vertices_calculados_sha256": sha256(vertices.to_byte_array()),
		"malla": Malla.huella(superficie),
	}
	await get_tree().process_frame
	await get_tree().process_frame
	if OS.has_feature("web"):
		var capturas := int(JavaScriptBridge.eval("window.__capturas|0"))
		print("[captura] retorno")
		while int(JavaScriptBridge.eval("window.__capturas|0")) == capturas:
			await get_tree().process_frame
	return retorno


func _entregar(informe: Dictionary) -> void:
	if OS.has_feature("web"):
		print("[informe] " + JSON.stringify(informe))
		return
	var revision: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], revision)
	informe["commit"] = str(revision[0]).strip_edges() if not revision.is_empty() else "desconocido"
	var ruta := "res://reports/rendimiento-agua-fuera-de-camara.json"
	DirAccess.make_dir_recursive_absolute("res://reports")
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar " + ruta)
		get_tree().quit(1)
		return
	archivo.store_string(JSON.stringify(informe, "\t"))
	get_tree().quit()
