## La boca queda libre y las paredes frenan el paso; soltar por la boca no cuenta como tiro.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const TapaDelLocal := preload("res://src/escenas/puestos/tapa_del_contenedor.gd")
const BASE_DEL_CONTENEDOR := "Estructura/deposito_contenedor_soporte/"
const RUTA_DE_LA_TAPA := BASE_DEL_CONTENEDOR + "deposito_contenedor_bisagra_tapa/CuerpoDeLaTapa"
const OBJETO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")


func test_la_boca_abierta_no_tiene_una_tapa_de_colision_invisible() -> void:
	var almacen := await _abrir()
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_cuerpo/StaticBody3D"
	)
	for offset: Vector3 in [Vector3.ZERO, Vector3(-0.15, 0, 0.15), Vector3(0.15, 0, -0.15)]:
		var centro := contenedor.global_position + offset
		var golpe := _rayo(almacen, centro + Vector3.UP * 1.3, centro)
		assert_bool(golpe.is_empty()).is_false()
		if golpe.is_empty():
			continue
		assert_str(str(almacen.get_path_to(golpe.collider))).contains("deposito_contenedor")
		# Un único casco convexo cerraría la boca a un metro; el fondo está a unos 13 cm.
		assert_float(golpe.position.y - contenedor.global_position.y).is_between(0.12, 0.14)
		assert_float(golpe.normal.y).is_greater(0.99)


func test_el_cuerpo_del_contenedor_frena_un_rayo_desde_el_pasillo() -> void:
	var almacen := await _abrir()
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_cuerpo/StaticBody3D"
	)
	var centro := contenedor.global_position + Vector3.UP * 0.65
	var golpe := _rayo(almacen, centro + Vector3.BACK, centro)
	assert_bool(golpe.is_empty()).is_false()
	if golpe.is_empty():
		return
	assert_str(str(almacen.get_path_to(golpe.collider))).contains("deposito_contenedor")
	assert_float(golpe.position.z - centro.z).is_between(0.3, 0.36)
	assert_float(golpe.normal.z).is_greater(0.98)


func test_una_bolsa_soltada_por_la_boca_se_recoge_y_se_tira_despues() -> void:  # AC-CLN-009
	var almacen := await _abrir()
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_cuerpo/StaticBody3D"
	)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	jugador.global_position = contenedor.global_position + Vector3.BACK
	var bolsa: ObjetoAgarrable = almacen.get_node("Objetos/BolsaDeBasura1")
	var datos := bolsa.datos
	var agarre: Agarre = jugador.get("agarre")
	assert_bool(agarre.pedir_agarrar(datos, bolsa)).is_true()
	agarre.punto_de_soltado.global_position = contenedor.global_position + Vector3.UP * 1.2
	assert_object(agarre.soltar(true)).is_same(bolsa)
	for cuadro in 10:
		await get_tree().physics_frame
	var recolector: RecolectorDeBasura = almacen.get_node("Servicios/Recolector")
	assert_bool(recolector.tarea().esta_depositada(datos.id)).is_false()
	assert_int(recolector.tarea().depositadas()).is_zero()
	assert_bool(agarre.pedir_agarrar(datos, bolsa)).is_true()
	jugador.set("_enfocado", contenedor)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	jugador.call("_unhandled_input", clic)
	assert_bool(recolector.tarea().esta_depositada(datos.id)).is_true()
	assert_object(agarre.manos().sostenido()).is_null()


func _abrir() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return almacen


