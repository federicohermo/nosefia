## Los apoyos reportados se ejercen con la mira y el gesto, conservando los sólidos del local.
extends GdUnitTestSuite


func test_la_caja_grande_soltada_mirando_el_gris_descansa_sobre_el_riel() -> void:  # AC-PLY-099
	var medicion := await _sobre_el_riel(Producto.Id.LAYSNTT)
	assert_float(medicion.base).is_equal_approx(medicion.gris, ReglasDeLosObjetos.ROCE)


func test_la_caja_chica_soltada_mirando_el_gris_descansa_sobre_el_riel() -> void:  # AC-PLY-099
	var medicion := await _sobre_el_riel(Producto.Id.ACTRONCITO)
	assert_float(medicion.base).is_equal_approx(medicion.gris, ReglasDeLosObjetos.ROCE)


func test_la_caja_grande_se_acomoda_sobre_metal_visible_de_la_cabecera() -> void:  # AC-PLY-100
	var medicion := await _en_la_cabecera(Producto.Id.LAYSNTT)
	assert_vector(medicion.final).is_equal_approx(medicion.inicial, ReglasDeLosObjetos.ROCE)
	assert_float(medicion.base).is_equal_approx(medicion.metal, ReglasDeLosObjetos.ROCE)


func test_la_caja_chica_se_acomoda_sobre_metal_visible_de_la_cabecera() -> void:  # AC-PLY-100
	var medicion := await _en_la_cabecera(Producto.Id.ACTRONCITO)
	assert_vector(medicion.final).is_equal_approx(medicion.inicial, ReglasDeLosObjetos.ROCE)
	assert_float(medicion.base).is_equal_approx(medicion.metal, ReglasDeLosObjetos.ROCE)


func test_cada_cara_superior_del_riel_visible_tiene_apoyo_fisico() -> void:  # AC-PLY-099
	var almacen := await _abrir()
	var riel: MeshInstance3D = almacen.get_node("Estructura/bano_riel_frontal")
	var superiores := _superiores(riel)
	assert_array(superiores).is_not_empty()
	for triangulo: PackedVector3Array in superiores:
		var punto := (triangulo[0] + triangulo[1] + triangulo[2]) / 3.0
		var golpe := _rayo(almacen, punto + Vector3.UP * 0.01, punto + Vector3.DOWN * 0.02)
		(
			assert_bool(golpe.is_empty())
			. override_failure_message("Riel sin apoyo en %v" % punto)
			. is_false()
		)
		if golpe.is_empty():
			continue
		assert_bool(riel.is_ancestor_of(golpe.collider)).is_true()
		assert_float((golpe.position as Vector3).y).is_equal_approx(
			punto.y, ReglasDeLosObjetos.ROCE
		)
		assert_float((golpe.normal as Vector3).y).is_greater_equal(
			ReglasDeLosObjetos.APOYO_HORIZONTAL
		)


func test_el_collider_del_riel_conserva_el_aire_entre_sus_brazos() -> void:
	var almacen := await _abrir()
	var riel: MeshInstance3D = almacen.get_node("Estructura/bano_riel_frontal")
	var superiores := _superiores(riel)
	assert_array(superiores).is_not_empty()
	var limites := riel.global_transform * riel.get_aabb()
	var probados := 0
	for fila in range(1, 10):
		for columna in range(1, 10):
			var punto := limites.position + limites.size * Vector3(fila / 10.0, 1.0, columna / 10.0)
			if not _impacto_visible(riel, punto + Vector3.UP, punto + Vector3.DOWN).is_empty():
				continue
			probados += 1
			var golpe := _rayo(almacen, punto + Vector3.UP * 0.01, punto + Vector3.DOWN * 0.02)
			(
				assert_bool(golpe.is_empty())
				. override_failure_message("Riel llena aire en %v" % punto)
				. is_true()
			)
	assert_int(probados).override_failure_message("No se ejerció ningún hueco del riel").is_greater(
		0
	)


