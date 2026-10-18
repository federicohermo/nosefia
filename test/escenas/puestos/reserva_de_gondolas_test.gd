## El espacio comercial se conserva sin crear un soporte invisible bajo las cajas.
extends GdUnitTestSuite


func test_las_unidades_soltadas_hacia_las_tres_gondolas_quedan_afuera() -> void:  # AC-PLY-018
	var almacen := await _abrir()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	var reservados: Array[PhysicsBody3D] = almacen.get("_muebles_con_contorno")
	assert_int(reservados.size()).is_equal(3)
	for cuerpo: PhysicsBody3D in reservados:
		var malla := cuerpo.get_parent() as MeshInstance3D
		var mueble := malla.global_transform * malla.get_aabb()
		var centro := mueble.get_center()
		var hacia := (
			Vector3.FORWARD if str(malla.name).begins_with("gondolanueva_001") else Vector3.RIGHT
		)
		var pies := centro - hacia * (mueble.size.dot(hacia.abs()) / 2.0 + 0.8)
		var suelo := PhysicsRayQueryParameters3D.create(
			Vector3(pies.x, 0.8, pies.z), Vector3(pies.x, -1, pies.z), jugador.collision_mask
		)
		suelo.exclude = [jugador.get_rid()]
		var piso := almacen.get_world_3d().direct_space_state.intersect_ray(suelo)
		assert_object(piso.get("collider")).is_same(almacen.get_node("Estructura/SueloSolido"))
		if piso.is_empty():
			return
		pies.y = (piso.position as Vector3).y + ReglasDeLosObjetos.ROCE
		jugador.global_position = pies
		# La góndola norte se aborda por la cabecera; apuntar al piso acorta
		# la proyección horizontal de la mano y no entra en su reserva.
		var alto := centro.y if hacia == Vector3.FORWARD else 0.5
		await _mirar(jugador, Vector3(centro.x, alto, centro.z))
		var capsula: CollisionShape3D = jugador.get_node("Cuerpo")
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = capsula.shape
		consulta.transform = capsula.global_transform
		consulta.collision_mask = jugador.collision_mask
		consulta.exclude = [jugador.get_rid()]
		consulta.margin = 0.0
		assert_array(almacen.get_world_3d().direct_space_state.intersect_shape(consulta)).is_empty()
		puesto.call("retirar", Producto.Id.MALBARDO)
		var unidad := agarre.cuerpo_sostenido() as RigidBody3D
		assert_object(unidad).is_not_null()
		if unidad == null:
			return
		var datos: UnidadDeProducto = unidad.get("datos")
		var inventario := _inventario(almacen)
		var antes := _estado(almacen, datos.producto)
		assert_bool(inventario.esta_afuera(datos)).is_true()
		print(
			"RESERVA_428_PREMISA mueble=",
			malla.name,
			" volumen=",
			mueble,
			" mano=",
			agarre.punto_de_soltado.global_position,
			" mira=",
			jugador.call("mira")
		)
		assert_bool(mueble.has_point(agarre.punto_de_soltado.global_position)).is_true()
		agarre.soltar(true)
		for cuadro in 90:
			await get_tree().physics_frame
		print(
			"RESERVA_428_RECOGIDA mueble=",
			malla.get_path(),
			" pies=",
			pies,
			" unidad=",
			unidad.global_transform
		)
		assert_bool(mueble.grow(-0.03).has_point(unidad.global_position)).is_false()
		assert_dict(_estado(almacen, datos.producto)).is_equal(antes)
		assert_bool(inventario.esta_afuera(datos)).is_true()
		await _recoger(almacen, unidad)
		assert_object(agarre.cuerpo_sostenido()).is_same(unidad)
		assert_object(agarre.manos().sostenido()).is_same(datos)
		puesto.call("devolver", datos.producto.id)
		assert_object(agarre.manos().sostenido()).is_null()