func test_cerrar_tapa_bloquea_la_boca_y_abrir_la_deja_libre() -> void:  # AC-CLN-034
	var almacen := await _abrir()
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_cuerpo/StaticBody3D"
	)
	var bisagra := tapa.bisagra.global_position
	assert_bool(tapa.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	assert_array(tapa.mallas).has_size(1)
	assert_object(tapa.call("interactuar")).is_null()
	tapa.usar()
	await _terminar_el_giro(tapa)
	var centro := contenedor.global_position
	var golpe := _rayo(almacen, centro + Vector3.UP * 1.3, centro)
	assert_bool(golpe.is_empty()).is_false()
	if not golpe.is_empty():
		assert_object(golpe.collider).is_same(tapa)
		assert_float(golpe.position.y - centro.y).is_between(1.08, 1.11)
	assert_bool(tapa.call("recibe_objetos")).is_false()
	assert_vector(tapa.bisagra.global_position).is_equal_approx(bisagra, Vector3.ONE * 0.00001)
	tapa.usar()
	await _terminar_el_giro(tapa)
	golpe = _rayo(almacen, centro + Vector3.UP * 1.3, centro)
	assert_bool(golpe.is_empty()).is_false()
	if not golpe.is_empty():
		assert_float(golpe.position.y - centro.y).is_between(0.12, 0.14)
	assert_bool(tapa.call("recibe_objetos")).is_true()
	assert_vector(tapa.bisagra.global_position).is_equal_approx(bisagra, Vector3.ONE * 0.00001)


func test_clic_derecho_sobre_el_cuerpo_tambien_alterna_la_tapa() -> void:  # AC-CLN-034
	var almacen := await _abrir()
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_cuerpo/StaticBody3D"
	)
	var centro := contenedor.global_position + Vector3.UP * 0.65
	var golpe := _rayo(almacen, centro + Vector3.BACK, centro)
	assert_bool(golpe.is_empty()).is_false()
	if golpe.is_empty():
		return
	var cuerpo: StaticBody3D = golpe.collider
	assert_str(str(almacen.get_path_to(cuerpo))).contains("deposito_contenedor_cuerpo")
	assert_bool(cuerpo.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	assert_bool(cuerpo.has_method(ReglasDeLosObjetos.METODO_USAR)).is_true()
	assert_object(cuerpo.call(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_null()
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	jugador.set("_enfocado", cuerpo)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_RIGHT
	clic.pressed = true
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	jugador.call("_unhandled_input", clic)
	await _terminar_el_giro(tapa)
	assert_bool(tapa.call("recibe_objetos")).is_false()
	golpe = _rayo(
		almacen, contenedor.global_position + Vector3.UP * 1.3, contenedor.global_position
	)
	assert_object(golpe.get("collider")).is_same(tapa)
	jugador.call("_unhandled_input", clic)
	await _terminar_el_giro(tapa)
	assert_bool(tapa.call("recibe_objetos")).is_true()


func test_bolsa_con_tapa_cerrada_se_conserva_hasta_el_clic_abierta() -> void:  # AC-CLN-035
	var almacen := await _abrir()
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	tapa.usar()
	await _terminar_el_giro(tapa)
	var bolsa: ObjetoAgarrable = almacen.get_node("Objetos/BolsaDeBasura1")
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(bolsa.datos, bolsa)).is_true()
	tapa.interactuar()
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	tapa.usar()
	await _terminar_el_giro(tapa)
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_zero()
	tapa.interactuar()
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_equal(1)


func test_reiniciar_restaura_tapa_abierta() -> void:  # AC-CLN-034
	var almacen := await _abrir()
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	var abierta := tapa.bisagra.global_transform
	tapa.usar()
	await _terminar_el_giro(tapa)
	almacen.call("_al_abrir_la_jornada", 2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_cuerpo/StaticBody3D"
	)
	assert_bool(tapa.call("recibe_objetos")).is_true()
	assert_vector(tapa.bisagra.global_position).is_equal_approx(
		abierta.origin, Vector3.ONE * 0.00001
	)
	assert_vector(tapa.bisagra.global_basis.z).is_equal_approx(
		abierta.basis.z, Vector3.ONE * 0.00001
	)


func test_la_tapa_se_detiene_ante_un_objeto_y_continua_cuando_se_retira() -> void:  # AC-CLN-034
	var almacen := await _abrir()
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_cuerpo/StaticBody3D"
	)
	var obstaculo: ObjetoAgarrable = OBJETO.instantiate()
	obstaculo.freeze = true
	almacen.add_child(obstaculo)
	obstaculo.global_position = contenedor.global_position + Vector3.UP * 1.10
	await get_tree().physics_frame
	await get_tree().physics_frame
	tapa.usar()
	for cuadro in 60:
		await get_tree().physics_frame
	var estado: TapaDelContenedor = tapa.get("_tapa")
	var detenida := estado.angulo()
	assert_float(detenida).is_between(0.05, TapaDelContenedor.ANGULO_ABIERTA - 0.05)
	var consulta := PhysicsShapeQueryParameters3D.new()
	var forma: CollisionShape3D = tapa.get_node("Volumen")
	consulta.shape = forma.shape
	consulta.transform = forma.global_transform
	consulta.exclude = [tapa.get_rid()]
	for choque in almacen.get_world_3d().direct_space_state.intersect_shape(consulta, 32):
		assert_object(choque.collider).is_not_same(obstaculo)
	for cuadro in 15:
		await get_tree().physics_frame
	assert_float(estado.angulo()).is_equal(detenida)
	obstaculo.queue_free()
	for cuadro in 60:
		await get_tree().physics_frame
	assert_float(estado.angulo()).is_equal(0.0)
	assert_bool(tapa.call("recibe_objetos")).is_false()
	tapa.usar()
	for cuadro in 60:
		await get_tree().physics_frame
	assert_float(estado.angulo()).is_equal(TapaDelContenedor.ANGULO_ABIERTA)
	assert_bool(tapa.call("recibe_objetos")).is_true()


func test_las_paredes_contienen_la_tolerancia_de_penetracion_del_motor() -> void:
	var almacen := await _abrir()
	var soporte: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_cuerpo/StaticBody3D"
	)
	var tolerancia: float = ProjectSettings.get_setting(
		"physics/jolt_physics_3d/simulation/penetration_slop"
	)
	for alto: float in [0.2, 0.45, 0.65, 0.9]:
		for lado: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var centro := soporte.global_position + Vector3.UP * alto
			var afuera := centro + lado * 0.6
			var interior := _rayo(almacen, centro, afuera)
			var exterior := _rayo(almacen, afuera, centro)
			assert_object(interior.get("collider")).is_same(soporte)
			assert_object(exterior.get("collider")).is_same(soporte)
			if interior.is_empty() or exterior.is_empty():
				continue
			var espesor: float = interior.position.distance_to(exterior.position)
			assert_float(espesor).is_greater(tolerancia * 2.0)


