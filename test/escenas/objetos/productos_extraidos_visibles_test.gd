extends GdUnitTestSuite

const ALMACEN := "res://src/escenas/almacen.tscn"


func _local() -> Node3D:
	var local: Node3D = auto_free(load(ALMACEN).instantiate())
	local.set("_partida", Partida.desde({"jornada": 5, "medios": 0}))
	add_child(local)
	(local.get("_reloj") as Node).set_process(false)
	(local.get("_jugador") as Node).set_physics_process(false)
	return local


func _caja(local: Node3D, id: Producto.Id) -> Node3D:
	for caja: Node3D in local.get("_cajas_de_productos"):
		if caja.get("producto") == id:
			return caja
	return null


func _grupo(local: Node3D, id: Producto.Id) -> MultiMeshInstance3D:
	return local.get("_reposicion_manual").get_node("SueltosDe" + Catalogo.de(id).nombre)


func _accion(jugador: Node3D, objetivo: Node3D, accion: StringName) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _sacar_y_soltar(local: Node3D, id: Producto.Id, indice: int) -> RigidBody3D:
	var agarre: Agarre = local.get("_agarre")
	_accion(local.get("_jugador"), _caja(local, id), ReglasDelJugador.ACCION_USAR)
	var cuerpo := agarre.cuerpo_sostenido() as RigidBody3D
	assert_object(cuerpo).is_not_null()
	if cuerpo == null:
		return null
	assert_int((agarre.manos().sostenido() as UnidadDeProducto).producto.id).is_equal(id)
	assert_bool((cuerpo.get_node("Malla") as MeshInstance3D).visible).is_true()
	assert_object(agarre.soltar(true)).is_same(cuerpo)
	# Piso libre del depósito medido por las suites físicas. La mira real se ejerce además
	# en el recorrido nativo; aquí se aísla la transferencia que conserva cuerpo y dibujo.
	cuerpo.global_position = Vector3(
		4.18 + (indice % 4) * 0.6, 0.4, -8.95 - floori(float(indice) / 4.0) * 0.6
	)
	cuerpo.linear_velocity = Vector3.ZERO
	cuerpo.angular_velocity = Vector3.ZERO
	return cuerpo


func _afirmar_dibujos(grupo: MultiMeshInstance3D, cuerpos: Array[RigidBody3D]) -> void:
	grupo.call("_process", 0.0)
	assert_int(grupo.multimesh.visible_instance_count).is_equal(cuerpos.size())
	assert_int(grupo.multimesh.instance_count).is_greater_equal(cuerpos.size())
	var agrupados: Array = grupo.get("cuerpos")
	var matrices: Array = grupo.get("_matrices")
	assert_int(agrupados.size()).is_equal(cuerpos.size())
	for cuerpo in cuerpos:
		assert_bool(is_instance_valid(cuerpo)).is_true()
		var indice := agrupados.find(cuerpo)
		assert_int(indice).is_greater_equal(0)
		if indice < 0:
			continue
		var malla: MeshInstance3D = cuerpo.get_node("Malla")
		var copia: Transform3D = matrices[indice]
		var dibuja_copia := not is_zero_approx(copia.basis.determinant())
		assert_int(int(malla.visible) + int(dibuja_copia)).is_equal(1)
		if dibuja_copia:
			var limites := copia * grupo.multimesh.mesh.get_aabb()
			assert_bool(grupo.custom_aabb.grow(0.001).encloses(limites)).is_true()
			if DisplayServer.get_name() != "headless":
				(
					assert_bool(
						grupo.multimesh.get_instance_transform(indice).is_equal_approx(copia)
					)
					. is_true()
				)


