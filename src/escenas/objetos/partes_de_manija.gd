extends RefCounted

const MATERIALES := ["util_asa_grafito", "util_borde_crema"]


static func preparar(original: Mesh) -> ArrayMesh:
	if not original is ArrayMesh:
		push_error("La manija necesita una malla con superficies editables")
		return null
	var preparada := (original as ArrayMesh).duplicate() as ArrayMesh
	preparada.shadow_mesh = null
	# La copia mantiene todos los buffers importados; sólo UV2 identifica qué parte gira.
	var superficies: Array = original.get("_surfaces")
	for superficie: int in original.get_surface_count():
		var material := original.surface_get_material(superficie)
		if material == null or material.resource_name not in MATERIALES:
			continue
		var formato := (original as ArrayMesh).surface_get_format(superficie)
		if (
			(formato & Mesh.ARRAY_FORMAT_TEX_UV2) == 0
			or formato & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		):
			push_error("La manija necesita UV2 flotantes para distinguir sus partes móviles")
			return null
		var marcas := _partes(original.surface_get_arrays(superficie))
		var paso := RenderingServer.mesh_surface_get_format_attribute_stride(formato, marcas.size())
		var inicio := RenderingServer.mesh_surface_get_format_offset(
			formato, marcas.size(), Mesh.ARRAY_TEX_UV2
		)
		var informacion: Dictionary = superficies[superficie].duplicate()
		var atributos: PackedByteArray = informacion["attribute_data"]
		for numero: int in marcas.size():
			atributos.encode_float(inicio + numero * paso, marcas[numero].x)
			atributos.encode_float(inicio + numero * paso + 4, marcas[numero].y)
		informacion["attribute_data"] = atributos
		superficies[superficie] = informacion
	preparada.clear_surfaces()
	preparada.set("_surfaces", superficies)
	return preparada


static func _partes(datos: Array) -> PackedVector2Array:
	var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	var padres: Array[int] = []
	var repetidos: Dictionary[Vector3, int] = {}
	for numero: int in vertices.size():
		padres.append(numero)
		if repetidos.has(vertices[numero]):
			_unir(padres, numero, repetidos[vertices[numero]])
		else:
			repetidos[vertices[numero]] = numero
	var indices := PackedInt32Array()
	if datos[Mesh.ARRAY_INDEX] != null:
		indices = datos[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array(range(vertices.size()))
	for numero: int in range(0, indices.size(), 3):
		_unir(padres, indices[numero], indices[numero + 1])
		_unir(padres, indices[numero + 1], indices[numero + 2])
	var techos: Dictionary[int, float] = {}
	for numero: int in vertices.size():
		var grupo := _grupo(padres, numero)
		techos[grupo] = maxf(techos.get(grupo, -INF), vertices[numero].y)
	var marcas := PackedVector2Array()
	marcas.resize(vertices.size())
	for numero: int in vertices.size():
		# Los apoyos, borde y logotipo son componentes bajos; arco y agarre superan 20 cm.
		marcas[numero] = Vector2(1, 0) if techos[_grupo(padres, numero)] > .2 else Vector2.ZERO
	return marcas


static func _grupo(padres: Array[int], numero: int) -> int:
	while padres[numero] != numero:
		padres[numero] = padres[padres[numero]]
		numero = padres[numero]
	return numero


static func _unir(padres: Array[int], primero: int, segundo: int) -> void:
	padres[_grupo(padres, primero)] = _grupo(padres, segundo)
