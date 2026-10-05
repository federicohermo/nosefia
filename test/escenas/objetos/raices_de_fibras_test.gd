extends GdUnitTestSuite

const Raices := preload("res://src/escenas/objetos/raices_de_fibras.gd")
const Util := preload("res://src/escenas/objetos/util_de_limpieza.gd")


func test_las_caras_separadas_por_normales_comparten_la_raiz_de_su_fibra() -> void:
	var original := _dos_fibras()
	var preparada := Raices.preparar(original)
	var datos := preparada.surface_get_arrays(0)
	var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	var raices: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV2]
	assert_int(raices.size()).is_equal(vertices.size())
	for numero in vertices.size():
		var esperada := Vector2(0.08, 0.02) if vertices[numero].x < 0.15 else Vector2(0.25, 0.06)
		assert_vector(raices[numero]).is_equal_approx(esperada, Vector2.ONE * 0.000001)
	assert_bool(preparada.get_aabb().is_equal_approx(original.get_aabb())).is_true()


func test_la_metadata_no_cambia_la_malla_importada_ni_los_materiales_del_modelo() -> void:
	var original := Util.malla_del_modelo(&"mopa")
	var antes: Array[Array] = []
	for superficie in original.get_surface_count():
		antes.append(original.surface_get_arrays(superficie).duplicate(true))
	var preparada := Raices.preparar(original)
	assert_object(preparada).is_not_same(original)
	assert_int(preparada.get_surface_count()).is_equal(original.get_surface_count())
	assert_object(preparada.shadow_mesh).is_null()
	var buffers_antes: Array = original.get("_surfaces")
	var buffers_despues: Array = preparada.get("_surfaces")
	var anclas: Dictionary[Vector2, bool] = {}
	for superficie in original.get_surface_count():
		var material := original.surface_get_material(superficie)
		assert_object(preparada.surface_get_material(superficie)).is_same(material)
		assert_bool(original.surface_get_arrays(superficie) == antes[superficie]).is_true()
		for campo: String in buffers_antes[superficie]:
			if campo != "attribute_data":
				(
					assert_bool(
						buffers_antes[superficie][campo] == buffers_despues[superficie][campo]
					)
					. is_true()
				)
		var despues := preparada.surface_get_arrays(superficie)
		for canal in Mesh.ARRAY_MAX:
			if canal != Mesh.ARRAY_TEX_UV2:
				assert_bool(despues[canal] == antes[superficie][canal]).is_true()
		if material.resource_name.begins_with("util_fibra"):
			var raices: PackedVector2Array = despues[Mesh.ARRAY_TEX_UV2]
			var vertices: PackedVector3Array = despues[Mesh.ARRAY_VERTEX]
			assert_int(raices.size()).is_equal(vertices.size())
			for raiz: Vector2 in raices:
				assert_float(raiz.length()).is_between(0.07, 0.11)
				anclas[raiz] = true
		else:
			(
				assert_bool(despues[Mesh.ARRAY_TEX_UV2] == antes[superficie][Mesh.ARRAY_TEX_UV2])
				. is_true()
			)
	assert_int(anclas.size()).is_equal(32)


func _dos_fibras() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var uv := PackedVector2Array()
	var anteriores := PackedVector2Array()
	for centro: Vector2 in [Vector2(0.08, 0.02), Vector2(0.25, 0.06)]:
		for lado in 5:
			var puntos := PackedVector3Array()
			for indice: int in [lado, (lado + 1) % 5]:
				var giro := TAU * indice / 5.0
				puntos.append(
					Vector3(centro.x + cos(giro) * 0.01, -0.774, centro.y + sin(giro) * 0.01)
				)
				puntos.append(
					Vector3(centro.x + cos(giro) * 0.02, -0.8518224, centro.y + sin(giro) * 0.02)
				)
			for indice: int in [0, 2, 1, 1, 2, 3]:
				vertices.append(puntos[indice])
				normales.append(Vector3(cos(TAU * lado / 5.0), 0, sin(TAU * lado / 5.0)))
				uv.append(Vector2.ZERO)
				anteriores.append(Vector2(0.123, 0.456))
	var datos: Array = []
	datos.resize(Mesh.ARRAY_MAX)
	datos[Mesh.ARRAY_VERTEX] = vertices
	datos[Mesh.ARRAY_NORMAL] = normales
	datos[Mesh.ARRAY_TEX_UV] = uv
	datos[Mesh.ARRAY_TEX_UV2] = anteriores
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, datos)
	var material := StandardMaterial3D.new()
	material.resource_name = "util_fibra_prueba"
	malla.surface_set_material(0, material)
	return malla
