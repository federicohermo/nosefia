extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_el_agua_de_ambos_lavatorios_llega_hasta_la_pared_de_la_cubeta() -> void:
	var almacen: Node3D = await _almacen()
	for numero: int in [1, 2]:
		var nombre := "vanitory" if numero == 1 else "bano_lavatorio_2"
		var malla := almacen.get_node("Estructura/" + nombre) as MeshInstance3D
		var puesto := "AguaDelBano" if numero == 1 else "AguaDelBanoSegunda"
		var agua := almacen.get_node("Ambiente/" + puesto + "/Lavatorio") as MeshInstance3D
		var contorno: PackedVector2Array = almacen.get_node("Ambiente/" + puesto).get(
			"contorno_del_lavatorio"
		)
		var centro := agua.global_position
		for muestra in 16:
			var angulo := TAU * muestra / 16.0
			var hasta := centro + Vector3(cos(angulo), 0, sin(angulo))
			var cruces := _cruces(malla, centro, hasta)
			assert_array(cruces).override_failure_message(nombre).is_not_empty()
			if cruces.is_empty():
				continue
			var pared := INF
			for punto: Vector3 in cruces:
				pared = minf(pared, centro.distance_to(punto))
			var rayo := agua.to_local(hasta)
			var borde := INF
			for i in contorno.size():
				var corte: Variant = Geometry2D.segment_intersects_segment(
					Vector2.ZERO,
					Vector2(rayo.x, rayo.z),
					contorno[i],
					contorno[(i + 1) % contorno.size()]
				)
				if corte != null:
					var mundial := agua.to_global(Vector3(corte.x, 0, corte.y))
					borde = minf(borde, centro.distance_to(mundial))
			(
				assert_float(borde)
				. override_failure_message(
					"%s, rayo %d: agua %.6f, pared %.6f" % [nombre, muestra, borde, pared]
				)
				. is_between(pared - 0.0005, pared + 0.005)
			)


func test_los_volumenes_de_los_tanques_coinciden_con_sus_tapas_visibles() -> void:
	var almacen: Node3D = await _almacen()
	for nombre: String in ["inodoro", "bano_inodoro_2"]:
		var malla := almacen.get_node("Estructura/" + nombre) as MeshInstance3D
		var x := 10.94 if nombre == "inodoro" else 12.55
		var desde := Vector3(x, 1.4, 6.106)
		var hasta := desde - Vector3.UP
		var cruces := _cruces(malla, desde, hasta)
		assert_array(cruces).override_failure_message(nombre).is_not_empty()
		var consulta := PhysicsRayQueryParameters3D.create(desde, hasta, 1)
		var choque := almacen.get_world_3d().direct_space_state.intersect_ray(consulta)
		assert_object(choque.get("collider")).is_same(malla.get_node("StaticBody3D"))
		if cruces.is_empty() or choque.is_empty():
			continue
		var tapa := -INF
		for cruce: Vector3 in cruces:
			tapa = maxf(tapa, cruce.y)
		assert_float(choque.position.y).override_failure_message(nombre).is_equal_approx(
			tapa, 0.008
		)


func test_los_lavatorios_y_los_inodoros_tienen_porcelana_clara() -> void:
	var almacen: Node3D = await _almacen()
	for nombre: String in ["vanitory", "bano_lavatorio_2", "inodoro", "bano_inodoro_2"]:
		var malla := almacen.get_node("Estructura/" + nombre) as MeshInstance3D
		var porcelana: StandardMaterial3D = null
		for superficie in malla.mesh.get_surface_count():
			var material := malla.mesh.surface_get_material(superficie) as StandardMaterial3D
			if material != null and material.resource_name == "bano_porcelana":
				porcelana = material
		assert_object(porcelana).override_failure_message(nombre).is_not_null()
		if porcelana != null:
			assert_float(porcelana.albedo_color.r).is_greater(0.7)
			assert_float(porcelana.roughness).is_between(0.2, 0.4)


func test_el_piso_ampliado_forma_parte_de_la_misma_superficie_del_edificio() -> void:
	var almacen: Node3D = await _almacen()
	var edificio := almacen.get_node("Estructura/almacen") as MeshInstance3D
	for z: float in [-2.17, -3.48, -3.71, -4.33]:
		var cruces := _cruces(
			edificio, Vector3(10.17, 1.0, z + 7.556), Vector3(10.17, 0.0, z + 7.556)
		)
		assert_array(cruces).override_failure_message("piso en z=%s" % z).has_size(1)
		if cruces.size() == 1:
			assert_float(cruces[0].y).is_equal_approx(0.102237, 0.00001)


