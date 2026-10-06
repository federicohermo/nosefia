extends GdUnitTestSuite

const Partes := preload("res://src/escenas/objetos/partes_de_manija.gd")
const Util := preload("res://src/escenas/objetos/util_de_limpieza.gd")
const MATERIALES := ["util_asa_grafito", "util_borde_crema"]


func test_la_costura_de_normales_no_separa_los_extremos_del_arco_movil() -> void:
	for nombre: String in MATERIALES:
		var original := _con_costura(nombre)
		var preparada := Partes.preparar(original)
		var datos := preparada.surface_get_arrays(0)
		var marcas: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV2]
		for indice: int in 9:
			assert_vector(marcas[indice]).is_equal(Vector2(1, 0) if indice < 6 else Vector2.ZERO)
		(
			assert_bool(
				datos[Mesh.ARRAY_VERTEX] == original.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			)
			. is_true()
		)
		(
			assert_bool(
				datos[Mesh.ARRAY_NORMAL] == original.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
			)
			. is_true()
		)
	var ajena := _con_costura("util_plastico_azul")
	(
		assert_bool(Partes.preparar(ajena).surface_get_arrays(0) == ajena.surface_get_arrays(0))
		. is_true()
	)


func test_el_balde_real_conserva_todos_los_buffers_salvo_uv2_de_las_dos_partes() -> void:
	var original := Util.malla_del_modelo(&"balde") as ArrayMesh
	var originales: Array = original.get("_surfaces").duplicate(true)
	var preparada := Partes.preparar(original)
	assert_object(preparada).is_not_same(original)
	assert_object(preparada.shadow_mesh).is_null()
	assert_int(preparada.get_surface_count()).is_equal(original.get_surface_count())
	assert_bool(original.get("_surfaces") == originales).is_true()
	var finales: Array = preparada.get("_surfaces")
	var encontradas := 0
	for superficie: int in original.get_surface_count():
		var material := original.surface_get_material(superficie)
		assert_object(preparada.surface_get_material(superficie)).is_same(material)
		var seleccionada: bool = material.resource_name in MATERIALES
		for campo: String in originales[superficie]:
			if campo != "attribute_data" or not seleccionada:
				assert_bool(originales[superficie][campo] == finales[superficie][campo]).is_true()
		var antes := original.surface_get_arrays(superficie)
		var despues := preparada.surface_get_arrays(superficie)
		for canal: int in Mesh.ARRAY_MAX:
			if canal != Mesh.ARRAY_TEX_UV2 or not seleccionada:
				assert_bool(antes[canal] == despues[canal]).is_true()
		if not seleccionada:
			continue
		encontradas += 1
		_verificar_bytes_ajenos_a_uv2(
			original, superficie, originales[superficie], finales[superficie]
		)
		var esperadas := _marcas_por_conectividad(antes)
		var marcas: PackedVector2Array = despues[Mesh.ARRAY_TEX_UV2]
		assert_bool(marcas == esperadas).is_true()
		assert_bool(Vector2(1, 0) in marcas).is_true()
		assert_bool(Vector2.ZERO in marcas).is_true()
	assert_int(encontradas).is_equal(2)
	assert_bool(original.get("_surfaces") == originales).is_true()


func _verificar_bytes_ajenos_a_uv2(
	malla: ArrayMesh, superficie: int, antes: Dictionary, despues: Dictionary
) -> void:
	var vertices: PackedVector3Array = malla.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX]
	var formato := malla.surface_get_format(superficie)
	var paso := RenderingServer.mesh_surface_get_format_attribute_stride(formato, vertices.size())
	var inicio := RenderingServer.mesh_surface_get_format_offset(
		formato, vertices.size(), Mesh.ARRAY_TEX_UV2
	)
	var origen: PackedByteArray = antes["attribute_data"]
	var final: PackedByteArray = despues["attribute_data"]
	var mascara := PackedByteArray()
	mascara.resize(origen.size())
	for indice: int in vertices.size():
		for byte: int in 8:
			mascara[inicio + indice * paso + byte] = 1
	for indice: int in origen.size():
		if mascara[indice] == 0:
			assert_int(final[indice]).is_equal(origen[indice])


func _marcas_por_conectividad(datos: Array) -> PackedVector2Array:
	# Una búsqueda por posiciones verifica también los vértices duplicados por normales partidas.
	var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = datos[Mesh.ARRAY_INDEX]
	var vecinos: Dictionary[Vector3, Array] = {}
	for vertice: Vector3 in vertices:
		vecinos[vertice] = []
	for inicio: int in range(0, indices.size(), 3):
		for lado: int in 3:
			var a := vertices[indices[inicio + lado]]
			var b := vertices[indices[inicio + (lado + 1) % 3]]
			vecinos[a].append(b)
			vecinos[b].append(a)
	var marcas: Dictionary[Vector3, Vector2] = {}
	for vertice: Vector3 in vecinos:
		if marcas.has(vertice):
			continue
		var recorrer: Array[Vector3] = [vertice]
		var grupo: Dictionary[Vector3, bool] = {vertice: true}
		var techo := vertice.y
		while not recorrer.is_empty():
			var actual: Vector3 = recorrer.pop_back()
			techo = maxf(techo, actual.y)
			for vecino: Vector3 in vecinos[actual]:
				if not grupo.has(vecino):
					grupo[vecino] = true
					recorrer.append(vecino)
		for punto: Vector3 in grupo:
			marcas[punto] = Vector2(1, 0) if techo > .2 else Vector2.ZERO
	var resultado := PackedVector2Array()
	for vertice: Vector3 in vertices:
		resultado.append(marcas[vertice])
	return resultado


func _con_costura(nombre: String) -> ArrayMesh:
	var vertices := PackedVector3Array(
		[
			Vector3(0, .1, 0),
			Vector3(.02, .1, 0),
			Vector3(0, .3, 0),
			Vector3(0, .1, 0),
			Vector3(.02, .1, 0),
			Vector3(0, .15, .02),
			Vector3(1, .1, 0),
			Vector3(1.02, .1, 0),
			Vector3(1, .15, 0),
		]
	)
	var normales := PackedVector3Array()
	var uv := PackedVector2Array()
	for indice: int in vertices.size():
		normales.append(Vector3.FORWARD if indice < 3 else Vector3.UP)
		uv.append(Vector2(.123, .456))
	var datos: Array = []
	datos.resize(Mesh.ARRAY_MAX)
	datos[Mesh.ARRAY_VERTEX] = vertices
	datos[Mesh.ARRAY_NORMAL] = normales
	datos[Mesh.ARRAY_TEX_UV] = uv
	datos[Mesh.ARRAY_TEX_UV2] = uv
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, datos)
	var material := StandardMaterial3D.new()
	material.resource_name = nombre
	malla.surface_set_material(0, material)
	return malla
