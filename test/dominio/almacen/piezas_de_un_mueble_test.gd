extends GdUnitTestSuite

const HUECO := PiezasDeUnMueble.HUECO_ENTRE_PIEZAS


## Una pieza hecha de dos triángulos que cubren de punta a punta su extensión en Z.
func _caja(desde_z: float, hasta_z: float) -> PackedVector3Array:
	return PackedVector3Array(
		[
			Vector3(0, 0, desde_z),
			Vector3(1, 0, desde_z),
			Vector3(1, 1, hasta_z),
			Vector3(0, 1, hasta_z),
			Vector3(0, 0, hasta_z),
			Vector3(1, 1, desde_z),
		]
	)


func test_dos_partes_separadas_por_mas_del_hueco_son_dos_piezas() -> void:
	var caras := _caja(0.0, 2.0) + _caja(2.0 + HUECO * 2.0, 4.0)
	var piezas := PiezasDeUnMueble.de_triangulos(caras)
	assert_int(piezas.size()).is_equal(2)
	assert_float(piezas[0].end.z).is_equal_approx(2.0, 0.0001)
	assert_float(piezas[1].position.z).is_equal_approx(2.0 + HUECO * 2.0, 0.0001)


func test_dos_partes_que_se_tocan_o_casi_son_una_pieza() -> void:
	for separacion: float in [0.0, HUECO / 2.0]:
		var caras := _caja(0.0, 2.0) + _caja(2.0 + separacion, 4.0)
		var piezas := PiezasDeUnMueble.de_triangulos(caras)
		assert_int(piezas.size()).is_equal(1)
		assert_float(piezas[0].size.z).is_equal_approx(4.0, 0.0001)


func test_el_orden_de_los_triangulos_no_cambia_las_piezas() -> void:
	var caras := _caja(6.0, 8.0) + _caja(0.0, 2.0) + _caja(3.0, 5.0)
	var piezas := PiezasDeUnMueble.de_triangulos(caras)
	assert_int(piezas.size()).is_equal(3)
	assert_float(piezas[0].position.z).is_equal_approx(0.0, 0.0001)
	assert_float(piezas[2].end.z).is_equal_approx(8.0, 0.0001)


func test_una_malla_sin_triangulos_no_tiene_piezas() -> void:
	assert_array(PiezasDeUnMueble.de_triangulos(PackedVector3Array())).is_empty()


func test_las_piezas_de_una_malla_salen_de_sus_caras() -> void:
	var malla := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _caja(0.0, 1.0) + _caja(1.0 + HUECO * 3.0, 2.0)
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	assert_int(PiezasDeUnMueble.de_la_malla(malla).size()).is_equal(2)
