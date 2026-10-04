extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_el_piso_ampliado_forma_parte_de_la_misma_superficie_del_edificio() -> void:
	var almacen: Node3D = await _almacen()
	var edificio := almacen.get_node("Estructura/almacen") as MeshInstance3D
	for z: float in [-2.17, -3.48, -3.71, -4.33]:
		var cruces := _cruces(edificio, Vector3(10.17, 1.0, z), Vector3(10.17, 0.0, z))
		assert_array(cruces).override_failure_message("piso en z=%s" % z).has_size(1)
		if cruces.size() == 1:
			assert_float(cruces[0].y).is_equal_approx(0.102237, 0.00001)
	assert_object(almacen.get_node_or_null("Estructura/bano_piso_ampliado")).is_null()


func test_las_paredes_del_bano_tienen_un_plano_continuo_hasta_el_dintel() -> void:
	var almacen: Node3D = await _almacen()
	var edificio := almacen.get_node("Estructura/almacen") as MeshInstance3D
	for muestra: Vector3 in [Vector3(11, 1.43, -2.17), Vector3(11, 3.02, -6.82)]:
		var hasta := muestra + Vector3.LEFT * 3.05
		var cruces := _cruces(edificio, muestra, hasta)
		assert_array(cruces).has_size(1)
		if cruces.size() == 1:
			assert_float(cruces[0].x).is_equal_approx(8.29186, 0.0001)
	for nombre: String in ["bano_revestimiento_oeste", "bano_revestimiento_ampliado"]:
		assert_object(almacen.get_node_or_null("Estructura/" + nombre)).is_null()


func _cruces(malla: MeshInstance3D, desde: Vector3, hasta: Vector3) -> Array[Vector3]:
	var caras := malla.mesh.get_faces()
	var cruces: Array[Vector3] = []
	for indice in range(0, caras.size(), 3):
		var cruce: Variant = Geometry3D.segment_intersects_triangle(
			desde,
			hasta,
			malla.global_transform * caras[indice],
			malla.global_transform * caras[indice + 1],
			malla.global_transform * caras[indice + 2]
		)
		if cruce != null:
			cruces.append(cruce)
	return cruces


func test_cada_cabina_tiene_una_luminaria_encima_del_inodoro() -> void:
	var almacen: Node3D = await _almacen()
	for numero: int in [7, 8]:
		var luz := almacen.get_node("Ambiente/LuzDelBano%d" % numero) as SpotLight3D
		var x := 10.945 if numero == 7 else 12.555
		assert_float(luz.global_position.x).is_equal_approx(x, 0.01)
		assert_float(luz.global_position.z).is_between(-2.8, -1.8)
		assert_float(luz.light_energy).is_greater(0.0)


func test_los_lavatorios_dejan_espacio_entre_sus_bordes() -> void:
	var almacen: Node3D = await _almacen()
	var primero := almacen.get_node("Estructura/vanitory") as MeshInstance3D
	var segundo := almacen.get_node("Estructura/bano_lavatorio_2") as MeshInstance3D
	var caja_primera := primero.global_transform * primero.get_aabb()
	var caja_segunda := segundo.global_transform * segundo.get_aabb()
	assert_float(caja_primera.position.z - caja_segunda.end.z).is_greater(0.35)
	var agua := almacen.get_node("Ambiente/AguaDelBano/Lavatorio") as Node3D
	assert_float(agua.global_position.z).is_between(caja_primera.position.z, caja_primera.end.z)


func test_la_pared_del_sector_ampliado_no_tiene_caras_superpuestas() -> void:
	var almacen: Node3D = await _almacen()
	var edificio := almacen.get_node("Estructura/almacen") as MeshInstance3D
	var desde := Vector3(9.4, 1.413, -2.217)
	var hasta := Vector3(7.95, 1.413, -2.217)
	var caras := edificio.mesh.get_faces()
	var cruces: Array[Vector3] = []
	for indice in range(0, caras.size(), 3):
		var cruce: Variant = Geometry3D.segment_intersects_triangle(
			desde,
			hasta,
			edificio.global_transform * caras[indice],
			edificio.global_transform * caras[indice + 1],
			edificio.global_transform * caras[indice + 2]
		)
		if cruce != null:
			cruces.append(cruce)
	assert_array(cruces).has_size(1)


