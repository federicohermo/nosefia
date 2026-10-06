extends GdUnitTestSuite

const MODELO := preload("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")


func test_las_cuatro_ranuras_siguen_visibles_en_cada_nivel_de_detalle() -> void:
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var puerta := modelo.find_child("puerta2", true, false) as MeshInstance3D
	assert_object(puerta).is_not_null()
	if puerta == null:
		return
	assert_float(puerta.position.y).is_equal_approx(1.477237, .00001)
	var niveles: Array[float] = [0.0]
	for superficie in puerta.mesh.get_surface_count():
		var datos := RenderingServer.mesh_get_surface(puerta.mesh.get_rid(), superficie)
		for lod: Dictionary in datos.get("lods", []):
			var umbral: float = lod.edge_length
			if umbral not in niveles:
				niveles.append(umbral)
	niveles.sort()
	for nivel in niveles:
		for altura: float in [.35, .41, .47, .53]:
			for x: float in [-.2, 0.0, .2]:
				_comprobar_ranura(puerta.mesh, nivel, x, altura - puerta.position.y)


func _comprobar_ranura(malla: Mesh, nivel: float, x: float, y: float) -> void:
	var golpe := _golpe(malla, nivel, Vector3(x, y, .2))
	assert_bool(golpe.is_empty()).is_false()
	if golpe.is_empty():
		return
	var pintura := malla.surface_get_material(golpe.superficie) as BaseMaterial3D
	assert_object(pintura).is_not_null()
	if pintura == null:
		return
	# El primer triángulo visible tiene que dibujar la ranura, no quedar delante de ella.
	assert_object(pintura.albedo_texture).is_not_null()
	if pintura.albedo_texture == null:
		return
	var imagen := pintura.albedo_texture.get_image()
	assert_object(imagen).is_not_null()
	if imagen == null:
		return
	if imagen.is_compressed():
		assert_int(imagen.decompress()).is_equal(OK)
	var ranura := _pixel(imagen, golpe.uv)
	for desplazamiento: float in [-.03, .03]:
		var entre := _golpe(malla, nivel, Vector3(x, y + desplazamiento, .2))
		assert_bool(entre.is_empty()).is_false()
		if entre.is_empty():
			continue
		var otra := malla.surface_get_material(entre.superficie) as BaseMaterial3D
		assert_object(otra.albedo_texture).is_same(pintura.albedo_texture)
		if otra.albedo_texture != pintura.albedo_texture:
			continue
		var blanco := _pixel(imagen, entre.uv)
		assert_float(blanco.get_luminance() - ranura.get_luminance()).is_greater(.1)


func _pixel(imagen: Image, uv: Vector2) -> Color:
	var x := clampi(int(uv.x * imagen.get_width()), 0, imagen.get_width() - 1)
	var y := clampi(int(uv.y * imagen.get_height()), 0, imagen.get_height() - 1)
	return imagen.get_pixel(x, y)


func _golpe(malla: Mesh, nivel: float, origen: Vector3) -> Dictionary:
	var salida: Dictionary = {}
	var distancia := .4
	for superficie in malla.get_surface_count():
		var arrays := malla.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var coordenadas: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var datos := RenderingServer.mesh_get_surface(malla.get_rid(), superficie)
		for lod: Dictionary in datos.get("lods", []):
			if float(lod.edge_length) <= nivel:
				indices = _indices(lod.index_data, vertices.size())
		for inicio in range(0, indices.size(), 3):
			var a := vertices[indices[inicio]]
			var b := vertices[indices[inicio + 1]]
			var c := vertices[indices[inicio + 2]]
			var golpe: Variant = Geometry3D.ray_intersects_triangle(
				origen, Vector3.FORWARD, a, b, c
			)
			if golpe == null:
				continue
			var punto: Vector3 = golpe
			var recorrido := origen.z - punto.z
			if recorrido < 0.0 or recorrido >= distancia:
				continue
			distancia = recorrido
			var lados := Vector2((b - a).dot(b - a), (b - a).dot(c - a))
			var ultimo := (c - a).dot(c - a)
			var d := Vector2((punto - a).dot(b - a), (punto - a).dot(c - a))
			var denominador := lados.x * ultimo - lados.y * lados.y
			var pesos := (
				Vector2(ultimo * d.x - lados.y * d.y, lados.x * d.y - lados.y * d.x) / denominador
			)
			var uv := coordenadas[indices[inicio]] * (1.0 - pesos.x - pesos.y)
			uv += coordenadas[indices[inicio + 1]] * pesos.x
			uv += coordenadas[indices[inicio + 2]] * pesos.y
			salida = {"superficie": superficie, "uv": uv}
	return salida


func _indices(datos: PackedByteArray, vertices: int) -> PackedInt32Array:
	var salida := PackedInt32Array()
	var paso := 2 if vertices < 65536 else 4
	for inicio in range(0, datos.size(), paso):
		salida.append(datos.decode_u16(inicio) if paso == 2 else datos.decode_u32(inicio))
	return salida
