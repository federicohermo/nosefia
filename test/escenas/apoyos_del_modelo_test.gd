extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Cada cuánto se baja un rayo sobre el tablero de un pallet, en metros: menos que una ranura.
const PASO_SOBRE_EL_TABLERO := 0.002


func test_cada_mancha_se_enfoca_desde_un_apoyo_caminable_a_un_metro() -> void:
	var almacen := await _abrir()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	for mancha: Node3D in almacen.get("_limpieza").manchas():
		var encontrada := false
		for direccion: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var pie := mancha.global_position + direccion
			# Hasta un metro abajo del piso y no de la mancha: la del moho está en una pared.
			var apoyo := _rayo(jugador, pie + Vector3.UP, Vector3(pie.x, -1.0, pie.z))
			if apoyo.is_empty():
				continue
			if not _es_piso(almacen, apoyo.collider) or apoyo.normal.y < 0.9:
				continue
			pie.y = apoyo.position.y + 0.01
			var consulta := PhysicsShapeQueryParameters3D.new()
			consulta.shape = forma.shape
			consulta.collision_mask = jugador.collision_mask
			consulta.transform = Transform3D(Basis.IDENTITY, pie + forma.position)
			consulta.exclude = [jugador.get_rid()]
			if not jugador.get_world_3d().direct_space_state.intersect_shape(consulta).is_empty():
				continue
			jugador.global_position = pie
			jugador.velocity = Vector3.ZERO
			camara.look_at(mancha.global_position + Vector3.UP * 0.03)
			for cuadro in 4:
				await get_tree().physics_frame
			if jugador.get("_enfocado") == mancha:
				encontrada = true
				break
		assert_bool(encontrada).override_failure_message(str(mancha.name)).is_true()


func test_los_objetos_y_manchas_quedan_sobre_el_modelo() -> void:
	var almacen := await _abrir()
	var objetos: Array[Node] = almacen.get_node("Objetos").get_children()
	var manchas: Array = almacen.get("_limpieza").manchas()
	objetos.append_array(manchas)
	for objeto: Node3D in objetos:
		# Cada cosa se apoya hacia su propio abajo: la mancha de la pared, contra la pared.
		var abajo := Vector3.DOWN
		if objeto is StaticBody3D and objeto in manchas:
			abajo = -objeto.global_basis.y.normalized()
		for malla: MeshInstance3D in objeto.find_children("*", "MeshInstance3D", true, false):
			if not malla.is_visible_in_tree():
				continue
			var limites := malla.global_transform * malla.get_aabb()
			var medio := (limites.size * abajo.abs()).length() / 2.0
			var pie := limites.get_center() + abajo * medio
			var apoyo := _rayo(objeto, pie - abajo * 0.1, pie + abajo)
			assert_bool(apoyo.is_empty()).override_failure_message(str(objeto.name)).is_false()
			if not apoyo.is_empty():
				# **No todo se apoya en la malla del edificio desde el 043.** Ese spec mandó
				# las cajas de reposición al depósito, donde el apoyo es `SueloSolido` y no el
				# modelo. Acá se cuida que el apoyo sea del escenario; que no flote ni se hunda
				# lo mide el hueco de abajo.
				var sostiene := str(almacen.get_path_to(apoyo.collider))
				(
					assert_bool(sostiene.begins_with("Estructura/"))
					. override_failure_message("%s se apoya en `%s`" % [objeto.name, sostiene])
					. is_true()
				)
				var hueco: float = (apoyo.position - pie).dot(abajo)
				(
					assert_float(hueco)
					. override_failure_message(
						"%s: base %v, apoyo %v" % [objeto.name, pie, apoyo.position]
					)
					. is_between(-0.01, 0.06)
				)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	assert_bool(jugador.is_on_floor()).is_true()
	var piso := _rayo(
		jugador, jugador.global_position + Vector3.UP * 0.1, jugador.global_position + Vector3.DOWN
	)
	assert_bool(piso.is_empty()).is_false()
	if not piso.is_empty():
		# El motor mantiene un margen de contacto entre la cápsula y el piso.
		assert_float(jugador.global_position.y - piso.position.y).is_between(-0.01, 0.06)


func test_las_manchas_superan_el_alcance_entre_si() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	var manchas: Array = almacen.get("_limpieza").manchas()
	for indice in manchas.size():
		for otra in range(indice + 1, manchas.size()):
			var a: Vector3 = manchas[indice].position
			var b: Vector3 = manchas[otra].position
			assert_float(Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))).is_greater(
				ReglasDelJugador.ALCANCE_DE_LA_MIRA
			)


func test_el_tablero_de_cada_pallet_no_deja_pasar_un_rayo() -> void:
	# Quien busca un apoyo baja un rayo. Por la ranura entre dos tablas el rayo cruzaba el pallet
	# y daba con lo de abajo: la caja apuntada a un estante terminaba al lado del jugador.
	var almacen := await _abrir()
	var espacio := almacen.get_world_3d().direct_space_state
	var pallets := almacen.get_node("Estructura").find_children(
		"deposito_pallet_*", "MeshInstance3D", true, false
	)
	assert_array(pallets).is_not_empty()
	for pallet: MeshInstance3D in pallets:
		var cuerpo: StaticBody3D = pallet.get_node("StaticBody3D")
		var limites := pallet.get_aabb()
		var ranuras: Array[String] = []
		for eje: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
			var largo := (limites.size * eje).length()
			var recorrido := PASO_SOBRE_EL_TABLERO
			while recorrido < largo:
				var tapa := limites.get_center() + eje * (recorrido - largo / 2.0)
				tapa.y = limites.end.y
				var arriba := pallet.to_global(tapa)
				var consulta := PhysicsRayQueryParameters3D.create(
					arriba + Vector3.UP * 0.01,
					arriba + Vector3.DOWN * limites.size.y,
					cuerpo.collision_layer
				)
				var golpe := espacio.intersect_ray(consulta)
				if (
					golpe.get("collider") != cuerpo
					or absf((golpe["position"] as Vector3).y - arriba.y) > 0.001
				):
					ranuras.append("%v" % tapa)
				recorrido += PASO_SOBRE_EL_TABLERO
		(
			assert_array(ranuras)
			. override_failure_message(
				"`%s` deja pasar el rayo en %s" % [pallet.name, ", ".join(ranuras)]
			)
			. is_empty()
		)


func _abrir() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	for numero: int in [1, 2]:
		almacen.get_node("Estructura/bano_puerta_%d/CuerpoDeLaHoja" % numero).call("usar")
	for cuadro in 60:
		await get_tree().physics_frame
	return almacen


## Si lo que el rayo tocó es piso donde se camina: el del edificio, o el volumen sólido que lo
## dobla por debajo.
func _es_piso(almacen: Node3D, cuerpo: Object) -> bool:
	return (
		cuerpo == almacen.get_node("Estructura/almacen/StaticBody3D")
		or cuerpo == almacen.get_node("Estructura/SueloSolido")
		or cuerpo == almacen.get_node("Estructura/almacen/Volumen")
	)


func _rayo(objeto: Node3D, desde: Vector3, hasta: Vector3) -> Dictionary:
	# Los discos de interacción de las manchas no son apoyos físicos del jugador.
	var consulta := PhysicsRayQueryParameters3D.create(
		desde, hasta, 1 | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
	)
	if objeto is CollisionObject3D:
		consulta.exclude = [objeto.get_rid()]
	return objeto.get_world_3d().direct_space_state.intersect_ray(consulta)
