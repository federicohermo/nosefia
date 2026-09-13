extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_los_estantes_agrupan_las_unidades_sin_cuerpos_por_producto() -> void:  # 042-AC1
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var grupos := presentacion.find_children("*", "MultiMeshInstance3D", true, false)
	assert_int(grupos.size()).is_equal(Catalogo.todos().size())
	for grupo: MultiMeshInstance3D in grupos:
		assert_int(grupo.multimesh.visible_instance_count).is_zero()
	var agarre: Agarre = almacen.get("_agarre")
	for producto in Catalogo.todos():
		var grupo: MultiMeshInstance3D = presentacion.get_node("ProductosDe" + producto.nombre)
		assert_int(grupo.multimesh.instance_count).is_equal(producto.umbral)
		for indice in producto.umbral:
			presentacion.call("retirar", producto.id)
			assert_object(agarre.manos().sostenido()).is_not_null()
			presentacion.call("pedir_colocar", producto.id)
			assert_int(grupo.multimesh.visible_instance_count).is_equal(indice + 1)
		assert_int(grupo.get_child_count()).is_zero()
	assert_int(presentacion.find_children("*", "RigidBody3D", true, false).size()).is_equal(1)


func test_reutiliza_el_cuerpo_al_depositar_y_cambia_de_producto() -> void:  # 042-AC3
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	presentacion.call("retirar", Producto.Id.ACTRONCITO)
	var cuerpo := agarre.punto_de_producto.get_child(0)
	var anterior: Resource = cuerpo.datos
	presentacion.call("pedir_colocar", Producto.Id.ACTRONCITO)
	assert_bool(cuerpo.is_visible_in_tree()).is_false()
	assert_int(cuerpo.collision_layer).is_zero()
	presentacion.call("retirar", Producto.Id.JORGILLO)
	assert_object(agarre.punto_de_producto.get_child(0)).is_same(cuerpo)
	assert_object(cuerpo.datos).is_not_same(anterior)
	assert_int(cuerpo.datos.producto.id).is_equal(Producto.Id.JORGILLO)
	var suelto: RigidBody3D = agarre.soltar(true)
	assert_bool(suelto.freeze).is_false()
	assert_int(suelto.collision_layer).is_equal(1)
	assert_int(suelto.collision_mask).is_equal(1)


func test_las_unidades_sueltas_caen_y_se_recuperan_sin_perder_su_reserva() -> void:  # 042-AC4
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	var estante: Estante = almacen.get("_repositor").estante()
	var producto := Catalogo.de(Producto.Id.JABON)
	var sueltas: Array[RigidBody3D] = []
	for indice in producto.umbral:
		presentacion.call("retirar", producto.id)
		var cuerpo: RigidBody3D = agarre.soltar(true)
		cuerpo.global_position = Vector3(indice, 2, -6)
		sueltas.append(cuerpo)
		assert_bool(cuerpo.freeze).is_false()
		assert_int(cuerpo.collision_layer).is_equal(1)
	assert_object(sueltas[0]).is_not_same(sueltas[1])
	for cuadro in 12:
		await get_tree().physics_frame
	assert_float(sueltas[0].global_position.y).is_less(2.0)
	assert_float(sueltas[1].global_position.y).is_less(2.0)
	presentacion.call("retirar", producto.id)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(estante.disponibles_para_retirar(producto)).is_zero()
	var identidad: UnidadDeProducto = sueltas[0].datos
	assert_bool(agarre.pedir_agarrar(identidad, sueltas[0])).is_true()
	assert_object(agarre.manos().sostenido()).is_same(identidad)
	presentacion.call("pedir_colocar", Producto.Id.ACTRONCITO)
	assert_object(agarre.manos().sostenido()).is_same(identidad)
	presentacion.call("pedir_colocar", producto.id)
	assert_int(estante.unidades_en_gondola(producto)).is_equal(1)
	assert_int(estante.disponibles_para_retirar(producto)).is_zero()
	assert_bool(sueltas[1].is_visible_in_tree()).is_true()
	assert_bool(sueltas[1].freeze).is_false()
	assert_bool(agarre.pedir_agarrar(sueltas[1].datos, sueltas[1])).is_true()
	presentacion.call("pedir_colocar", producto.id)
	assert_int(estante.unidades_en_gondola(producto)).is_equal(producto.umbral)


func test_otra_jornada_vacia_grupos_mano_y_productos_sueltos() -> void:  # 042-AC5
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	presentacion.call("retirar", Producto.Id.ACTRONCITO)
	presentacion.call("pedir_colocar", Producto.Id.ACTRONCITO)
	presentacion.call("retirar", Producto.Id.ACTRONCITO)
	var suelta := agarre.soltar(true)
	presentacion.call("retirar", Producto.Id.JORGILLO)
	var sostenida := agarre.punto_de_producto.get_child(0)
	almacen.call("_al_abrir_la_jornada", 2)
	await get_tree().process_frame
	assert_bool(is_instance_valid(suelta)).is_false()
	assert_bool(is_instance_valid(sostenida)).is_false()
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(agarre.punto_de_producto.get_child_count()).is_zero()
	for grupo: MultiMeshInstance3D in presentacion.find_children(
		"*", "MultiMeshInstance3D", true, false
	):
		assert_int(grupo.multimesh.visible_instance_count).is_zero()
	presentacion.call("retirar", Producto.Id.JORGILLO)
	assert_object(agarre.manos().sostenido()).is_not_null()


func test_el_frente_se_conserva_al_examinar_y_volver_a_agarrar() -> void:  # 042-AC3
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
		var grupo: MultiMeshInstance3D = almacen.get("_reposicion_manual").get_node(
			"ProductosDe" + producto.nombre
		)
		(
			assert_bool(
				_transformacion_de_copia(grupo.multimesh, 0).basis.is_equal_approx(Basis.IDENTITY)
			)
			. is_true()
		)


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


func test_cada_unidad_ocupa_un_lugar_distinto_y_la_marca_indica_su_base() -> void:  # 042-AC2
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
			var grupo: MultiMeshInstance3D = presentacion.get_node("ProductosDe" + producto.nombre)
			var transformacion := (
				grupo.global_transform * _transformacion_de_copia(grupo.multimesh, indice)
			)
			var limites := transformacion * grupo.multimesh.mesh.get_aabb()
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
	assert_bool(unidad.is_visible_in_tree()).is_false()
	var grupo: MultiMeshInstance3D = almacen.get("_reposicion_manual").get_node(
		"ProductosDeActroncito"
	)
	assert_int(grupo.multimesh.visible_instance_count).is_equal(1)
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


func _transformacion_de_copia(copias: MultiMesh, indice: int) -> Transform3D:
	# El renderizador dummy no implementa get_instance_transform; sí conserva el buffer.
	if DisplayServer.get_name() != "headless":
		return copias.get_instance_transform(indice)
	var valores := copias.buffer
	var inicio := indice * 12
	return Transform3D(
		Basis(
			Vector3(valores[inicio], valores[inicio + 4], valores[inicio + 8]),
			Vector3(valores[inicio + 1], valores[inicio + 5], valores[inicio + 9]),
			Vector3(valores[inicio + 2], valores[inicio + 6], valores[inicio + 10])
		),
		Vector3(valores[inicio + 3], valores[inicio + 7], valores[inicio + 11])
	)


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
