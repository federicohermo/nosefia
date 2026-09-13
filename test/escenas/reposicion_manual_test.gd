extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_cada_unidad_ocupa_un_lugar_distinto_y_la_marca_indica_su_base() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var ocupados: Array[AABB] = []
	for producto in Catalogo.todos():
		var zona := presentacion.get_node("ZonaDe" + producto.nombre)
		for indice in producto.umbral:
			_accion(jugador, almacen.get("_cajas_de_productos")[producto.id])
			var unidad: Node3D = jugador.get_node("Camara/PuntoDeProducto").get_child(0)
			var marca: MeshInstance3D = zona.mallas[0]
			var apoyo := marca.global_position
			assert_float(absf(marca.global_basis.z.dot(Vector3.UP))).is_equal_approx(1.0, 0.001)
			_accion(jugador, zona)
			var vista: MeshInstance3D = unidad.get_node("Malla")
			var limites := vista.global_transform * vista.mesh.get_aabb()
			assert_float(limites.get_center().x).is_equal_approx(apoyo.x, 0.001)
			assert_float(limites.get_center().z).is_equal_approx(apoyo.z, 0.001)
			assert_float(limites.position.y).is_equal_approx(apoyo.y - 0.005, 0.001)
			for ocupado in ocupados:
				assert_bool(limites.intersects(ocupado)).is_false()
			ocupados.append(limites)
		_accion(jugador, almacen.get("_cajas_de_productos")[producto.id])
		assert_object(almacen.get("_agarre").manos().sostenido()).is_null()


func test_el_clic_saca_una_unidad_visible_y_el_estante_la_recibe() -> void:  # 006-AC7 008-AC2
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = jugador.get("agarre")
	var caja: Node3D = almacen.get("_cajas_de_productos")[0]
	var estante: Node3D = almacen.get("_estante")
	var repositor: Repositor = almacen.get("_repositor")
	jugador.set("_enfocado", caja)
	var clic := InputEventAction.new()
	clic.action = ReglasDeLosObjetos.ACCION_AGARRAR
	clic.pressed = true
	jugador.call("_unhandled_input", clic)
	assert_object(agarre.manos().sostenido()).is_not_null()
	var punto := jugador.get_node_or_null("Camara/PuntoDeProducto")
	assert_object(punto).is_not_null()
	if punto == null or punto.get_child_count() == 0:
		return
	var unidad: Node3D = punto.get_child(0)
	assert_bool(unidad.is_visible_in_tree()).is_true()
	assert_int(unidad.collision_layer).is_zero()
	assert_float(punto.position.x).is_zero()
	assert_float(punto.position.y).is_zero()
	jugador.call("_unhandled_input", clic)
	assert_int(punto.get_child_count()).is_equal(1)
	_apuntar(almacen, Producto.Id.YERBA)
	jugador.set("_enfocado", almacen.get("_reposicion_manual").get_node("ZonaDeYerba"))
	jugador.call("_unhandled_input", clic)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(estante.is_ancestor_of(unidad)).is_true()
	assert_bool(unidad.is_visible_in_tree()).is_true()
	assert_int(repositor.estante().unidades_en_gondola(Catalogo.todos()[0])).is_equal(1)


func test_con_el_estante_lleno_la_caja_no_entrega_otra_unidad() -> void:  # 008-AC1
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	var jugador: Node3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[0]
	var estante: Node3D = almacen.get("_estante")
	var agarre: Agarre = almacen.get("_agarre")
	for unidad in Catalogo.todos()[0].umbral:
		_accion(jugador, caja)
		_accion(jugador, estante)
	_accion(jugador, caja)
	assert_object(agarre.manos().sostenido()).is_null()
	_accion(jugador, estante)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(jugador.get_node("Camara/PuntoDeProducto").get_child_count()).is_zero()


func test_examinar_no_retira_ni_deposita_y_devuelve_la_unidad_a_la_mira() -> void:  # 006-AC9
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	var jugador: Node3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[0]
	var estante: Node3D = almacen.get("_estante")
	var agarre: Agarre = almacen.get("_agarre")
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_object(agarre.manos().sostenido()).is_null()
	_accion(jugador, caja)
	var sostenido := agarre.manos().sostenido()
	_accion(jugador, estante, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_object(agarre.manos().sostenido()).is_same(sostenido)
	assert_int(jugador.get_node("Camara/PuntoDeExamen").get_child_count()).is_equal(1)
	_accion(jugador, estante, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_int(jugador.get_node("Camara/PuntoDeProducto").get_child_count()).is_equal(1)


func _accion(
	jugador: Node3D, objetivo: Node3D, accion: StringName = ReglasDeLosObjetos.ACCION_AGARRAR
) -> void:
	if objetivo == jugador.get_parent().get("_estante"):
		_apuntar(jugador.get_parent(), Producto.Id.YERBA)
		objetivo = jugador.get_parent().get("_reposicion_manual").get_node("ZonaDeYerba")
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _apuntar(almacen: Node3D, id: Producto.Id) -> void:
	var zona: AABB = almacen.get("_reposicion_manual").zona(id)
	var jugador: Node3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Camara")
	camara.global_position = zona.get_center() + Vector3(0, 0, 1.5)
	camara.look_at(zona.get_center())


func test_solo_la_zona_del_producto_recibe_el_foco_y_el_resto_del_mueble_no_coloca() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var agarre: Agarre = almacen.get("_agarre")
	var estante: Node3D = almacen.get("_estante")
	_accion(jugador, almacen.get("_cajas_de_productos")[0])
	var sostenido := agarre.manos().sostenido()
	assert_bool(estante.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_false()
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var zona := presentacion.get_node("ZonaDeYerba")
	assert_int(zona.collision_layer).is_equal(2)
	assert_int(presentacion.get_node("ZonaDeFideos").collision_layer).is_zero()
	var mueble: MeshInstance3D = estante.get_parent()
	assert_object(mueble.material_overlay).is_null()
	estante.call("interactuar")
	assert_object(agarre.manos().sostenido()).is_same(sostenido)
	presentacion.get_node("ZonaDeFideos").call("interactuar")
	assert_object(agarre.manos().sostenido()).is_same(sostenido)
