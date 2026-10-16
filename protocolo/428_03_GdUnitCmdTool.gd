## Observa el runner real y el fixture heredado; no escribe poses, estados ni entradas.
extends "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"

var candidatas: Array[WeakRef] = []
var pila: Array[WeakRef] = []
var mundo: WeakRef
var anterior := ""


func _initialize() -> void:
	node_added.connect(_al_agregar)
	physics_frame.connect(_cuadro)
	super._initialize()


func _al_agregar(nodo: Node) -> void:
	if nodo is RigidBody3D and nodo.get_script() != null:
		var ruta: String = nodo.get_script().resource_path
		if ruta == "res://src/escenas/objetos/caja_de_productos.gd":
			_observar.call_deferred(weakref(nodo))


func _observar(referencia: WeakRef) -> void:
	var caja := referencia.get_ref() as RigidBody3D
	if caja == null:
		return
	for previa: WeakRef in candidatas:
		if previa.get_ref() == caja:
			return
	candidatas.append(referencia)
	caja.sleeping_state_changed.connect(_senal.bind(referencia, "reposo"))
	caja.connect(ReglasDeLosObjetos.SENAL_EMPUJADA, _empujada)


func _empujada(caja: Node3D) -> void:
	_senal(weakref(caja), "empujada_despues_de_lectores")


func _senal(referencia: WeakRef, nombre: String) -> void:
	var caja := referencia.get_ref() as RigidBody3D
	if caja == null or pila.is_empty():
		return
	for elegida: WeakRef in pila:
		if elegida.get_ref() == caja:
			_snapshot(nombre + ":" + str(caja.name))
			return


func _cuadro() -> void:
	if mundo != null and mundo.get_ref() == null:
		pila.clear()
		mundo = null
		anterior = ""
	if pila.is_empty():
		var elegibles: Array[WeakRef] = []
		for referencia: WeakRef in candidatas:
			var caja := referencia.get_ref() as RigidBody3D
			if caja == null or not caja.is_inside_tree():
				continue
			var p := caja.global_position
			if absf(p.x - 4.49) < 0.001 and absf(p.z + 10.0) < 0.001 and p.y < 3.0:
				elegibles.append(referencia)
		if elegibles.size() == 5:
			var almacen := _almacen_de(elegibles[0].get_ref() as Node3D)
			if almacen == null or not almacen.get("_jugador") is CharacterBody3D:
				return
			pila = elegibles
			mundo = weakref(almacen)
			_snapshot("pila_cinco_armada")
		return
	_snapshot("antes_physics_process")


func _almacen_de(nodo: Node3D) -> Node3D:
	var actual: Node = nodo
	while actual != null:
		var script: Script = actual.get_script()
		if script != null and script.resource_path == "res://src/escenas/almacen.gd":
			return actual as Node3D
		actual = actual.get_parent()
	return null


func _vector(v: Vector3) -> Array[float]:
	return [v.x, v.y, v.z]


func _snapshot(etapa: String) -> void:
	var almacen := mundo.get_ref() as Node3D
	if almacen == null or not almacen.is_inside_tree():
		return
	var jugador := almacen.get("_jugador") as CharacterBody3D
	if not is_instance_valid(jugador) or not jugador.is_inside_tree():
		return
	var agarre := almacen.get("_agarre") as Agarre
	if not is_instance_valid(agarre) or not agarre.is_inside_tree():
		return
	var estados: Array[Dictionary] = []
	for referencia: WeakRef in pila:
		var caja := referencia.get_ref() as RigidBody3D
		if caja == null or not caja.is_inside_tree():
			continue
		var apoyo: Vector3 = caja.call("apoyo_que_dejo")
		var forma: CollisionShape3D = caja.get_node("Cuerpo")
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		var media := (forma.shape as BoxShape3D).size * forma.scale / 2.0
		consulta.transform = Transform3D(
			Basis.IDENTITY.scaled(forma.scale), apoyo + Vector3.UP * media.y * 2.0
		)
		consulta.exclude = [caja.get_rid(), jugador.get_rid()]
		var encima: Array[Dictionary] = []
		for hit: Dictionary in almacen.get_world_3d().direct_space_state.intersect_shape(
			consulta, 8
		):
			var otro := hit.collider as RigidBody3D
			encima.append(
				{
					"nombre": str(hit.collider.name),
					"freeze": otro.freeze if otro != null else null,
					"sleeping": otro.sleeping if otro != null else null
				}
			)
		estados.append(
			{
				"nombre": str(caja.name),
				"posicion": _vector(caja.global_position),
				"apoyo": _vector(apoyo),
				"parent": str(caja.get_parent().get_path()),
				"freeze": caja.freeze,
				"sleeping": caja.sleeping,
				"velocidad": _vector(caja.linear_velocity),
				"query_pose": str(consulta.transform),
				"query_encima": encima
			}
		)
	var resumen := JSON.stringify(estados)
	if resumen == anterior and etapa == "antes_physics_process":
		return
	anterior = resumen
	print(
		"428_RUNNER_PILA ",
		JSON.stringify(
			{
				"etapa": etapa,
				"physics_frame": Engine.get_physics_frames(),
				"estados": estados,
				"time_scale": Engine.time_scale,
				"max_fps": Engine.max_fps,
				"mano": str(agarre.cuerpo_sostenido())
			}
		)
	)