func test_las_paredes_del_bano_tienen_un_plano_continuo_hasta_el_dintel() -> void:
	var almacen: Node3D = await _almacen()
	var edificio := almacen.get_node("Estructura/almacen") as MeshInstance3D
	for muestra: Vector3 in [Vector3(11, 1.43, 5.386), Vector3(11, 3.02, 0.736)]:
		var hasta := Vector3(8.2, muestra.y, muestra.z)
		var cruces := _cruces(edificio, muestra, hasta)
		assert_array(cruces).has_size(1)
		if cruces.size() == 1:
			assert_float(cruces[0].x).is_equal_approx(8.29186, 0.0001)


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
		assert_float(luz.global_position.z).is_between(4.756, 5.756)
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
	var desde := Vector3(9.4, 1.413, 5.339)
	var hasta := Vector3(8.2, 1.413, 5.339)
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
		[Vector3(11, 1.5, 5.456), Vector3(8.2, 1.5, 5.456)],
		[Vector3(8.15, 1.5, 0.736), Vector3(8.15, 1.5, -0.244)],
		[Vector3(8.15, 1.5, 0.736), Vector3(8.15, 3.3, 0.736)],
	]:
		assert_str(_material_de_la_cara(edificio, recorrido[0], recorrido[1])).is_equal(
			"bano_pared_clara"
		)
	(
		assert_str(_material_de_la_cara(edificio, Vector3(8.15, 1, 0.736), Vector3(8.15, 0, 0.736)))
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
	var marco := almacen.get_node("Estructura/bano_marco_entrada") as MeshInstance3D
	# Estos rayos cruzan las bandas que antes dejaban visible la pared del almacén.
	for punto: Vector3 in [
		Vector3(7.70, 2.86461, 0.736),
		Vector3(7.70, 1.70, 1.58026),
		Vector3(7.70, 1.70, -0.10818),
	]:
		assert_str(_material_de_la_cara(marco, punto, punto + Vector3.RIGHT * 0.5)).is_equal(
			"bano_entrada_blanca"
		)


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
			Vector3(x, 1.4, 3.706), Vector3(x, 1.4, 5.106), 9
		)
		var espacio := almacen.get_world_3d().direct_space_state
		var cerrada := espacio.intersect_ray(consulta)
		assert_bool(cerrada.is_empty()).is_false()
		assert_object(cerrada.get("collider")).is_same(puerta)
		puerta.call("usar")
		for cuadro in 60:
			await get_tree().physics_frame
		assert_bool(espacio.intersect_ray(consulta).is_empty()).is_true()
		var jugador := almacen.get("_jugador") as CharacterBody3D
		jugador.global_position = Vector3(x, 0.12, 3.706)
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
	for punto: Vector3 in [Vector3(8.9, 0.12, 2.556), Vector3(10.8, 0.12, 1.156)]:
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
	jugador.global_position = Vector3(9.2, 0.12, 3.456)
	await get_tree().physics_frame
	var obstaculo := jugador.move_and_collide(Vector3(0.0, 0.0, 0.75), true)
	assert_object(obstaculo).is_null()
	var piso := PhysicsRayQueryParameters3D.create(
		Vector3(9.3, 0.4, 4.306), Vector3(9.3, -0.1, 4.306), 1
	)
	var apoyo := almacen.get_world_3d().direct_space_state.intersect_ray(piso)
	assert_bool(apoyo.is_empty()).is_false()
	assert_float((apoyo.get("position", Vector3.ZERO) as Vector3).y).is_equal_approx(
		0.102237, 0.005
	)


func test_la_puerta_del_bano_abierta_no_corta_el_recorrido_hacia_las_cabinas() -> void:
	var almacen: Node3D = await _almacen()
	almacen.get_node("Estructura/puerta2/CuerpoDeLaHoja").call("usar")
	for cuadro in 60:
		await get_tree().physics_frame
	var jugador := almacen.get("_jugador") as CharacterBody3D
	jugador.global_position = Vector3(7.3, 0.12, 0.736)
	await get_tree().physics_frame
	assert_object(jugador.move_and_collide(Vector3(3.6, 0.0, 0.0), true)).is_null()
	jugador.global_position = Vector3(10.9, 0.12, 0.736)
	await get_tree().physics_frame
	assert_object(jugador.move_and_collide(Vector3(0.0, 0.0, 2.8), true)).is_null()