func test_saladik_sale_de_su_caja_se_enfoca_se_recoge_y_se_devuelve() -> void:
	var local := _local()
	var id := Producto.Id.SALADICK
	var agarre: Agarre = local.get("_agarre")
	var repositor: Repositor = local.get("_repositor")
	var cantidad := repositor.caja(id).unidades()
	var cuerpo := _sacar_y_soltar(local, id, 0)
	if cuerpo == null:
		return
	var cuerpos: Array[RigidBody3D] = [cuerpo]
	var grupo := _grupo(local, id)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_afirmar_dibujos(grupo, cuerpos)
	var jugador: Node3D = local.get("_jugador")
	jugador.emit_signal("objetivo_enfocado", cuerpo, 1.0)
	_afirmar_dibujos(grupo, cuerpos)
	assert_bool((cuerpo.get_node("Malla") as MeshInstance3D).visible).is_true()
	jugador.emit_signal("objetivo_perdido")
	_afirmar_dibujos(grupo, cuerpos)
	_accion(jugador, cuerpo, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.cuerpo_sostenido()).is_same(cuerpo)
	assert_int(grupo.multimesh.visible_instance_count).is_zero()
	_accion(jugador, _caja(local, id), ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.cuerpo_sostenido()).is_null()
	assert_int(repositor.caja(id).unidades()).is_equal(cantidad)
	assert_bool(cuerpo.visible).is_false()


func test_caja_completa_conserva_cada_dibujo_al_cruzar_la_capacidad_inicial() -> void:
	var local := _local()
	var id := Producto.Id.ACTRONCITO
	for producto in Catalogo.todos():
		if (
			_grupo(local, producto.id).multimesh.instance_count
			< _grupo(local, id).multimesh.instance_count
		):
			id = producto.id
	var grupo := _grupo(local, id)
	var capacidad := grupo.multimesh.instance_count
	var repositor: Repositor = local.get("_repositor")
	var cantidad := repositor.caja(id).unidades()
	assert_int(cantidad).is_greater(0)
	var cuerpos: Array[RigidBody3D] = []
	for indice in cantidad:
		var cuerpo := _sacar_y_soltar(local, id, indice)
		if cuerpo == null:
			return
		cuerpos.append(cuerpo)
		await get_tree().physics_frame
		_afirmar_dibujos(grupo, cuerpos)
	if cantidad > capacidad:
		assert_int(grupo.multimesh.instance_count).is_greater(capacidad)
	assert_int(repositor.caja(id).unidades()).is_zero()
	_accion(local.get("_jugador"), _caja(local, id), ReglasDelJugador.ACCION_USAR)
	assert_object((local.get("_agarre") as Agarre).cuerpo_sostenido()).is_null()
	_afirmar_dibujos(grupo, cuerpos)
	# Quitar del medio reutiliza el último índice; devolver no debe borrar otra instancia.
	var medio := floori(float(cuerpos.size()) / 2.0)
	for elegido: RigidBody3D in [cuerpos[medio], cuerpos.front(), cuerpos.back()]:
		_accion(local.get("_jugador"), elegido, ReglasDeLosObjetos.ACCION_AGARRAR)
		cuerpos.erase(elegido)
		_afirmar_dibujos(grupo, cuerpos)
		_accion(local.get("_jugador"), _caja(local, id), ReglasDeLosObjetos.ACCION_AGARRAR)
		assert_bool(elegido.visible).is_false()
		_afirmar_dibujos(grupo, cuerpos)


func test_el_deposito_conserva_dibujos_independientes_de_productos_distintos() -> void:
	var local := _local()
	var productos: Array[Producto.Id] = [
		Producto.Id.MAROLINI, Producto.Id.SALADICK, Producto.Id.LAYSNNT
	]
	var por_producto: Dictionary[Producto.Id, Array] = {}
	var lugar := 0
	for id in productos:
		var cuerpos: Array[RigidBody3D] = []
		for _unidad in 3:
			var cuerpo := _sacar_y_soltar(local, id, lugar)
			if cuerpo == null:
				return
			cuerpos.append(cuerpo)
			lugar += 1
		por_producto[id] = cuerpos
	await get_tree().physics_frame
	await get_tree().physics_frame
	for id in productos:
		var cuerpos: Array[RigidBody3D] = []
		cuerpos.assign(por_producto[id])
		_afirmar_dibujos(_grupo(local, id), cuerpos)
		for cuerpo in cuerpos:
			assert_int((cuerpo.get("datos") as UnidadDeProducto).producto.id).is_equal(id)
	var recogida: RigidBody3D = por_producto[Producto.Id.SALADICK][1]
	_accion(local.get("_jugador"), recogida, ReglasDeLosObjetos.ACCION_AGARRAR)
	por_producto[Producto.Id.SALADICK].erase(recogida)
	for id in productos:
		var cuerpos: Array[RigidBody3D] = []
		cuerpos.assign(por_producto[id])
		_afirmar_dibujos(_grupo(local, id), cuerpos)