func test_una_unidad_exterior_oblicua_no_se_retrocede_por_su_aabb() -> void:  # AC-PLY-018
	var almacen := await _abrir()
	var puesto: Node3D = almacen.get("_reposicion_manual")
	puesto.call("retirar", Producto.Id.MALBARDO)
	var agarre: Agarre = almacen.get("_agarre")
	var unidad := agarre.soltar(false) as RigidBody3D
	assert_object(unidad).is_not_null()
	if unidad == null:
		return
	unidad.freeze = true
	var mueble: MeshInstance3D = almacen.get_node("Estructura/gondolanueva")
	var limites := mueble.get_aabb()
	var forma: CollisionShape3D = unidad.get_node("Forma")
	var volumen := LimitesDeForma.de(forma.shape)
	var giro := Basis(Vector3.UP, PI / 4.0)
	var envuelta := Transform3D(giro, Vector3.ZERO) * volumen
	var afuera := minf(envuelta.size.x, envuelta.size.z) * 0.4
	var centro := Vector3(limites.end.x + afuera, limites.get_center().y, limites.end.z + afuera)
	unidad.global_transform = mueble.global_transform * Transform3D(giro, centro)
	var local := mueble.global_transform.affine_inverse() * forma.global_transform * volumen
	assert_bool(local.intersects(limites)).is_true()
	assert_bool(_libre(almacen, unidad)).is_true()
	(
		assert_bool(
			ReservaDeLaGondola.se_superponen(
				volumen, forma.global_transform, limites, mueble.global_transform
			)
		)
		. is_false()
	)
	var antes := unidad.global_transform
	puesto.call("_desatascar_lo_soltado", unidad)
	assert_vector(unidad.global_position).is_equal(antes.origin)


func test_la_reserva_no_se_extiende_al_interior_de_la_heladera() -> void:  # AC-PLY-024
	var almacen := await _abrir()
	var puesto: Node3D = almacen.get("_reposicion_manual")
	puesto.call("retirar", Producto.Id.MALBARDO)
	var unidad := almacen.get("_agarre").soltar(false) as RigidBody3D
	assert_object(unidad).is_not_null()
	if unidad == null:
		return
	unidad.freeze = true
	var heladera: MeshInstance3D = almacen.get_node("Estructura/heladeranueva")
	var zona: AABB = puesto.call("zona", Producto.Id.PURA_COLA)
	unidad.global_basis = Basis.IDENTITY
	unidad.global_position = zona.get_center()
	(
		assert_bool(
			(heladera.global_transform * heladera.get_aabb()).has_point(unidad.global_position)
		)
		. is_true()
	)
	assert_bool(_libre(almacen, unidad)).is_true()
	var antes := unidad.global_position
	puesto.call("_desatascar_lo_soltado", unidad)
	assert_vector(unidad.global_position).is_equal(antes)


