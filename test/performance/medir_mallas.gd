extends Node3D

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const MUESTRAS := 240


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
	for nombre: String in ["local", "deposito", "bano"]:
		var partes: Array[AABB] = lector.get(nombre)
		var caja: AABB = partes[0]
		var centro: Vector3 = lector.to_global(caja.get_center())
		jugador.global_position = inicio if nombre == "local" else Vector3(centro.x, 0.12, centro.z)
		var ojo := jugador.global_position + Vector3.UP * 1.7
		var direccion := Vector3.FORWARD if nombre == "local" else Vector3.RIGHT
		camara.look_at_from_position(ojo, ojo + direccion)
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
	print("[informe] " + JSON.stringify(resultados))