func _sobre_el_riel(producto: Producto.Id) -> Dictionary:
	var almacen := await _abrir()
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[producto]
	var riel: MeshInstance3D = almacen.get_node("Estructura/bano_riel_frontal")
	var pared: MeshInstance3D = almacen.get_node("Estructura/bano_mampara_frontal")
	var blanco := pared.global_transform * pared.get_aabb()
	var objetivo := blanco.get_center()
	objetivo.x = blanco.position.x
	objetivo.y = (riel.global_transform * riel.get_aabb()).end.y
	var gris := _impacto_visible(riel, objetivo + Vector3.UP, objetivo + Vector3.DOWN)
	(
		assert_bool(gris.is_empty())
		. override_failure_message("Premisa: gris sobre división blanca")
		. is_false()
	)
	if gris.is_empty():
		return {"base": -INF, "gris": objetivo.y}
	objetivo = gris.punto
	await _mirar_desde_el_piso(almacen, caja, objetivo, Vector3.LEFT * 0.9)
	var mira: Transform3D = almacen.get("_jugador").call("mira")
	var visible := _impacto_visible(
		riel, mira.origin, mira.origin - mira.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA
	)
	(
		assert_bool(visible.is_empty())
		. override_failure_message("Premisa: la mira golpea el gris")
		. is_false()
	)
	if visible.is_empty():
		return {"base": -INF, "gris": objetivo.y}
	await _soltar_con_el_gesto(almacen, caja)
	var cuerpo: CollisionShape3D = caja.get_node("Cuerpo")
	var limites := cuerpo.global_transform * cuerpo.shape.get_debug_mesh().get_aabb()
	var dibujado: MeshInstance3D = caja.get_node("Malla")
	var dibujo := dibujado.global_transform * dibujado.get_aabb()
	assert_float(limites.position.y).is_equal_approx(dibujo.position.y, ReglasDeLosObjetos.ROCE)
	(
		assert_float(limites.position.y)
		. override_failure_message(
			"Base %v, riel visible %v, producto %s" % [limites.position, objetivo, producto]
		)
		. is_equal_approx(objetivo.y, ReglasDeLosObjetos.ROCE)
	)
	assert_bool(almacen.get("_reposicion_manual").call("_entra_entera", caja)).is_true()
	return {"base": limites.position.y, "gris": objetivo.y}


func _en_la_cabecera(producto: Producto.Id) -> Dictionary:
	var almacen := await _abrir()
	var antes := _estado_del_local(almacen)
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[producto]
	var gondola: MeshInstance3D = almacen.get_node("Estructura/gondolanueva2")
	var referencia: MeshInstance3D = gondola.get_node("saladix-2oeste2")
	var objetivo := referencia.global_position
	objetivo.y = (gondola.global_transform * gondola.get_aabb()).end.y - 0.03
	await _mirar_desde_el_piso(almacen, caja, objetivo, Vector3.FORWARD * 1.2)
	var mira: Transform3D = almacen.get("_jugador").call("mira")
	var visible := _impacto_visible(
		gondola, mira.origin, mira.origin - mira.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA
	)
	(
		assert_bool(visible.is_empty())
		. override_failure_message("Premisa: cabecera visible sobre Saladik")
		. is_false()
	)
	if visible.is_empty():
		return {"final": Vector3.INF, "inicial": Vector3.ZERO, "base": -INF, "metal": INF}
	var fisico := _rayo(
		almacen,
		mira.origin,
		mira.origin - mira.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA,
		[caja.get_rid(), almacen.get("_jugador").get_rid()]
	)
	assert_bool(fisico.is_empty()).is_false()
	if not fisico.is_empty():
		assert_vector(fisico.position).is_equal_approx(visible.punto, ReglasDeLosObjetos.ROCE)
	await _soltar_con_el_gesto(almacen, caja, 1)
	var inicial := caja.global_position
	for cuadro in 180:
		await get_tree().physics_frame
	var final := caja.global_position
	assert_vector(final).is_equal_approx(inicial, ReglasDeLosObjetos.ROCE)
	assert_bool(caja.freeze).is_true()
	assert_bool(caja.sleeping).is_true()
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var limites := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
	var metal := _impacto_visible(
		gondola, final, final + Vector3.DOWN * ReglasDeLosObjetos.CAIDA_HASTA_EL_PISO
	)
	(
		assert_bool(metal.is_empty())
		. override_failure_message("Premisa: metal bajo el centro")
		. is_false()
	)
	var contacto := _rayo(
		almacen,
		final,
		final + Vector3.DOWN * ReglasDeLosObjetos.CAIDA_HASTA_EL_PISO,
		[caja.get_rid(), almacen.get("_jugador").get_rid()]
	)
	assert_bool(contacto.is_empty()).is_false()
	if metal.is_empty() or contacto.is_empty():
		return {"final": final, "inicial": inicial, "base": limites.position.y, "metal": INF}
	assert_float(limites.position.y).is_equal_approx(
		(metal.punto as Vector3).y, ReglasDeLosObjetos.ROCE
	)
	assert_float((contacto.position as Vector3).y).is_equal_approx(
		(metal.punto as Vector3).y, ReglasDeLosObjetos.ROCE
	)
	assert_object(almacen.get("_agarre").manos().sostenido()).is_null()
	assert_bool(almacen.get("_reposicion_manual").call("_entra_entera", caja)).is_true()
	assert_dict(_estado_del_local(almacen)).is_equal(antes)
	await _mirar_desde_el_piso(almacen, caja, final, Vector3.FORWARD * 1.2)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.call("_leer_la_mira")
	assert_object(jugador.get("_enfocado")).is_same(caja)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)
	assert_object(almacen.get("_agarre").cuerpo_sostenido()).is_same(caja)
	assert_object(almacen.get("_agarre").manos().sostenido()).is_same(caja.get("datos"))
	assert_dict(_estado_del_local(almacen)).is_equal(antes)
	return {
		"final": final,
		"inicial": inicial,
		"base": limites.position.y,
		"metal": (metal.punto as Vector3).y
	}


