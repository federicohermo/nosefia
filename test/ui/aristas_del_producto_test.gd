extends GdUnitTestSuite


func test_el_cilindro_reduce_las_lineas_verticales_y_conserva_los_aros() -> void:
	var cilindro := CylinderMesh.new()
	cilindro.radial_segments = 32
	cilindro.rings = 1
	cilindro.top_radius = 0.5
	cilindro.bottom_radius = 0.5
	var preparada := AristasDelProducto.preparar(cilindro)
	var arreglos := preparada.surface_get_arrays(0)
	var vertices: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
	var coordenadas: PackedFloat32Array = arreglos[Mesh.ARRAY_CUSTOM0]
	var verticales: Dictionary[Array, bool] = {}
	var aros: Dictionary[Array, bool] = {}
	for inicio in range(0, vertices.size(), 3):
		var mascara := int(coordenadas[inicio * 4 + 3])
		for esquina in 3:
			if not mascara & (1 << esquina):
				continue
			var desde := vertices[inicio + (esquina + 1) % 3].snapped(Vector3.ONE * 0.00001)
			var hasta := vertices[inicio + (esquina + 2) % 3].snapped(Vector3.ONE * 0.00001)
			if desde.y < hasta.y:
				verticales[[desde, hasta]] = true
			elif hasta.y < desde.y:
				verticales[[hasta, desde]] = true
			else:
				aros[[desde, hasta]] = true
	assert_int(verticales.size()).is_between(4, 12)
	assert_int(aros.size()).is_greater_equal(64)


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