func test_la_pared_ampliada_y_el_hueco_tienen_el_acabado_del_bano() -> void:
	var almacen: Node3D = await _almacen()
	var edificio := almacen.get_node("Estructura/almacen") as MeshInstance3D
	for recorrido: Array in [
		[Vector3(11, 1.5, -2.1), Vector3(7.8, 1.5, -2.1)],
		[Vector3(8.15, 1.5, -6.82), Vector3(8.15, 1.5, -7.8)],
		[Vector3(8.15, 1.5, -6.82), Vector3(8.15, 3.3, -6.82)],
	]:
		assert_str(_material_de_la_cara(edificio, recorrido[0], recorrido[1])).is_equal(
			"bano_pared_clara"
		)
	(
		assert_str(_material_de_la_cara(edificio, Vector3(8.15, 1, -6.82), Vector3(8.15, 0, -6.82)))
		. is_equal("bano_piso_gris")
	)


func _material_de_la_cara(malla: MeshInstance3D, desde: Vector3, hasta: Vector3) -> String:
	var distancia := INF
	var nombre := ""
	for superficie in malla.mesh.get_surface_count():
		var datos := malla.mesh.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = datos[Mesh.ARRAY_INDEX]
		var cantidad := vertices.size() if indices.is_empty() else indices.size()
		for indice in range(0, cantidad, 3):
			var puntos: Array[Vector3] = []
			for desplazamiento in 3:
				var vertice := indice + desplazamiento
				if not indices.is_empty():
					vertice = indices[vertice]
				puntos.append(malla.global_transform * vertices[vertice])
			var cruce: Variant = Geometry3D.segment_intersects_triangle(
				desde, hasta, puntos[0], puntos[1], puntos[2]
			)
			if cruce != null and desde.distance_to(cruce) < distancia:
				distancia = desde.distance_to(cruce)
				nombre = malla.get_active_material(superficie).resource_name
	return nombre


func test_la_entrada_conserva_la_escala_de_las_otras_puertas_y_un_marco_continuo() -> void:
	var almacen: Node3D = await _almacen()
	var entrada := almacen.get_node("Estructura/puerta2") as MeshInstance3D
	var otra := almacen.get_node("Estructura/puerta") as MeshInstance3D
	var altura := (entrada.global_transform * entrada.get_aabb()).size.y
	var referencia := (otra.global_transform * otra.get_aabb()).size.y
	assert_float(altura / referencia).is_between(0.92, 1.08)
	assert_array(entrada.find_children("*", "MeshInstance3D", true, false)).is_empty()
	assert_object(almacen.get_node_or_null("Estructura/bano_marco_entrada")).is_not_null()
	assert_object(almacen.get_node_or_null("Estructura/bano_marco_entrada_001")).is_null()
	assert_object(almacen.get_node_or_null("Estructura/bano_muro_entrada")).is_null()


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	return almacen


func test_las_cabinas_tienen_puertas_que_liberan_el_acceso_al_abrirse() -> void:
	var almacen: Node3D = await _almacen()
	for numero: int in [1, 2]:
		var ruta := "Estructura/bano_puerta_%d/CuerpoDeLaHoja" % numero
		var puerta := almacen.get_node_or_null(ruta) as PhysicsBody3D
		assert_object(puerta).override_failure_message(ruta).is_not_null()
		if puerta == null:
			continue
		var x := 10.945 if numero == 1 else 12.555
		var consulta := PhysicsRayQueryParameters3D.create(
			Vector3(x, 1.4, -3.85), Vector3(x, 1.4, -2.45), 9
		)
		var espacio := almacen.get_world_3d().direct_space_state
		var cerrada := espacio.intersect_ray(consulta)
		assert_bool(cerrada.is_empty()).is_false()
		assert_object(cerrada.get("collider")).is_same(puerta)
		puerta.call("interactuar")
		for cuadro in 60:
			await get_tree().physics_frame
		assert_bool(espacio.intersect_ray(consulta).is_empty()).is_true()
		var jugador := almacen.get("_jugador") as CharacterBody3D
		jugador.global_position = Vector3(x, 0.12, -3.85)
		await get_tree().physics_frame
		assert_object(jugador.move_and_collide(Vector3(0.0, 0.0, 1.1), true)).is_null()
		var puertas: Array = almacen.get("_puertas")
		assert_bool(puertas.has(puerta)).is_true()
		almacen.get("_ciclo").abrir_la_jornada()
		await get_tree().physics_frame
		assert_bool(puerta.call("puerta").abierta()).is_false()


