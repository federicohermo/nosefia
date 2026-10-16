extends SceneTree

var almacen: Node3D
var fallas: Array[String] = []


func _init() -> void:
	call_deferred("_medir")


func _bounds(caja: RigidBody3D) -> AABB:
	var f: CollisionShape3D = caja.get_node("Cuerpo")
	return f.global_transform * f.shape.get_debug_mesh().get_aabb()


func _medir() -> void:
	for producto: Producto.Id in [Producto.Id.LAYSNTT, Producto.Id.ACTRONCITO]:
		await _caso(producto)
	for cuadro in 8:
		await process_frame
	print("428_CASCADA_CONTROL_FIN fallas=", fallas)
	quit(0 if fallas.is_empty() else 1)


func _caso(producto: Producto.Id) -> void:
	almacen = load("res://src/escenas/almacen.tscn").instantiate()
	root.add_child(almacen)
	almacen.get_node("Interfaz/PersianaDeLaNoche").terminar()
	almacen.get("_reloj").set_process(false)
	for cuadro in 8:
		await physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.call("reanudar")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	for numero: int in [1, 2]:
		almacen.get_node("Estructura/bano_puerta_%d/CuerpoDeLaHoja" % numero).call("alternar")
	for cuadro in 45:
		await physics_frame
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[producto]
	var debajo: RigidBody3D = almacen.get("_cajas_de_productos")[Producto.Id.SALADIK]
	var ajena: RigidBody3D = almacen.get("_cajas_de_productos")[Producto.Id.OREMOS]
	var q := PhysicsRayQueryParameters3D.create(Vector3(4.49, 0.8, -10), Vector3(4.49, -1, -10), 9)
	var piso := almacen.get_world_3d().direct_space_state.intersect_ray(q)
	if piso.get("collider") != almacen.get_node("Estructura/SueloSolido"):
		fallas.append("No encuentra piso conocido")
		return
	var p: Vector3 = piso.position
	for cuerpo: RigidBody3D in [debajo, caja, ajena]:
		cuerpo.global_basis = Basis.IDENTITY
	debajo.global_position = p + Vector3.UP * _bounds(debajo).size.y / 2.0
	debajo.call("quedarse_quieta")
	caja.global_position = p + Vector3.UP * (_bounds(debajo).size.y + _bounds(caja).size.y / 2.0)
	caja.call("quedarse_quieta")
	ajena.global_position = p + Vector3.RIGHT * 2 + Vector3.UP * _bounds(ajena).size.y / 2.0
	ajena.call("quedarse_quieta")
	var inicial := caja.global_transform
	var aparte := ajena.global_transform
	for cuadro in 30:
		await physics_frame
	q.from = caja.global_position
	q.to = caja.global_position + Vector3.DOWN * 4.0
	q.exclude = [caja.get_rid(), jugador.get_rid()]
	var apoyo := almacen.get_world_3d().direct_space_state.intersect_ray(q)
	if apoyo.get("collider") != debajo:
		fallas.append("Pila no apoyada realmente")
	var limites := _bounds(debajo)
	var cara := limites.get_center() + Vector3.FORWARD * limites.size.z / 2.0
	cara.y = limites.position.y + limites.size.y / 4.0
	var alrededor := cara + Vector3.FORWARD * 1.2
	q.from = Vector3(alrededor.x, 0.8, alrededor.z)
	q.to = Vector3(alrededor.x, -1, alrededor.z)
	q.exclude = [jugador.get_rid(), debajo.get_rid()]
	piso = almacen.get_world_3d().direct_space_state.intersect_ray(q)
	if piso.get("collider") != almacen.get_node("Estructura/SueloSolido"):
		fallas.append("Parada sin suelo conocido")
		return
	jugador.global_position = piso.position + Vector3.UP * 0.005
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	var volumen := PhysicsShapeQueryParameters3D.new()
	volumen.shape = forma.shape
	volumen.transform = forma.global_transform
	volumen.collision_mask = jugador.collision_mask
	volumen.exclude = [jugador.get_rid(), debajo.get_rid()]
	volumen.margin = 0.0
	if not almacen.get_world_3d().direct_space_state.intersect_shape(volumen).is_empty():
		fallas.append("Capsula sin espacio libre")
	jugador.get_node("Giro").global_basis = Basis.looking_at(Vector3.BACK)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	camara.look_at(cara)
	for cuadro in 4:
		await physics_frame
	jugador.call("_leer_la_mira")
	if jugador.get("_enfocado") != debajo:
		fallas.append("Mira real no elige caja inferior")
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)
	if almacen.get("_agarre").cuerpo_sostenido() != debajo:
		fallas.append("No retira caja inferior")
	for cuadro in 180:
		await physics_frame
	q.from = caja.global_position
	q.to = caja.global_position + Vector3.DOWN * 4.0
	q.exclude = [caja.get_rid(), jugador.get_rid()]
	var final_apoyo := almacen.get_world_3d().direct_space_state.intersect_ray(q)
	var dibujo: MeshInstance3D = caja.get_node("Malla")
	var base_visual := (dibujo.global_transform * dibujo.get_aabb()).position.y
	var forma_del_piso: CollisionShape3D = final_apoyo.collider.shape_owner_get_owner(
		final_apoyo.collider.shape_find_owner(final_apoyo.shape)
	)
	var forma_caja: CollisionShape3D = caja.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	var reducida := BoxShape3D.new()
	reducida.size = (
		(forma_caja.shape as BoxShape3D).size * forma_caja.global_basis.get_scale()
		- (Vector3.ONE * ReglasDeLosObjetos.ROCE)
	)
	consulta.shape = reducida
	consulta.transform = Transform3D(caja.global_basis.orthonormalized(), caja.global_position)
	consulta.collision_mask = caja.collision_mask
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	consulta.margin = 0.0
	var intersecciones: Array[String] = []
	for resultado: Dictionary in almacen.get_world_3d().direct_space_state.intersect_shape(
		consulta
	):
		intersecciones.append(str(resultado.collider.get_path()))
	print(
		"428_CASCADA_SUPERFICIES producto=",
		producto,
		" base_visual=",
		base_visual,
		" base_fisica=",
		_bounds(caja).position.y,
		" piso_bounds=",
		forma_del_piso.global_transform * forma_del_piso.shape.get_debug_mesh().get_aabb(),
		" piso_shape=",
		forma_del_piso.shape.get_class(),
		" piso_margin=",
		forma_del_piso.shape.margin,
		" caja_margin=",
		forma_caja.shape.margin,
		" intersecciones_reducida=",
		intersecciones
	)
	print(
		"428_CASCADA_CONTROL producto=",
		producto,
		" inicial=",
		inicial,
		" base_inicial=",
		inicial.origin.y - _bounds(caja).size.y / 2.0,
		" apoyo_inicial=",
		apoyo,
		" final=",
		caja.global_transform,
		" bounds_final=",
		_bounds(caja),
		" piso=",
		p,
		" apoyo_final=",
		final_apoyo,
		" entra=",
		almacen.get("_reposicion_manual").call("_entra_entera", caja),
		" ajena_intacta=",
		ajena.global_transform.is_equal_approx(aparte),
		" congelada=",
		caja.freeze,
		" dormida=",
		caja.sleeping
	)
	# Cierre de fixture posterior a todas las lecturas: soltar referencias de la mano.
	almacen.get("_agarre").entregar()
	for audio: Node in almacen.find_children("*", "Node", true, false):
		if audio is AudioStreamPlayer or audio is AudioStreamPlayer3D:
			audio.call("stop")
			audio.set("stream", null)
	almacen.queue_free()
	almacen = null
	for cuadro in 4:
		await process_frame
