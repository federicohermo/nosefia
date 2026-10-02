extends GdUnitTestSuite


func test_la_caja_marca_sus_aristas_y_no_las_diagonales_de_las_caras() -> void:
	var original := BoxMesh.new()
	var preparada := AristasDelProducto.preparar(original)
	var arreglos := preparada.surface_get_arrays(0)
	var coordenadas: PackedFloat32Array = arreglos[Mesh.ARRAY_CUSTOM0]
	var marcadas := 0
	for inicio in range(0, coordenadas.size(), 12):
		var mascara := int(coordenadas[inicio + 3])
		for esquina in 3:
			if mascara & (1 << esquina):
				marcadas += 1
	# Cada una de las doce aristas pertenece a dos caras; las seis diagonales no cuentan.
	assert_int(marcadas).is_equal(24)
	assert_int((arreglos[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()).is_equal(36)
	assert_object(original.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]).is_null()


func test_conserva_la_superficie_la_forma_y_los_uv_del_producto() -> void:
	var original := BoxMesh.new()
	var material := StandardMaterial3D.new()
	original.material = material
	var preparada := AristasDelProducto.preparar(original)
	assert_object(preparada.surface_get_material(0)).is_same(material)
	assert_bool(preparada.get_aabb().is_equal_approx(original.get_aabb())).is_true()
	var herramienta := SurfaceTool.new()
	herramienta.create_from(original, 0)
	herramienta.deindex()
	var antes := herramienta.commit_to_arrays()
	var despues := preparada.surface_get_arrays(0)
	for canal: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV]:
		assert_bool(antes[canal] == despues[canal]).is_true()
