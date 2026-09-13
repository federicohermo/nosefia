extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_el_frente_se_conserva_al_examinar_y_volver_a_agarrar() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var agarre: Agarre = almacen.get("_agarre")
	var frentes := [
		Vector3.RIGHT,
		Vector3.BACK,
		Vector3.RIGHT,
		Vector3.LEFT,
		Vector3.FORWARD,
		Vector3.BACK,
		Vector3.RIGHT,
		Vector3.FORWARD
	]
	for producto in Catalogo.todos():
		almacen.get("_cajas_de_productos")[producto.id].interactuar()
		var unidad: Node3D = agarre.punto_de_producto.get_child(0)
		var orientacion := unidad.basis
		assert_float((orientacion * frentes[producto.id]).dot(Vector3.BACK)).is_greater(0.8)
		assert_bool(orientacion.is_equal_approx(Basis.IDENTITY)).is_false()
		agarre.mover_lo_sostenido(almacen.get("_jugador").get_node("Camara/PuntoDeExamen"))
		unidad.rotate_y(0.7)
		agarre.devolver_a_la_mano()
		assert_bool(unidad.basis.is_equal_approx(orientacion)).is_true()
		agarre.soltar(true)
		assert_bool(agarre.pedir_agarrar(unidad.datos, unidad)).is_true()
		assert_bool(unidad.basis.is_equal_approx(orientacion)).is_true()
		almacen.get("_reposicion_manual").get_node("ZonaDe" + producto.nombre).interactuar()
		assert_bool(unidad.global_basis.is_equal_approx(Basis.IDENTITY)).is_true()


func test_actroncito_marolini_y_jorgillo_se_reponen_con_foco_y_clic_reales() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	for id in [Producto.Id.ACTRONCITO, Producto.Id.MAROLINI, Producto.Id.JORGILLO]:
		var caja: Node3D = almacen.get("_cajas_de_productos")[id]
		var vista: MeshInstance3D = caja.get_node("Malla")
		var centro := vista.global_transform * vista.mesh.get_aabb().get_center()
		await _mirar_foco(jugador, centro + Vector3(0, 0.7, 1.3), centro)
		assert_object(jugador.get("_enfocado")).is_same(caja)
		_clic_real(jugador)
		var unidad: UnidadDeProducto = almacen.get("_agarre").manos().sostenido()
		assert_object(unidad).is_not_null()
		if unidad == null:
			return
		assert_int(unidad.producto.id).is_equal(id)
		var zona: Node3D = almacen.get("_reposicion_manual").get_node(
			"ZonaDe" + unidad.producto.nombre
		)
		var desde := Vector3(0, 0.3, -1.2) if id == Producto.Id.JORGILLO else Vector3(1.2, 0.3, 0)
		await _mirar_foco(jugador, zona.global_position + desde, zona.global_position)
		assert_object(jugador.get("_enfocado")).is_same(zona)
		_clic_real(jugador)
		assert_object(almacen.get("_agarre").manos().sostenido()).is_null()
		(
			assert_int(almacen.get("_repositor").estante().unidades_en_gondola(Catalogo.de(id)))
			. is_equal(1)
		)


func test_no_hay_productos_3d_iniciales_fuera_del_inventario() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	for ruta in ["Zucarachas2_001", "alfajorescaja", "Actroncito", "Actroncito4", "Actroncito_001"]:
		var modelo: Node3D = almacen.get_node("Estructura/" + ruta)
		assert_bool(modelo.is_visible_in_tree()).is_false()
		for cuerpo: PhysicsBody3D in modelo.find_children("*", "PhysicsBody3D", true, false):
			assert_int(cuerpo.collision_layer).is_zero()
	for producto in Catalogo.todos():
		assert_int(almacen.get("_repositor").estante().unidades_en_gondola(producto)).is_zero()
	assert_str(Catalogo.todos()[0].nombre).is_equal("Actroncito")


func _mirar_foco(jugador: Node3D, ojo: Vector3, punto: Vector3) -> void:
	var camara: Camera3D = jugador.get_node("Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	jugador.global_position = ojo - camara.position
	camara.look_at(punto)
	for cuadro in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")


func _clic_real(jugador: Node3D) -> void:
	var clic := InputEventAction.new()
	clic.action = ReglasDeLosObjetos.ACCION_AGARRAR
	clic.pressed = true
	jugador.call("_unhandled_input", clic)


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
			assert_bool(vista.scale.is_equal_approx(Vector3.ONE)).is_true()
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
	_apuntar(almacen, Producto.Id.ACTRONCITO)
	jugador.set("_enfocado", almacen.get("_reposicion_manual").get_node("ZonaDeActroncito"))
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
		_apuntar(jugador.get_parent(), Producto.Id.ACTRONCITO)
		objetivo = jugador.get_parent().get("_reposicion_manual").get_node("ZonaDeActroncito")
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
	var zona := presentacion.get_node("ZonaDeActroncito")
	assert_int(zona.collision_layer).is_equal(2)
	assert_int(presentacion.get_node("ZonaDeFideos").collision_layer).is_zero()
	var mueble: MeshInstance3D = estante.get_parent()
	assert_object(mueble.material_overlay).is_null()
	estante.call("interactuar")
	assert_object(agarre.manos().sostenido()).is_same(sostenido)
	presentacion.get_node("ZonaDeFideos").call("interactuar")
	assert_object(agarre.manos().sostenido()).is_same(sostenido)
