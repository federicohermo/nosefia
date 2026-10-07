## La boca permite entrar hasta el fondo; las paredes frenan el paso y el descarte sigue activo.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const TapaDelLocal := preload("res://src/escenas/puestos/tapa_del_contenedor.gd")
const BASE_DEL_CONTENEDOR := "Estructura/deposito_contenedor_soporte/"
const RUTA_DE_LA_TAPA := BASE_DEL_CONTENEDOR + "deposito_contenedor_bisagra_tapa/CuerpoDeLaTapa"
const OBJETO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")


func test_la_boca_abierta_no_tiene_una_tapa_de_colision_invisible() -> void:
	var almacen := await _abrir()
	var zona: Area3D = almacen.get_node("Objetos/ZonaDeDescarte")
	for offset: Vector3 in [Vector3.ZERO, Vector3(-0.15, 0, 0.15), Vector3(0.15, 0, -0.15)]:
		var centro := zona.global_position + offset
		var golpe := _rayo(almacen, centro + Vector3.UP * 1.3, centro)
		assert_bool(golpe.is_empty()).is_false()
		if golpe.is_empty():
			continue
		assert_str(str(almacen.get_path_to(golpe.collider))).contains("deposito_contenedor")
		# Un único casco convexo cerraría la boca a un metro; el fondo está a unos 13 cm.
		assert_float(golpe.position.y - zona.global_position.y).is_between(0.12, 0.14)
		assert_float(golpe.normal.y).is_greater(0.99)


func test_el_cuerpo_del_contenedor_frena_un_rayo_desde_el_pasillo() -> void:
	var almacen := await _abrir()
	var zona: Area3D = almacen.get_node("Objetos/ZonaDeDescarte")
	var centro := zona.global_position + Vector3.UP * 0.65
	var golpe := _rayo(almacen, centro + Vector3.BACK, centro)
	assert_bool(golpe.is_empty()).is_false()
	if golpe.is_empty():
		return
	assert_str(str(almacen.get_path_to(golpe.collider))).contains("deposito_contenedor")
	assert_float(golpe.position.z - centro.z).is_between(0.3, 0.36)
	assert_float(golpe.normal.z).is_greater(0.98)


func test_una_bolsa_soltada_por_la_boca_llega_al_recolector() -> void:
	var almacen := await _abrir()
	var zona: Area3D = almacen.get_node("Objetos/ZonaDeDescarte")
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	jugador.global_position = zona.global_position + Vector3.BACK
	var bolsa: ObjetoAgarrable = almacen.get_node("Objetos/BolsaDeBasura1")
	var datos := bolsa.datos
	var agarre: Agarre = jugador.get("agarre")
	assert_bool(agarre.pedir_agarrar(datos, bolsa)).is_true()
	agarre.punto_de_soltado.global_position = zona.global_position + Vector3.UP * 1.2
	assert_object(agarre.soltar(true)).is_same(bolsa)
	for cuadro in 10:
		await get_tree().physics_frame
	var recolector: RecolectorDeBasura = almacen.get_node("Servicios/Recolector")
	assert_bool(recolector.tarea().esta_depositada(datos.id)).is_true()
	assert_int(recolector.tarea().depositadas()).is_equal(1)


func _abrir() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return almacen


