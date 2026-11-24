extends Node3D
## Saca una captura del almacén por cada vista de un JSON, para comparar el arte antes y después.
##
##     godot --path . res://test/performance/capturar_vistas.tscn -- VISTAS.json CARPETA
##
## El JSON es una lista de `{"nombre", "ojo": [x, y, z], "mira": [x, y, z]}`. Sin JSON saca cuatro
## vistas desde el centro de cada ambiente, que sirven para elegir las propias.

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AMBIENTES: Array[String] = ["local", "deposito", "bano"]
const RUMBOS := {"n": Vector3.FORWARD, "e": Vector3.RIGHT, "s": Vector3.BACK, "o": Vector3.LEFT}
const CUADROS_DE_ASIENTO := 45


func _ready() -> void:
	_capturar.call_deferred()


func _capturar() -> void:
	var argumentos := OS.get_cmdline_user_args()
	var carpeta := argumentos[1] if argumentos.size() > 1 else "user://"
	var almacen: Node3D = ALMACEN.instantiate()
	add_child(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.make_current()
	var vistas := _vistas(argumentos, almacen)
	for vista: Dictionary in vistas:
		var ojo := _vector(vista["ojo"])
		jugador.global_position = Vector3(ojo.x, 0.12, ojo.z)
		camara.look_at_from_position(ojo, _vector(vista["mira"]))
		for cuadro: int in CUADROS_DE_ASIENTO:
			await get_tree().process_frame
		var ruta := carpeta.path_join("%s.png" % vista["nombre"])
		if get_viewport().get_texture().get_image().save_png(ruta) != OK:
			push_error("no se pudo escribir %s" % ruta)
		print("[captura] %s %s" % [ruta, ojo])
	get_tree().quit()


func _vistas(argumentos: PackedStringArray, almacen: Node3D) -> Array:
	if argumentos.size() > 0 and argumentos[0] != "":
		return JSON.parse_string(FileAccess.get_file_as_string(argumentos[0]))
	var lector: Node3D = almacen.get("_habitaciones")
	var vistas := []
	for ambiente: String in AMBIENTES:
		var partes: Array[AABB] = lector.get(ambiente)
		var centro: Vector3 = lector.to_global(partes[0].get_center())
		var ojo := Vector3(centro.x, 1.7, centro.z)
		print(
			(
				"[ambiente] %s %s"
				% [
					ambiente,
					lector.to_global(partes[0].position),
				]
			)
		)
		print("[ambiente] %s fin %s" % [ambiente, lector.to_global(partes[0].end)])
		for rumbo: String in RUMBOS:
			var mira: Vector3 = ojo + RUMBOS[rumbo]
			vistas.append(
				{
					"nombre": "%s_%s" % [ambiente, rumbo],
					"ojo": [ojo.x, ojo.y, ojo.z],
					"mira": [mira.x, mira.y, mira.z]
				}
			)
	return vistas


func _vector(valores: Array) -> Vector3:
	return Vector3(valores[0], valores[1], valores[2])