func test_llenarlo_con_productos_no_los_comprime_a_traves_del_cuerpo_o_la_tapa() -> void:
	var almacen := await _abrir()
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)
	jugador.global_position = Vector3(3.0, 0.103, -13.75)
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_cuerpo/StaticBody3D"
	)
	var centro := contenedor.global_position
	var camara: Camera3D = jugador.get("_camara")
	camara.look_at(centro + Vector3.UP * 0.8)
	var unidades: Array[ObjetoAgarrable] = []
	var boca := _boca_interior(almacen, contenedor)
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	assert_bool(tapa.recibe_objetos()).is_true()
	assert_float(tapa.get("_tapa").angulo()).is_equal_approx(
		TapaDelContenedor.ANGULO_ABIERTA, 0.00001
	)
	var agarre: Agarre = almacen.get("_agarre")
	for indice in 28:
		var producto: Producto = Catalogo.todos()[indice % Catalogo.todos().size()]
		almacen.get("_reposicion_manual").call("retirar", producto.id)
		agarre.punto_de_soltado.global_position = (
			centro + Vector3((indice % 3 - 1) * 0.07, 1.35, (indice % 2 - 0.5) * 0.07)
		)
		var unidad := agarre.soltar(true) as ObjetoAgarrable
		assert_object(unidad).is_not_null()
		if unidad != null:
			_dejar_caer_en_la_boca(almacen, contenedor, unidad, unidades, boca, indice)
			unidades.append(unidad)
		for cuadro in 35:
			await get_tree().physics_frame
	for cuadro in 120:
		await get_tree().physics_frame
	var dentro := 0
	for unidad in unidades:
		var desde := unidad.global_position - centro
		if absf(desde.x) < 0.34 and absf(desde.z) < 0.38 and desde.y < 1.1:
			dentro += 1
	assert_int(dentro).override_failure_message("la carga no llegó al tacho").is_greater(6)
	tapa.usar()
	for cuadro in 120:
		await get_tree().physics_frame
	var estado: TapaDelContenedor = tapa.get("_tapa")
	assert_float(estado.angulo()).is_greater(0.0)
	var soporte: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_cuerpo/StaticBody3D"
	)
	var espacio := almacen.get_world_3d().direct_space_state
	for unidad in unidades:
		var forma: CollisionShape3D = unidad.get_node("Forma")
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.exclude = [unidad.get_rid()]
		var otros: Array[RID] = [unidad.get_rid()]
		for choque in espacio.intersect_shape(consulta, 64):
			assert_object(choque.collider).is_not_same(tapa)
			if choque.collider != soporte:
				otros.append(choque.rid)
		consulta.exclude = otros
		var contactos := espacio.collide_shape(consulta, 64)
		for indice in range(0, contactos.size() - 1, 2):
			# La protección interior mide 4 cm; nunca debe atravesarse hasta la cara visible.
			var profundidad := contactos[indice].distance_to(contactos[indice + 1])
			assert_float(profundidad).is_less(0.04)


func _terminar_el_giro(tapa: TapaDelLocal) -> void:
	tapa.set_physics_process(false)
	tapa.call("_physics_process", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _rayo(almacen: Node3D, desde: Vector3, hasta: Vector3) -> Dictionary:
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
	return almacen.get_world_3d().direct_space_state.intersect_ray(consulta)


func test_el_contenedor_fijo_conserva_los_viajes_del_local_y_las_bolsas() -> void:  # AC-CLN-008
	var almacen := await _abrir()
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_cuerpo/StaticBody3D"
	)
	var piso: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Fondo")
	var forma := piso.shape as BoxShape3D
	var punto := piso.to_local(contenedor.global_position)
	(
		assert_bool(AABB(-forma.size / 2.0, forma.size).has_point(Vector3(punto.x, 0, punto.z)))
		. is_true()
	)
	assert_object(contenedor.call("interactuar")).is_null()
	var puntos: Array[Node3D] = []
	for ruta: String in [
		"Estructura/gondolanueva/StaticBody3D",
		"Estructura/Ventanilla",
		"Estructura/base compu/StaticBody3D"
	]:
		puntos.append(almacen.get_node(ruta))
	puntos.append_array(almacen.get("_bolsas"))
	for mancha: Node in almacen.find_children("Mancha*", "Node3D", true, false):
		puntos.append(mancha as Node3D)
	assert_int(puntos.size()).is_equal(3 + ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA + 4)
	for nodo in puntos:
		assert_float(nodo.global_position.distance_to(contenedor.global_position)).is_greater_equal(
			ReglasDeLaBasura.DISTANCIA_MINIMA_AL_CONTENEDOR
		)