func test_cerrar_tapa_bloquea_la_boca_y_abrir_la_deja_libre() -> void:  # AC-CLN-034
	var almacen := await _abrir()
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	var zona: Area3D = almacen.get_node("Objetos/ZonaDeDescarte")
	var bisagra := tapa.bisagra.global_position
	assert_bool(tapa.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	assert_array(tapa.mallas).has_size(1)
	assert_bool(tapa.has_method("interactuar")).is_false()
	tapa.usar()
	await _terminar_el_giro(tapa)
	var centro := zona.global_position
	var golpe := _rayo(almacen, centro + Vector3.UP * 1.3, centro)
	assert_bool(golpe.is_empty()).is_false()
	if not golpe.is_empty():
		assert_object(golpe.collider).is_same(tapa)
		assert_float(golpe.position.y - centro.y).is_between(1.08, 1.11)
	assert_bool(zona.monitoring).is_false()
	assert_vector(tapa.bisagra.global_position).is_equal_approx(bisagra, Vector3.ONE * 0.00001)
	tapa.usar()
	await _terminar_el_giro(tapa)
	golpe = _rayo(almacen, centro + Vector3.UP * 1.3, centro)
	assert_bool(golpe.is_empty()).is_false()
	if not golpe.is_empty():
		assert_float(golpe.position.y - centro.y).is_between(0.12, 0.14)
	assert_bool(zona.monitoring).is_true()
	assert_vector(tapa.bisagra.global_position).is_equal_approx(bisagra, Vector3.ONE * 0.00001)


func test_clic_derecho_sobre_el_cuerpo_tambien_alterna_la_tapa() -> void:  # AC-CLN-034
	var almacen := await _abrir()
	var zona: Area3D = almacen.get_node("Objetos/ZonaDeDescarte")
	var centro := zona.global_position + Vector3.UP * 0.65
	var golpe := _rayo(almacen, centro + Vector3.BACK, centro)
	assert_bool(golpe.is_empty()).is_false()
	if golpe.is_empty():
		return
	var cuerpo: StaticBody3D = golpe.collider
	assert_str(str(almacen.get_path_to(cuerpo))).contains("deposito_contenedor_cuerpo")
	assert_bool(cuerpo.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	assert_bool(cuerpo.has_method(ReglasDeLosObjetos.METODO_USAR)).is_true()
	assert_bool(cuerpo.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_false()
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	jugador.set("_enfocado", cuerpo)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_RIGHT
	clic.pressed = true
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	jugador.call("_unhandled_input", clic)
	await _terminar_el_giro(tapa)
	assert_bool(zona.monitoring).is_false()
	golpe = _rayo(almacen, zona.global_position + Vector3.UP * 1.3, zona.global_position)
	assert_object(golpe.get("collider")).is_same(tapa)
	jugador.call("_unhandled_input", clic)
	await _terminar_el_giro(tapa)
	assert_bool(zona.monitoring).is_true()


func test_bolsa_con_tapa_cerrada_se_conserva_y_se_descarta_al_abrir() -> void:  # AC-CLN-035
	var almacen := await _abrir()
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	tapa.usar()
	await _terminar_el_giro(tapa)
	var zona: Area3D = almacen.get_node("Objetos/ZonaDeDescarte")
	assert_bool(zona.monitoring).is_false()
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	jugador.global_position = zona.global_position + Vector3.BACK
	var bolsa: ObjetoAgarrable = almacen.get_node("Objetos/BolsaDeBasura1")
	var datos := bolsa.datos
	var agarre: Agarre = jugador.get("agarre")
	assert_bool(agarre.pedir_agarrar(datos, bolsa)).is_true()
	agarre.punto_de_soltado.global_position = zona.global_position + Vector3.UP * 1.5
	assert_object(agarre.soltar(true)).is_same(bolsa)
	for cuadro: int in 10:
		await get_tree().physics_frame
	var recolector: RecolectorDeBasura = almacen.get_node("Servicios/Recolector")
	assert_bool(recolector.tarea().esta_depositada(datos.id)).is_false()
	assert_int(recolector.tarea().depositadas()).is_equal(0)
	assert_bool(is_instance_valid(bolsa)).is_true()
	tapa.usar()
	await _terminar_el_giro(tapa)
	for cuadro: int in 10:
		await get_tree().physics_frame
	assert_bool(recolector.tarea().esta_depositada(datos.id)).is_true()
	assert_int(recolector.tarea().depositadas()).is_equal(1)


func test_reiniciar_restaura_tapa_y_sensor_abiertos() -> void:  # AC-CLN-034
	var almacen := await _abrir()
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	var abierta := tapa.bisagra.global_transform
	tapa.usar()
	await _terminar_el_giro(tapa)
	almacen.call("_al_abrir_la_jornada", 2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var zona: Area3D = almacen.get_node("Objetos/ZonaDeDescarte")
	assert_bool(zona.monitoring).is_true()
	assert_vector(tapa.bisagra.global_position).is_equal_approx(
		abierta.origin, Vector3.ONE * 0.00001
	)
	assert_vector(tapa.bisagra.global_basis.z).is_equal_approx(
		abierta.basis.z, Vector3.ONE * 0.00001
	)


func test_la_tapa_se_detiene_ante_un_objeto_y_continua_cuando_se_retira() -> void:  # AC-CLN-034
	var almacen := await _abrir()
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	var zona: Area3D = almacen.get_node("Objetos/ZonaDeDescarte")
	var obstaculo: ObjetoAgarrable = OBJETO.instantiate()
	obstaculo.freeze = true
	almacen.add_child(obstaculo)
	obstaculo.global_position = zona.global_position + Vector3.UP * 1.10
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
	assert_bool(zona.monitoring).is_false()
	tapa.usar()
	for cuadro in 60:
		await get_tree().physics_frame
	assert_float(estado.angulo()).is_equal(TapaDelContenedor.ANGULO_ABIERTA)
	assert_bool(zona.monitoring).is_true()


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
	var zona: Area3D = almacen.get_node("Objetos/ZonaDeDescarte")
	var centro := zona.global_position
	var camara: Camera3D = jugador.get("_camara")
	camara.look_at(centro + Vector3.UP * 0.8)
	var unidades: Array[ObjetoAgarrable] = []
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
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
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
