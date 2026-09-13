extends GdUnitTestSuite

const MODELO := preload("res://assets/SEPT_JUEGOS_PROTOTIPO.glb")
const CONTENIDO := preload("res://src/escenas/puestos/contenido_del_estante.tscn")
const SOPORTE := preload("res://assets/models/gondola_soporte.res")
const COLISION := preload("res://assets/models/gondola_colision.res")


func test_separar_el_surtido_conserva_vertices_uv_y_materiales() -> void:  # 041-AC7
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var contenido: Node3D = auto_free(CONTENIDO.instantiate())
	var original: ArrayMesh = modelo.get_node("gondola01").mesh
	var superficies: Array[int] = [0, 2, 3, 4, 5]
	for indice in superficies.size():
		var malla: ArrayMesh = contenido.get_child(indice).mesh
		var antes := original.surface_get_arrays(superficies[indice])
		var despues := malla.surface_get_arrays(0)
		assert_array(despues[Mesh.ARRAY_VERTEX]).is_equal(antes[Mesh.ARRAY_VERTEX])
		assert_array(despues[Mesh.ARRAY_TEX_UV]).is_equal(antes[Mesh.ARRAY_TEX_UV])
		var material: StandardMaterial3D = malla.surface_get_material(0)
		var previo: StandardMaterial3D = original.surface_get_material(superficies[indice])
		assert_object(material.albedo_texture).is_same(previo.albedo_texture)
		assert_float(material.roughness).is_equal(previo.roughness)
		assert_int(material.cull_mode).is_equal(previo.cull_mode)
		assert_bool(contenido.get_child(indice).visible).is_false()


func test_la_colision_del_soporte_no_incluye_el_surtido() -> void:  # 041-AC3
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var original: ArrayMesh = modelo.get_node("gondola01").mesh
	assert_int(SOPORTE.get_surface_count()).is_equal(1)
	assert_array(SOPORTE.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]).is_equal(
		original.surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
	)
	assert_array(COLISION.get_faces()).is_equal(SOPORTE.get_faces())


func test_el_contenido_conserva_la_sexta_malla_y_su_transformacion() -> void:  # 041-AC7
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var contenido: Node3D = auto_free(CONTENIDO.instantiate())
	var original: MeshInstance3D = modelo.get_node("gondola01/malbardocig")
	var copia: MeshInstance3D = contenido.get_node("Cigarrillos")
	assert_int(contenido.get_child_count()).is_equal(6)
	assert_bool(copia.transform.is_equal_approx(original.transform)).is_true()
	assert_array(copia.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]).is_equal(
		original.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	)
