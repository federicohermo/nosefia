extends GdUnitTestSuite

const MODELO := preload("res://assets/SEPT_JUEGOS_PROTOTIPO.glb")
const CONTENIDO := preload("res://src/escenas/puestos/contenido_del_estante.tscn")
const SOPORTE := preload("res://assets/models/gondola_soporte.res")
const COLISION := preload("res://assets/models/gondola_colision.res")


func test_el_mueble_conserva_todas_sus_caras_y_materiales() -> void:  # 041-AC7
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var original: ArrayMesh = modelo.get_node("gondola01").mesh
	assert_int(SOPORTE.get_surface_count()).is_equal(original.get_surface_count())
	for indice in original.get_surface_count():
		if indice >= SOPORTE.get_surface_count():
			continue
		var antes := original.surface_get_arrays(indice)
		var despues := SOPORTE.surface_get_arrays(indice)
		assert_array(despues[Mesh.ARRAY_VERTEX]).is_equal(antes[Mesh.ARRAY_VERTEX])
		assert_array(despues[Mesh.ARRAY_TEX_UV]).is_equal(antes[Mesh.ARRAY_TEX_UV])
		var material: StandardMaterial3D = SOPORTE.surface_get_material(indice)
		var previo: StandardMaterial3D = original.surface_get_material(indice)
		assert_object(material.albedo_texture).is_same(previo.albedo_texture)
		assert_float(material.roughness).is_equal(previo.roughness)
		assert_int(material.cull_mode).is_equal(previo.cull_mode)


func test_la_colision_corresponde_al_mueble_completo() -> void:  # 041-AC3
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var original: ArrayMesh = modelo.get_node("gondola01").mesh
	assert_array(COLISION.get_faces()).is_equal(original.get_faces())


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


func test_reponer_recupera_los_productos_independientes_del_modelo() -> void:  # 041-AC9
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var contenido: Node3D = auto_free(CONTENIDO.instantiate())
	var gondola: MeshInstance3D = modelo.get_node("gondola01")
	var vertices: Array[Vector3] = []
	var cantidad_original := 0
	for grupo: MeshInstance3D in contenido.get_children():
		for superficie in grupo.mesh.get_surface_count():
			for vertice: Vector3 in grupo.mesh.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX]:
				vertices.append(gondola.transform * grupo.transform * vertice)
	for nombre in [
		"at\u00fan",
		"at\u00fan_02",
		"durextra",
		"snackpapas1",
		"snacks2",
		"snacks2_02",
		"snacks2_03",
		"snacks2_04",
		"burgaloo",
		"burgaloo_001",
		"burgaloo_002",
		"burgaloo_003",
		"Zucarachas",
		"Zucarachas2"
	]:
		var producto: MeshInstance3D = modelo.get_node(nombre)
		var ausentes := 0
		for superficie in producto.mesh.get_surface_count():
			for vertice: Vector3 in producto.mesh.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX]:
				cantidad_original += 1
				var esperado := producto.transform * vertice
				if not vertices.any(
					func(copia: Vector3) -> bool: return copia.is_equal_approx(esperado)
				):
					ausentes += 1
		assert_int(ausentes).override_failure_message("%s: %d" % [nombre, ausentes]).is_zero()

	var cigarrillos: MeshInstance3D = modelo.get_node("gondola01/malbardocig")
	for superficie in cigarrillos.mesh.get_surface_count():
		cantidad_original += (
			cigarrillos.mesh.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX].size()
		)
	assert_int(vertices.size()).is_equal(cantidad_original)
