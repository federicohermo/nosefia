extends Node3D

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const MUESTRAS := 240

## Vistas de cerca de los productos: nombre, ojo y punto que mira.
const CERCA := [
	["gondola", Vector3(4.2, 1.6, -0.4), Vector3(2.7, 1.1, -2.4)],
	["exhibidos", Vector3(2.4, 1.7, 2.5), Vector3(0.8, 0.6, 2.5)],
]


func _ready() -> void:
	_ejecutar.call_deferred()


func _ejecutar() -> void:
	var almacen: Node3D = ALMACEN.instantiate()
	add_child(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)
	var inicio: Vector3 = jugador.global_position
	var lector: Node3D = almacen.get("_habitaciones")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.make_current()
	var resultados := {}
	var vistas: Array[Dictionary] = []
	for nombre: String in ["local", "deposito", "bano"]:
		var partes: Array[AABB] = lector.get(nombre)
		var centro: Vector3 = lector.to_global(partes[0].get_center())
		var base := inicio if nombre == "local" else Vector3(centro.x, 0.12, centro.z)
		var ojo := base + Vector3.UP * 1.7
		var direccion := Vector3.FORWARD if nombre == "local" else Vector3.RIGHT
		vistas.append({"nombre": nombre, "base": base, "ojo": ojo, "mira": ojo + direccion})
	for cerca: Array in CERCA:
		vistas.append({"nombre": cerca[0], "base": inicio, "ojo": cerca[1], "mira": cerca[2]})
	for vista: Dictionary in vistas:
		var nombre: String = vista["nombre"]
		jugador.global_position = vista["base"]
		camara.look_at_from_position(vista["ojo"], vista["mira"])
		for cuadro: int in 60:
			await get_tree().process_frame
		var muestras: Array[float] = []
		var cuadros: Array[float] = []
		var previo := Time.get_ticks_usec()
		for cuadro: int in MUESTRAS:
			await get_tree().process_frame
			var ahora := Time.get_ticks_usec()
			cuadros.append((ahora - previo) / 1000.0)
			previo = ahora
			muestras.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		muestras.sort()
		cuadros.sort()
		resultados[nombre] = {
			"dibujos_p50": muestras[muestras.size() / 2],
			"cuadro_ms_p50": cuadros[cuadros.size() / 2],
			"cuadro_ms_p90": cuadros[cuadros.size() * 9 / 10],
			"objetos": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"primitivas": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"posicion": str(camara.global_position)
		}
		if OS.has_feature("web"):
			var capturas := int(JavaScriptBridge.eval("window.__capturas|0"))
			print("[captura] " + nombre)
			while int(JavaScriptBridge.eval("window.__capturas|0")) == capturas:
				await get_tree().process_frame
		else:
			get_viewport().get_texture().get_image().save_png("user://captura_%s.png" % nombre)
	print("[informe] " + JSON.stringify(resultados))
	if not OS.has_feature("web"):
		print("[carpeta] " + ProjectSettings.globalize_path("user://"))
		get_tree().quit()
