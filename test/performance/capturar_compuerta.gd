extends Node3D
## Saca capturas del mostrador y de su compuerta cerrada o abierta, desde un JSON de vistas.
##
##     godot --path . --resolution 1280x720 res://test/performance/capturar_compuerta.tscn \
##         -- VISTAS.json CARPETA
##
## Cada entrada lleva `{"nombre", "ojo": [x, y, z], "mira": [x, y, z], "abierta": false}`.

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const CUADROS_DE_ASIENTO := 45
const CUADROS_DE_GIRO := 90


func _ready() -> void:
	_capturar.call_deferred()


func _capturar() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.size() < 2:
		push_error("uso: -- VISTAS.json CARPETA")
		get_tree().quit(1)
		return
	var vistas: Array = JSON.parse_string(FileAccess.get_file_as_string(argumentos[0]))
	var carpeta := argumentos[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	var almacen: Node3D = ALMACEN.instantiate()
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)
	# El sensor de empuje de la compuerta detecta cuerpos cercanos; se aparta al jugador.
	jugador.collision_layer = 0
	jugador.collision_mask = 0
	jugador.global_position = Vector3(0.0, -20.0, 0.0)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.make_current()
	var compuerta: Node = almacen.get_node("Estructura/compuerta_mostrador/CuerpoDeLaHoja")
	for vista: Dictionary in vistas:
		var ocultos: Array[Node3D] = []
		for ruta_oculta: String in vista.get("ocultar", []):
			var nodo := almacen.get_node_or_null(ruta_oculta) as Node3D
			if nodo != null and nodo.visible:
				nodo.visible = false
				ocultos.append(nodo)
		var abierta := bool(vista.get("abierta", false))
		if abierta != compuerta.call("puerta").abierta():
			compuerta.call("alternar")
			for _cuadro: int in CUADROS_DE_GIRO:
				await get_tree().physics_frame
		var ojo := _vector(vista["ojo"])
		camara.look_at_from_position(ojo, _vector(vista["mira"]))
		for _cuadro: int in CUADROS_DE_ASIENTO:
			await get_tree().process_frame
		var ruta := carpeta.path_join("%s.png" % vista["nombre"])
		if get_viewport().get_texture().get_image().save_png(ruta) != OK:
			push_error("no se pudo escribir %s" % ruta)
		print("[captura] %s %s abierta=%s" % [ruta, ojo, abierta])
		for nodo: Node3D in ocultos:
			nodo.visible = true
	get_tree().quit()


func _vector(valores: Array) -> Vector3:
	return Vector3(valores[0], valores[1], valores[2])