func _limites_fisicos(unidad: ObjetoAgarrable) -> AABB:
	var forma: CollisionShape3D = unidad.get_node("Forma")
	return forma.global_transform * forma.shape.get_debug_mesh().get_aabb()


func _boca_interior(almacen: Node3D, contenedor: StaticBody3D) -> AABB:
	var malla := contenedor.get_parent() as MeshInstance3D
	var borde: AABB = malla.global_transform * malla.get_aabb()
	var centro := Vector3(
		contenedor.global_position.x,
		borde.end.y - 2.0 * ReglasDeLosObjetos.ROCE,
		contenedor.global_position.z
	)
	var limites: Array[Vector3] = []
	for direccion: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var golpe := _rayo(almacen, centro, centro + direccion * borde.size.length())
		assert_object(golpe.get("collider")).is_same(contenedor)
		limites.append(golpe.position)
	var minimo := Vector3(limites[0].x, borde.position.y, limites[2].z)
	var maximo := Vector3(limites[1].x, borde.end.y, limites[3].z)
	return AABB(minimo, maximo - minimo)


func _dejar_caer_en_la_boca(
	almacen: Node3D,
	contenedor: StaticBody3D,
	unidad: ObjetoAgarrable,
	cargadas: Array[ObjetoAgarrable],
	boca: AABB,
	indice: int
) -> void:
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	var limites_tapa: AABB = (
		tapa.forma.global_transform * tapa.forma.shape.get_debug_mesh().get_aabb()
	)
	var apoyo := boca.end.y
	for anterior: ObjetoAgarrable in cargadas:
		apoyo = maxf(apoyo, _limites_fisicos(anterior).end.y)
	var limites := _limites_fisicos(unidad)
	var base := limites.position - unidad.global_position
	var fin := limites.end - unidad.global_position
	var desde := boca.position - base + Vector3.ONE * ReglasDeLosObjetos.ROCE
	var hasta := boca.end - fin - Vector3.ONE * ReglasDeLosObjetos.ROCE
	var altura := apoyo - base.y + 2.0 * ReglasDeLosObjetos.ROCE
	var forma: CollisionShape3D = unidad.get_node("Forma")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.collision_mask = unidad.collision_mask
	consulta.exclude = [unidad.get_rid()]
	var espacio := almacen.get_world_3d().direct_space_state
	var encontrada := false
	# Recorre primero el centro y alterna dentro de la boca erosionada por la forma real.
	for fraccion_z: float in [0.5, 0.75, 1.0, 0.25, 0.0]:
		for fraccion_x: float in [0.5, 0.25, 0.75, 0.0, 1.0]:
			var destino := Vector3(
				lerpf(desde.x, hasta.x, fraccion_x), altura, lerpf(desde.z, hasta.z, fraccion_z)
			)
			consulta.transform = forma.global_transform
			consulta.transform.origin += destino - unidad.global_position
			consulta.motion = Vector3.ZERO
			if not espacio.intersect_shape(consulta, 32).is_empty():
				continue
			consulta.motion = (
				Vector3.DOWN * maxf(0.0, altura + base.y - apoyo - ReglasDeLosObjetos.ROCE)
			)
			var recorrido := espacio.cast_motion(consulta)
			if recorrido[0] < 1.0:
				continue
			unidad.global_position = destino
			encontrada = true
			break
		if encontrada:
			break
	(
		assert_bool(encontrada)
		. override_failure_message("no hay caída libre por la boca para esta forma")
		. is_true()
	)
	assert_float(hasta.x - desde.x).is_greater(0.0)
	assert_float(hasta.z - desde.z).is_greater(0.0)
	unidad.linear_velocity = Vector3.ZERO
	unidad.angular_velocity = Vector3.ZERO
	unidad.reset_physics_interpolation()
	consulta.transform = forma.global_transform
	consulta.motion = Vector3.ZERO
	assert_array(espacio.intersect_shape(consulta, 32)).is_empty()
	assert_bool(unidad.freeze).is_false()
	assert_float(unidad.gravity_scale).is_greater(0.0)
	assert_int(unidad.collision_layer).is_not_equal(0)
	assert_int(unidad.collision_mask).is_not_equal(0)