func _abrir() -> Node3D:
	var escena: PackedScene = load("res://src/escenas/almacen.tscn")
	var almacen: Node3D = auto_free(escena.instantiate())
	add_child(almacen)
	almacen.get_node("Interfaz/PersianaDeLaNoche").terminar()
	almacen.get("_reloj").set_process(false)
	var apertura: Script = load("res://test/escenas/apertura_con_lugar.gd")
	apertura.abrir_con_todo_el_lugar(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.call("reanudar")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	for cuadro in 8:
		await get_tree().physics_frame
	return almacen


func _mirar(jugador: CharacterBody3D, punto: Vector3) -> void:
	var hacia := punto - jugador.global_position
	jugador.get_node("Giro").global_basis = Basis.looking_at(Vector3(hacia.x, 0, hacia.z))
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	camara.look_at(punto)
	jugador.reset_physics_interpolation()
	camara.reset_physics_interpolation()
	for cuadro in 4:
		await get_tree().physics_frame


func _recoger(almacen: Node3D, unidad: RigidBody3D) -> void:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var lugar: Variant = _lugar_para_mirar(almacen, unidad)
	(
		assert_bool(lugar is Dictionary)
		. override_failure_message("Premisa: recogida desde piso libre")
		. is_true()
	)
	if not lugar is Dictionary:
		return
	jugador.global_position = lugar.pies
	await _mirar(jugador, lugar.objetivo)
	jugador.call("_leer_la_mira")
	assert_object(jugador.get("_enfocado")).is_same(unidad)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _lugar_para_mirar(almacen: Node3D, unidad: RigidBody3D) -> Variant:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	var espacio := almacen.get_world_3d().direct_space_state
	var campo: Area3D = jugador.get("_campo")
	var descartes: Array[Dictionary] = []
	var forma_unidad: CollisionShape3D = unidad.get_node("Forma")
	var convexo := forma_unidad.shape as ConvexPolygonShape3D
	var centro := Vector3.ZERO
	for vertice: Vector3 in convexo.points:
		centro += vertice
	centro = forma_unidad.global_transform * (centro / convexo.points.size())
	var limites := forma_unidad.global_transform * LimitesDeForma.de(forma_unidad.shape)
	var objetivos: Array[Vector3] = [centro]
	for direccion: Vector3 in [
		Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK
	]:
		objetivos.append(limites.get_center() + direccion * limites.size / 2.0)
	for radio: float in [0.6, 0.9, 1.2]:
		for lado in ReglasDeLosObjetos.LADOS_ALREDEDOR:
			var direccion := Basis(Vector3.UP, TAU * lado / ReglasDeLosObjetos.LADOS_ALREDEDOR)
			var punto := unidad.global_position + direccion * Vector3.FORWARD * radio
			var rayo := PhysicsRayQueryParameters3D.create(
				Vector3(punto.x, 0.8, punto.z),
				Vector3(punto.x, -1, punto.z),
				jugador.collision_mask
			)
			rayo.exclude = [jugador.get_rid()]
			var piso := espacio.intersect_ray(rayo)
			if piso.get("collider") != almacen.get_node("Estructura/SueloSolido"):
				descartes.append({"fase": "piso", "punto": punto})
				continue
			var pies: Vector3 = piso.position + Vector3.UP * ReglasDeLosObjetos.ROCE
			var consulta := PhysicsShapeQueryParameters3D.new()
			consulta.shape = forma.shape
			consulta.transform = Transform3D(jugador.global_basis, pies) * forma.transform
			consulta.collision_mask = jugador.collision_mask
			consulta.exclude = [jugador.get_rid()]
			var choques := espacio.intersect_shape(consulta, 1)
			if not choques.is_empty():
				descartes.append({"fase": "capsula", "pies": pies})
				continue
			rayo.from = pies + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
			rayo.collision_mask = campo.collision_mask
			for objetivo: Vector3 in objetivos:
				rayo.to = objetivo
				var golpe := espacio.intersect_ray(rayo)
				if golpe.get("collider") == unidad:
					return {"pies": pies, "objetivo": objetivo}
				descartes.append(
					{
						"fase": "mira",
						"pies": pies,
						"objetivo": objetivo,
						"collider": str(golpe.get("collider")),
						"position": golpe.get("position")
					}
				)
	print(
		"RESERVA_428_RECOGIDA_DESCARTES unidad=",
		unidad.global_transform,
		" forma=",
		forma_unidad.global_transform,
		" centro_convexo=",
		centro,
		" limites=",
		limites,
		" datos=",
		descartes
	)
	return null


func _inventario(almacen: Node3D) -> Inventario:
	var estante: Estante = almacen.get("_repositor").estante()
	return estante.get("_inventario")


func _libre(almacen: Node3D, unidad: RigidBody3D) -> bool:
	var forma: CollisionShape3D = unidad.get_node("Forma")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = forma.global_transform
	consulta.collision_mask = unidad.collision_mask | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
	consulta.exclude = [unidad.get_rid(), almacen.get("_jugador").get_rid()]
	return almacen.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _estado(almacen: Node3D, producto: Producto) -> Dictionary:
	var estante: Estante = almacen.get("_repositor").estante()
	var turno: Turno = almacen.get("_reloj").get("_turno")
	return {
		"deposito": estante.unidades_en_deposito(producto),
		"gondola": estante.unidades_en_gondola(producto),
		"reservadas": estante.reservadas(producto),
		"tareas": turno.tareas_cumplidas(),
		"casilleros": estante.casilleros_ocupados(producto).duplicate()
	}
