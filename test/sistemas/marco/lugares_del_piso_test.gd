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
