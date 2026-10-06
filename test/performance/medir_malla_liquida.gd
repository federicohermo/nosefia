## Mide lo que cuesta dibujar la malla líquida, y deja la malla de cada pose para compararla
## entre dos árboles.
extends Node3D

const Superficie := preload("res://src/escenas/objetos/superficie_liquida.gd")
const DIBUJOS := 600
const REPETICIONES := 3
const NIVELES: Array[float] = [0.0, 0.2, 0.7, 1.0]
const FASES: Array[float] = [0.0, 1.0, 7.0]
const PENDIENTE := Vector2(0.035, -0.02)
const INTENTOS := 3


func _ready() -> void:
	_ejecutar.call_deferred()


## Una superficie activa y sin procesos propios: sólo se dibuja cuando se lo piden.
static func crear(padre: Node, en_balde: bool) -> Superficie:
	var recipiente := Recipiente.new()
	padre.add_child(recipiente)
	var superficie := Superficie.new()
	superficie.en_balde = en_balde
	superficie.mesh = CylinderMesh.new()
	superficie.material_override = StandardMaterial3D.new()
	recipiente.add_child(superficie)
	superficie.set_process(false)
	superficie.set_physics_process(false)
	superficie.set("_onda", 1.0)
	superficie.set("_pendiente", PENDIENTE)
	return superficie


## Cada combinación de nivel y fase, en el orden en que se informa.
static func poses() -> Array[Dictionary]:
	var todas: Array[Dictionary] = []
	for nivel: float in NIVELES:
		for fase: float in FASES:
			todas.append({"nivel": nivel, "fase": fase})
	return todas


## Deja la superficie en una pose fija y la dibuja: el nivel es cuánto está lleno el balde, y
## la fase es el tiempo de la onda de la mancha.
static func posar(superficie: Superficie, nivel: float, fase: float) -> void:
	superficie.set("_nivel_visual", nivel)
	superficie.set("_tiempo", fase)
	superficie.call("_dibujar")


## Lo que la malla tiene hoy, leído del renderizador: es lo que se compara entre dos árboles.
static func huella(superficie: Superficie) -> Dictionary:
	var malla := superficie.mesh as ArrayMesh
	var arrays := malla.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var coordenadas: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return {
		"superficies": malla.get_surface_count(),
		"vertices": vertices.size(),
		"vertices_sha256": _sha256(vertices.to_byte_array()),
		"normales_sha256": _sha256(normales.to_byte_array()),
		"uv_sha256": _sha256(coordenadas.to_byte_array()),
		"indices_sha256": _sha256(indices.to_byte_array()),
		"aabb": str(malla.get_aabb()),
	}


## Cuántos bytes pide de más una llamada mientras corre, o -1 si no se pudo medir.
## El motor sólo cuenta su memoria en una compilación de depuración: en las demás da cero.
static func pedido_transitorio(llamada: Callable) -> int:
	var menor := -1
	var lastres: Array = []
	lastres.resize(INTENTOS)
	for intento: int in INTENTOS:
		# El pico sólo sube si el uso lo alcanza: un lastre del tamaño del hueco los iguala.
		var lastre := PackedByteArray()
		lastre.resize(OS.get_static_memory_peak_usage() - OS.get_static_memory_usage() + 4096)
		lastres[intento] = lastre
		var piso := OS.get_static_memory_peak_usage()
		if OS.get_static_memory_usage() != piso:
			continue
		llamada.call()
		var pedido := OS.get_static_memory_peak_usage() - piso
		# Otro hilo sólo puede sumar: el menor de los intentos es el de la llamada.
		menor = pedido if menor < 0 else mini(menor, pedido)
	return menor


## Las subidas de buffers que contó el navegador, o -1 fuera de la web.
static func subidas() -> int:
	if not OS.has_feature("web"):
		return -1
	return int(JavaScriptBridge.eval("window.__subidas_de_buffers|0"))


static func _sha256(bytes: PackedByteArray) -> String:
	var contexto := HashingContext.new()
	contexto.start(HashingContext.HASH_SHA256)
	contexto.update(bytes)
	return contexto.finish().hex_encode()