func test_la_entrada_cerrada_no_deja_ver_el_bano_por_los_bordes_de_la_hoja() -> void:
	var almacen: Node3D = await _almacen()
	var puerta := almacen.get_node("Estructura/puerta2/CuerpoDeLaHoja")
	assert_bool(puerta.call("puerta").abierta()).is_false()
	var superficies: Array[MeshInstance3D] = []
	for nombre: String in ["puerta2", "bano_marco_entrada", "almacen"]:
		superficies.append(almacen.get_node("Estructura/" + nombre) as MeshInstance3D)
	# Los puntos cruzan las rendijas visibles entre hoja, marco y piso del vano real.
	for banda: Vector3 in [
		Vector3(7.974, 0.35, -0.0972),
		Vector3(7.974, 1.40, -0.0972),
		Vector3(7.974, 2.60, -0.0972),
		Vector3(7.974, 1.40, 1.5693),
		Vector3(7.974, 0.115, 1.356),
		Vector3(7.974, 0.115, 0.736),
		Vector3(7.974, 0.115, 0.156),
	]:
		for pendiente: float in [-0.15, 0.0, 0.15]:
			for lado: float in [-1.0, 1.0]:
				var direccion := Vector3(1.0, 0.0, pendiente) * lado
				var desde := banda - direccion * 0.5
				var hasta := banda + direccion * 0.5
				var bloqueado := false
				for superficie: MeshInstance3D in superficies:
					if not _cruces(superficie, desde, hasta).is_empty():
						bloqueado = true
						break
				(
					assert_bool(bloqueado)
					. override_failure_message(
						(
							"Vista sin bloquear en %s, pendiente %.2f, lado %.0f"
							% [banda, pendiente, lado]
						)
					)
					. is_true()
				)


func test_el_acabado_del_bano_no_sobresale_delante_de_la_hoja_cerrada() -> void:
	var almacen: Node3D = await _almacen()
	var puerta := almacen.get_node("Estructura/puerta2/CuerpoDeLaHoja")
	assert_bool(puerta.call("puerta").abierta()).is_false()
	var edificio := almacen.get_node("Estructura/almacen") as MeshInstance3D
	var hoja := almacen.get_node("Estructura/puerta2") as MeshInstance3D
	var referencia := _material_de_la_cara(
		edificio, Vector3(7.70, 0.25, 0.736), Vector3(7.70, 0.0, 0.736)
	)
	var interior := _material_de_la_cara(
		edificio, Vector3(8.08, 0.25, 0.736), Vector3(8.08, 0.0, 0.736)
	)
	assert_str(referencia).is_not_empty()
	assert_str(interior).is_not_empty().is_not_equal(referencia)
	# La franja delante de la hoja era visible aun con la puerta cerrada.
	for z: float in [-6.20, -6.82, -7.40]:
		var desde := Vector3(7.918, 0.25, z + 7.556)
		var hasta := Vector3(7.918, 0.0, z + 7.556)
		assert_array(_cruces(hoja, desde, hasta)).is_empty()
		(
			assert_str(_material_de_la_cara(edificio, desde, hasta))
			. override_failure_message(
				"El acabado exterior cambia delante de la puerta en z=%s" % z
			)
			. is_equal(referencia)
		)


func test_las_hojas_de_cabina_giran_unidas_a_un_soporte_fijo() -> void:
	var almacen: Node3D = await _almacen()
	var estructura := almacen.get_node("Estructura") as Node3D
	for numero: int in [1, 2]:
		var hoja := estructura.get_node("bano_puerta_%d" % numero) as MeshInstance3D
		var cuerpo := hoja.get_node("CuerpoDeLaHoja")
		var x := 11.455 if numero == 1 else 13.065
		var eje := Vector3(x, 1.25, 4.206)
		var ancla_local := hoja.to_local(eje)
		for altura: float in [0.59, 1.95]:
			var pasador := Vector3(x, altura, 4.206)
			(
				assert_float(_distancia_al_pasador_fijo(estructura, hoja, pasador))
				. override_failure_message("Falta soporte fijo junto al eje %s" % pasador)
				. is_less_equal(0.005)
			)
		cuerpo.call("usar")
		for cuadro in 60:
			await get_tree().physics_frame
		var estado := cuerpo.call("puerta") as Puerta
		assert_float(estado.angulo()).is_equal_approx(Puerta.ANGULO_ABIERTA, 0.001)
		assert_float(hoja.to_global(ancla_local).distance_to(eje)).is_less(0.0001)
		for altura: float in [0.59, 1.95]:
			var pasador := Vector3(x, altura, 4.206)
			assert_float(_distancia_al_pasador_fijo(estructura, hoja, pasador)).is_less_equal(0.005)


func _distancia_al_pasador_fijo(estructura: Node3D, hoja: MeshInstance3D, eje: Vector3) -> float:
	var distancia := INF
	var desde := eje + Vector3.FORWARD * 0.04
	var hasta := eje + Vector3.BACK * 0.04
	for hijo: Node in estructura.get_children():
		var malla := hijo as MeshInstance3D
		if malla == null or malla == hoja:
			continue
		for punto: Vector3 in _cruces(malla, desde, hasta):
			distancia = minf(distancia, eje.distance_to(punto))
	return distancia