func test_el_sector_abierto_deja_lugar_para_caminar_y_llevar_el_balde() -> void:
	var almacen: Node3D = await _almacen()
	var jugador := almacen.get("_jugador") as CharacterBody3D
	var forma := jugador.get_node("Cuerpo") as CollisionShape3D
	var espacio := almacen.get_world_3d().direct_space_state
	for punto: Vector3 in [Vector3(8.9, 0.12, -5.0), Vector3(10.8, 0.12, -6.4)]:
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = Transform3D(Basis.IDENTITY, punto) * forma.transform
		consulta.collision_mask = jugador.collision_mask
		consulta.exclude = [jugador.get_rid()]
		(
			assert_array(espacio.intersect_shape(consulta))
			. override_failure_message(str(punto))
			. is_empty()
		)


func test_los_dos_inodoros_y_lavatorios_se_pueden_usar_para_la_limpieza() -> void:
	var almacen: Node3D = await _almacen()
	for nombre: String in ["inodoro", "bano_inodoro_2", "vanitory", "bano_lavatorio_2"]:
		var artefacto := almacen.get_node_or_null("Estructura/" + nombre + "/StaticBody3D")
		assert_object(artefacto).override_failure_message(nombre).is_not_null()
		if artefacto == null:
			continue
		assert_bool(artefacto.is_in_group("interactuable")).is_true()
		var destino: StringName = artefacto.call("destino_del_uso")
		var esperado: StringName = &"inodoro" if "inodoro" in nombre else &"lavatorio"
		assert_that(destino).is_equal(esperado)


func test_el_sector_antes_cerrado_es_accesible_desde_el_bano() -> void:
	var almacen: Node3D = await _almacen()
	var jugador := almacen.get("_jugador") as CharacterBody3D
	jugador.global_position = Vector3(9.2, 0.12, -4.1)
	await get_tree().physics_frame
	var obstaculo := jugador.move_and_collide(Vector3(0.0, 0.0, 0.75), true)
	assert_object(obstaculo).is_null()
	var piso := PhysicsRayQueryParameters3D.create(
		Vector3(9.3, 0.4, -3.25), Vector3(9.3, -0.1, -3.25), 1
	)
	var apoyo := almacen.get_world_3d().direct_space_state.intersect_ray(piso)
	assert_bool(apoyo.is_empty()).is_false()
	assert_float((apoyo.get("position", Vector3.ZERO) as Vector3).y).is_equal_approx(
		0.102237, 0.005
	)


func test_la_puerta_del_bano_abierta_no_corta_el_recorrido_hacia_las_cabinas() -> void:
	var almacen: Node3D = await _almacen()
	almacen.get_node("Estructura/puerta2/CuerpoDeLaHoja").call("interactuar")
	for cuadro in 60:
		await get_tree().physics_frame
	var jugador := almacen.get("_jugador") as CharacterBody3D
	jugador.global_position = Vector3(7.3, 0.12, -6.82)
	await get_tree().physics_frame
	assert_object(jugador.move_and_collide(Vector3(3.6, 0.0, 0.0), true)).is_null()
	jugador.global_position = Vector3(10.9, 0.12, -6.82)
	await get_tree().physics_frame
	assert_object(jugador.move_and_collide(Vector3(0.0, 0.0, 2.8), true)).is_null()