func _ejecutar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("La medición necesita un renderizador real; ejecutar sin --headless.")
		get_tree().quit(1)
		return
	var camara := Camera3D.new()
	add_child(camara)
	camara.position = Vector3(0.0, 2.0, 1.0)
	camara.look_at(Vector3.ZERO)
	camara.current = true
	var superficies := {"balde": crear(self, true), "mancha": crear(self, false)}
	# Los primeros cuadros compilan los shaders de lo que entra en vista.
	await get_tree().create_timer(1.0).timeout

	var informe := {
		"compilacion_debug": OS.is_debug_build(),
		"fecha_utc": Time.get_datetime_string_from_system(true),
		"godot": Engine.get_version_info().string,
		"sistema": OS.get_name(),
		"cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"renderizador": RenderingServer.get_current_rendering_method(),
		"resolucion": str(get_viewport().get_visible_rect().size),
		"dibujos": DIBUJOS,
		"poses": [],
	}
	for nombre: String in superficies:
		var superficie: Superficie = superficies[nombre]
		informe[nombre] = _medir(superficie)
		for pose: Dictionary in poses():
			(informe.poses as Array).append(_registrar(nombre, superficie, pose))
		await get_tree().process_frame
	_entregar(informe)


func _medir(superficie: Superficie) -> Dictionary:
	var tiempos: Array[float] = []
	var subidas_por_tanda: Array[int] = []
	for repeticion: int in REPETICIONES:
		var antes := subidas()
		var inicio := Time.get_ticks_usec()
		for dibujo: int in DIBUJOS:
			superficie.set("_tiempo", dibujo / 60.0)
			superficie.call("_dibujar")
		tiempos.append(float(Time.get_ticks_usec() - inicio) / DIBUJOS)
		subidas_por_tanda.append(subidas() - antes)
	var pedido := pedido_transitorio(Callable(superficie, "_dibujar"))
	return {
		"us_por_dibujo": tiempos,
		"subidas_por_tanda": subidas_por_tanda,
		"bytes_transitorios_por_dibujo": pedido if OS.is_debug_build() else -1,
		"subidas_con_agua_quieta": _subidas_con_agua_quieta(superficie),
	}


## La pose dibujada sobre la superficie que ya existe, y otra vez después de quitarla.
func _registrar(nombre: String, superficie: Superficie, pose: Dictionary) -> Dictionary:
	var antes := subidas()
	posar(superficie, pose.nivel, pose.fase)
	var registro := {"superficie": nombre, "subidas": subidas() - antes}
	registro.merge(pose)
	registro.merge(huella(superficie))
	(superficie.mesh as ArrayMesh).clear_surfaces()
	posar(superficie, pose.nivel, pose.fase)
	registro["reconstruida"] = huella(superficie)
	return registro


## El segundo dibujo de la misma agua quieta se descarta: no sube nada.
func _subidas_con_agua_quieta(superficie: Superficie) -> int:
	superficie.set("_onda", 0.0)
	superficie.set("_pendiente", Vector2.ZERO)
	superficie.call("_dibujar")
	var antes := subidas()
	superficie.call("_dibujar")
	var descartadas := subidas() - antes
	superficie.set("_onda", 1.0)
	superficie.set("_pendiente", PENDIENTE)
	return descartadas


func _entregar(informe: Dictionary) -> void:
	if OS.has_feature("web"):
		print("[informe] " + JSON.stringify(informe))
		return
	var revision: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], revision)
	informe["commit"] = str(revision[0]).strip_edges() if not revision.is_empty() else "desconocido"
	var ruta := "res://reports/rendimiento-malla-liquida.json"
	DirAccess.make_dir_recursive_absolute("res://reports")
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar " + ruta)
		get_tree().quit(1)
		return
	archivo.store_string(JSON.stringify(informe, "\t"))
	get_tree().quit()


class Recipiente:
	extends Node3D
	var lugar := 0