func _estado_del_local(almacen: Node3D) -> Dictionary:
	var estante: Estante = almacen.get("_repositor").estante()
	var turno: Turno = almacen.get("_reloj").get("_turno")
	var cantidades: Dictionary = {}
	for producto: Producto in Catalogo.todos():
		cantidades[producto.id] = [
			estante.unidades_en_deposito(producto),
			estante.unidades_en_gondola(producto),
			estante.reservadas(producto),
			estante.casilleros_ocupados(producto).duplicate()
		]
	return {"cantidades": cantidades, "tareas": turno.tareas_cumplidas()}


func _abrir() -> Node3D:
	# Cargar dentro del caso evita retener el grafo del almacén durante el descubrimiento.
	var escena: PackedScene = load("res://src/escenas/almacen.tscn")
	var almacen: Node3D = auto_free(escena.instantiate())
	add_child(almacen)
	almacen.get_node("Interfaz/PersianaDeLaNoche").terminar()
	almacen.get("_reloj").set_process(false)
	for cuadro in 8:
		await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.call("reanudar")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	for numero: int in [1, 2]:
		almacen.get_node("Estructura/bano_puerta_%d/CuerpoDeLaHoja" % numero).call("alternar")
	for cuadro in 45:
		await get_tree().physics_frame
	return almacen


func _mirar_desde_el_piso(
	almacen: Node3D, caja: RigidBody3D, objetivo: Vector3, desplazamiento: Vector3
) -> void:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var alrededor := objetivo + desplazamiento
	var piso := _rayo(
		almacen,
		Vector3(alrededor.x, 0.8, alrededor.z),
		Vector3(alrededor.x, -1, alrededor.z),
		[jugador.get_rid(), caja.get_rid()]
	)
	assert_bool(piso.is_empty()).override_failure_message("Premisa: piso transitable").is_false()
	if piso.is_empty():
		return
	assert_object(piso.collider).is_same(almacen.get_node("Estructura/SueloSolido"))
	jugador.global_position = piso.position + Vector3.UP * 0.005
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = jugador.global_transform * forma.transform
	consulta.collision_mask = jugador.collision_mask
	consulta.exclude = [jugador.get_rid(), caja.get_rid()]
	consulta.margin = 0.0
	assert_array(almacen.get_world_3d().direct_space_state.intersect_shape(consulta)).is_empty()
	var giro: Node3D = jugador.get_node("Giro")
	giro.global_basis = Basis.looking_at(
		Vector3(objetivo.x - alrededor.x, 0, objetivo.z - alrededor.z)
	)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	camara.look_at(objetivo)
	jugador.reset_physics_interpolation()
	camara.reset_physics_interpolation()
	for cuadro in 4:
		await get_tree().physics_frame


func _soltar_con_el_gesto(almacen: Node3D, caja: RigidBody3D, cuadros := 12) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	var jugador: CharacterBody3D = almacen.get("_jugador")
	assert_bool(agarre.pedir_agarrar(caja.get("datos"), caja)).is_true()
	for cuadro in 8:
		jugador.call("_acomodar_las_manos", 1.0 / 60.0)
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)
	for cuadro in cuadros:
		await get_tree().physics_frame
	assert_object(agarre.manos().sostenido()).is_null()


func _rayo(almacen: Node3D, desde: Vector3, hasta: Vector3, excluir: Array[RID] = []) -> Dictionary:
	var consulta := PhysicsRayQueryParameters3D.create(
		desde, hasta, 1 | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
	)
	consulta.exclude = excluir
	return almacen.get_world_3d().direct_space_state.intersect_ray(consulta)


func _impacto_visible(malla: MeshInstance3D, desde: Vector3, hasta: Vector3) -> Dictionary:
	var caras := malla.mesh.get_faces()
	var direccion := desde.direction_to(hasta)
	var distancia := desde.distance_to(hasta)
	var salida: Dictionary = {}
	for indice in range(0, caras.size(), 3):
		var a := malla.to_global(caras[indice])
		var b := malla.to_global(caras[indice + 1])
		var c := malla.to_global(caras[indice + 2])
		var punto: Variant = Geometry3D.ray_intersects_triangle(desde, direccion, a, b, c)
		if punto == null or desde.distance_to(punto) > distancia:
			continue
		distancia = desde.distance_to(punto)
		salida = {"punto": punto, "triangulo": indice / 3, "distancia": distancia}
	return salida


func _superiores(malla: MeshInstance3D) -> Array[PackedVector3Array]:
	var caras := malla.mesh.get_faces()
	var tope := (malla.global_transform * malla.get_aabb()).end.y
	var salida: Array[PackedVector3Array] = []
	for indice in range(0, caras.size(), 3):
		var a := malla.to_global(caras[indice])
		var b := malla.to_global(caras[indice + 1])
		var c := malla.to_global(caras[indice + 2])
		if absf(a.y - tope) < 0.0001 and absf(b.y - tope) < 0.0001 and absf(c.y - tope) < 0.0001:
			salida.append(PackedVector3Array([a, b, c]))
	return salida
