## Repite el fixture heredado de cinco cajas y conserva sus emisores directos para diagnosticarlo.
extends SceneTree

const MEDIA := 0.3037
const PISO := Vector3(4.49, 0.102, -10.0)

var almacen: Node3D
var pila: Array[RigidBody3D] = []
var red: RedDeSeguridad
var ultimo_rescate := 0


func _init() -> void:
	call_deferred("_medir")


func _medir() -> void:
	almacen = load("res://src/escenas/almacen.tscn").instantiate()
	root.add_child(almacen)
	await physics_frame
	for nodo: Node in almacen.find_children("*", "Node", true, false):
		if nodo is RedDeSeguridad:
			red = nodo
	var jugador: CharacterBody3D = almacen.get("_jugador")
	for caja: RigidBody3D in almacen.get("_cajas_de_productos"):
		if caja.get_node("Cuerpo").scale.x >= MEDIA and pila.size() < 5:
			pila.append(caja)
	for piso in pila.size():
		var caja := pila[piso]
		caja.global_position = PISO + Vector3.UP * MEDIA * (1 + 2 * piso)
		caja.call("quedarse_quieta")
		caja.sleeping_state_changed.connect(_evento.bind(caja, "sleeping_state_changed"))
		caja.empujada.connect(_empujada)
	jugador.global_position = PISO + Vector3(0.0, 0.01, 1.2)
	await physics_frame
	_snapshot("pila_inicial")
	await _cuadros(20)
	_accion(jugador, pila[0])
	_snapshot("primer_retiro")
	await _cuadros(150)
	_snapshot("primera_caida")
	_mirar(jugador, PI, deg_to_rad(-40.0))
	_snapshot("mirar_otro_lado_antes_drop")
	_accion(jugador, pila[0])
	_snapshot("dejar_primera_caja")
	await physics_frame
	_accion(jugador, pila[1])
	_snapshot("segundo_retiro")
	await _cuadros(150)
	_snapshot("segunda_caida")
	almacen.get("_agarre").entregar()
	for audio: Node in almacen.find_children("*", "Node", true, false):
		if audio is AudioStreamPlayer or audio is AudioStreamPlayer3D:
			audio.call("stop")
			audio.set("stream", null)
	almacen.queue_free()
	almacen = null
	pila.clear()
	red = null
	for cuadro in 8:
		await process_frame
	print("428_TRAZA_PILA_FIN")
	quit()


func _accion(jugador: Node3D, objetivo: Node3D) -> void:
	# Exactamente como el test heredado: no presenta este diagnóstico como mira real de AC100.
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _mirar(jugador: Node3D, giro: float, alto: float) -> void:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var evento := InputEventMouseMotion.new()
	evento.relative = (
		Vector2(jugador.get_node("Giro").rotation.y - giro, camara.rotation.x - alto)
		/ ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE
	)
	jugador.call("_unhandled_input", evento)


func _cuadros(cantidad: int) -> void:
	for cuadro in cantidad:
		await physics_frame
		if red.rescates.size() != ultimo_rescate:
			ultimo_rescate = red.rescates.size()
			_snapshot("despues_de_rescate")


func _evento(caja: RigidBody3D, nombre: String) -> void:
	print(
		"428_PILA_EVENTO ",
		nombre,
		" caja=",
		caja.name,
		" pose=",
		caja.global_transform,
		" apoyo_anotado=",
		caja.call("apoyo_que_dejo"),
		" sleeping=",
		caja.sleeping,
		" freeze=",
		caja.freeze,
		" layer=",
		caja.collision_layer
	)


func _empujada(caja: Node3D) -> void:
	_evento(caja as RigidBody3D, "empujada")


func _snapshot(etapa: String) -> void:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	print(
		"428_PILA_ETAPA ",
		etapa,
		" mira=",
		jugador.call("mira"),
		" cursor=",
		Input.mouse_mode,
		" mano=",
		almacen.get("_agarre").cuerpo_sostenido(),
		" rescates=",
		red.rescates.size()
	)
	for caja: RigidBody3D in pila:
		var q := PhysicsRayQueryParameters3D.create(
			caja.global_position, caja.global_position + Vector3.DOWN * 4.0, 9
		)
		q.exclude = [caja.get_rid(), jugador.get_rid()]
		var debajo := almacen.get_world_3d().direct_space_state.intersect_ray(q)
		print(
			"428_PILA_ESTADO ",
			etapa,
			" caja=",
			caja.name,
			" pose=",
			caja.global_transform,
			" apoyo_anotado=",
			caja.call("apoyo_que_dejo"),
			" sleeping=",
			caja.sleeping,
			" freeze=",
			caja.freeze,
			" layer=",
			caja.collision_layer,
			" debajo=",
			debajo
		)
