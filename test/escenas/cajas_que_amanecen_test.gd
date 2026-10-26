extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Caja := preload("res://src/escenas/objetos/caja_de_productos.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

const JORNADA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1


func _abrir(poses: Dictionary[Producto.Id, Transform3D]) -> Node3D:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	var partida := Partida.desde({"jornada": JORNADA, "medios": 0})
	partida.poses_de_las_cajas = poses
	local.set("_partida", partida)
	add_child(local)
	local.get_node("Interfaz/PersianaDeLaNoche").terminar()
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	for _cuadro in 4:
		await get_tree().physics_frame
	return local


func _fabricas() -> Dictionary[Producto.Id, Transform3D]:
	var sin_poses: Dictionary[Producto.Id, Transform3D] = {}
	var local := await _abrir(sin_poses)
	var fabricas: Dictionary[Producto.Id, Transform3D] = {}
	for caja: Caja in local.get("_cajas_de_productos"):
		fabricas[caja.producto] = caja.pose_de_estanteria()
	local.queue_free()
	await get_tree().process_frame
	return fabricas


func _del_mismo_tamano(fabricas: Dictionary[Producto.Id, Transform3D]) -> Array[Producto.Id]:
	var por_tamano: Dictionary[Catalogo.TamanoDeCaja, Producto.Id] = {}
	for id: Producto.Id in fabricas:
		var tamano := Catalogo.caja_de(id)
		if por_tamano.has(tamano):
			return [por_tamano[tamano], id]
		por_tamano[tamano] = id
	return []


func _caja(local: Node3D, id: Producto.Id) -> Caja:
	for caja: Caja in local.get("_cajas_de_productos"):
		if caja.producto == id:
			return caja
	return null


func _esta_en_estanteria(local: Node3D, caja: Caja) -> bool:
	var rayo := PhysicsRayQueryParameters3D.create(
		caja.global_position,
		caja.global_position + Vector3.DOWN * (caja.get_node("Cuerpo").scale.y + 0.02)
	)
	rayo.exclude = [caja.get_rid()]
	var golpe := local.get_world_3d().direct_space_state.intersect_ray(rayo)
	if golpe.is_empty():
		return false
	var nombre := str(golpe.collider.get_parent().name)
	return nombre.begins_with("deposito_pallet_") and nombre != "deposito_pallet_piso"


func test_la_caja_abre_en_la_pose_con_que_cerro() -> void:  # AC-STK-111 AC-STK-080
	var fabricas := await _fabricas()
	var par := _del_mismo_tamano(fabricas)
	assert_int(par.size()).is_equal(2)
	var guardadas: Dictionary[Producto.Id, Transform3D] = fabricas.duplicate()
	guardadas[par[0]] = fabricas[par[1]]
	guardadas[par[1]] = fabricas[par[0]]
	var local := await _abrir(guardadas)
	assert_array(local.call("_repisas_del_deposito")).is_not_empty()
	for id in par:
		var caja := _caja(local, id)
		assert_bool(caja.lugar_de_origen().is_equal_approx(guardadas[id])).is_true()
		assert_bool(caja.global_transform.is_equal_approx(guardadas[id])).is_true()
		assert_bool(_esta_en_estanteria(local, caja)).is_true()


func test_la_caja_que_cerro_afuera_abre_en_un_hueco_libre_y_estable() -> void:  # AC-STK-112
	var fabricas := await _fabricas()
	var par := _del_mismo_tamano(fabricas)
	assert_int(par.size()).is_equal(2)
	var guardadas: Dictionary[Producto.Id, Transform3D] = fabricas.duplicate()
	guardadas[par[0]] = Transform3D(
		fabricas[par[0]].basis, fabricas[par[0]].origin + Vector3.DOWN * 20.0
	)
	guardadas[par[1]] = fabricas[par[0]]
	var local := await _abrir(guardadas)
	for caja: Caja in local.get("_cajas_de_productos"):
		(
			assert_int(caja.collision_layer)
			. override_failure_message("%s no está presente en la jornada" % caja.name)
			. is_not_zero()
		)
	var afuera := _caja(local, par[0])
	var ocupante := _caja(local, par[1])
	assert_bool(ocupante.global_transform.is_equal_approx(fabricas[par[0]])).is_true()
	assert_bool(afuera.lugar_de_origen().is_equal_approx(fabricas[par[1]])).is_true()
	assert_bool(_esta_en_estanteria(local, afuera)).is_true()
	for _cuadro in 120:
		await get_tree().physics_frame
	assert_float(afuera.global_position.distance_to(fabricas[par[1]].origin)).is_less_equal(0.01)
	assert_float(ocupante.global_position.distance_to(fabricas[par[0]].origin)).is_less_equal(0.01)


func test_el_cierre_anota_la_pose_de_cada_caja_y_la_guarda() -> void:  # AC-SAV-034
	var sin_poses: Dictionary[Producto.Id, Transform3D] = {}
	var local := await _abrir(sin_poses)
	var movida: Caja = local.get("_cajas_de_productos")[0]
	var pose := Transform3D(Basis.IDENTITY, Vector3(0.0, -5.0, 0.0))
	movida.global_transform = pose
	movida.quedarse_quieta()
	RelojDePrueba.avanzar_turno(local.get("_reloj"), Reglas.DURACION_DEL_TURNO)
	var partida: Partida = local.get("_partida")
	var poses := partida.poses_de_las_cajas
	assert_int(poses.size()).is_equal(local.get("_cajas_de_productos").size())
	assert_bool(poses[movida.producto].is_equal_approx(pose)).is_true()
	var retomada := Partida.desde(Guardado.new().cargar())
	assert_bool(retomada.poses_de_las_cajas[movida.producto].is_equal_approx(pose)).is_true()
