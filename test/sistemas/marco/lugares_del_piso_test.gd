extends GdUnitTestSuite

const LADOS := 8


## Un piso de 10 × 10 m con la cara de arriba en y = 0, y un pozo sin piso hacia +X.
func _piso_con_un_pozo() -> Node3D:
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	var piso := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(10.0, 1.0, 10.0)
	forma.shape = caja
	forma.position = Vector3(-4.0, -0.5, 0.0)
	piso.add_child(forma)
	raiz.add_child(piso)
	await get_tree().physics_frame
	return raiz


func test_los_lugares_arrancan_por_adelante_y_saltean_donde_no_hay_piso() -> void:
	var raiz: Node3D = await _piso_con_un_pozo()
	var lugares := LugaresDelPiso.alrededor(
		raiz.get_world_3d().direct_space_state,
		Vector3(0.0, 1.0, 0.0),
		Vector3.FORWARD,
		1.5,
		0.5,
		3.0,
		LADOS,
		1,
		[] as Array[RID]
	)
	assert_int(lugares.size()).is_less(LADOS)
	assert_vector(lugares[0]).is_equal_approx(Vector3(0.0, 0.0, -1.5), Vector3.ONE * 0.001)
	for lugar in lugares:
		assert_float(lugar.x).is_less(1.1)


func test_sin_piso_no_hay_lugar() -> void:
	var raiz: Node3D = await _piso_con_un_pozo()
	var lugares := LugaresDelPiso.alrededor(
		raiz.get_world_3d().direct_space_state,
		Vector3(20.0, 1.0, 0.0),
		Vector3.FORWARD,
		1.0,
		0.5,
		3.0,
		LADOS,
		1,
		[] as Array[RID]
	)
	assert_array(lugares).is_empty()


func _solido(raiz: Node3D, nombre: String, tamano: Vector3, punto: Vector3) -> StaticBody3D:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tamano
	forma.shape = caja
	forma.position = punto
	cuerpo.add_child(forma)
	raiz.add_child(cuerpo)
	return cuerpo


func test_el_piso_del_otro_lado_de_una_pared_no_es_un_lugar_cercano() -> void:  # AC-CLN-045
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	_solido(raiz, "PisoActual", Vector3(8.0, 0.2, 4.0), Vector3(0.0, -0.1, 1.5))
	var otro := _solido(raiz, "OtroPiso", Vector3(8.0, 0.2, 4.0), Vector3(0.0, -0.1, -2.5))
	var pared := _solido(raiz, "Pared", Vector3(8.0, 3.0, 0.1), Vector3(0.0, 1.5, -0.5))
	await get_tree().physics_frame
	var espacio := raiz.get_world_3d().direct_space_state
	var centro := Vector3(0.0, 0.1, 0.0)
	var lateral := centro + Vector3.FORWARD * 2.5
	var piso := espacio.intersect_ray(
		PhysicsRayQueryParameters3D.create(lateral + Vector3.UP, lateral + Vector3.DOWN)
	)
	assert_object(piso.get("collider")).is_same(otro)
	var recorrido := espacio.intersect_ray(
		PhysicsRayQueryParameters3D.create(centro + Vector3.UP * 0.5, lateral + Vector3.UP * 0.5)
	)
	assert_object(recorrido.get("collider")).is_same(pared)
	var lugares := LugaresDelPiso.alrededor(
		espacio, centro, Vector3.FORWARD, 2.5, 0.5, 3.0, LADOS, 1, [] as Array[RID]
	)
	assert_array(lugares).is_not_empty()
	for lugar in lugares:
		assert_float(lugar.z).is_greater(-0.5)
	# Sin la pared vuelve el mismo primer candidato. La máscara y las exclusiones se respetan.
	pared.collision_layer = 2
	await get_tree().physics_frame
	lugares = LugaresDelPiso.alrededor(
		espacio, centro, Vector3.FORWARD, 2.5, 0.5, 3.0, LADOS, 1, [] as Array[RID]
	)
	assert_vector(lugares[0]).is_equal_approx(Vector3(0.0, 0.0, -2.5), Vector3.ONE * 0.001)
	pared.collision_layer = 1
	await get_tree().physics_frame
	lugares = LugaresDelPiso.alrededor(
		espacio, centro, Vector3.FORWARD, 2.5, 0.5, 3.0, LADOS, 1, [pared.get_rid()]
	)
	assert_vector(lugares[0]).is_equal_approx(Vector3(0.0, 0.0, -2.5), Vector3.ONE * 0.001)
