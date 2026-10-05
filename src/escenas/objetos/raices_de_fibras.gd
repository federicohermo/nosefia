extends RefCounted


static func preparar(original: Mesh) -> ArrayMesh:
	# Las UV de lightmap del modelo permanecen en el recurso importado. La copia dinámica
	# usa su segundo canal para el anclaje real de cada hebra, incluso en cantos con normales partidas.
	var preparada := (original as ArrayMesh).duplicate() as ArrayMesh
	preparada.shadow_mesh = null
	# Godot conserva sus superficies serializadas en _surfaces. Usar esos buffers evita
	# una segunda cuantización de normales al recrearlas desde surface_get_arrays().
	var superficies: Array = original.get("_surfaces")
	for superficie in original.get_surface_count():
		var material := original.surface_get_material(superficie)
		if material == null or not material.resource_name.begins_with("util_fibra"):
			continue
		var formato := (original as ArrayMesh).surface_get_format(superficie)
		if not formato & Mesh.ARRAY_FORMAT_TEX_UV2 or formato & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES:
			push_error("La mopa necesita UV2 flotantes para anclar sus fibras")
			return null
		var raices := _raices(original.surface_get_arrays(superficie))
		var paso := RenderingServer.mesh_surface_get_format_attribute_stride(formato, raices.size())
		var inicio := RenderingServer.mesh_surface_get_format_offset(
			formato, raices.size(), Mesh.ARRAY_TEX_UV2
		)
		var informacion: Dictionary = superficies[superficie].duplicate()
		var atributos: PackedByteArray = informacion["attribute_data"]
		for numero in raices.size():
			atributos.encode_float(inicio + numero * paso, raices[numero].x)
			atributos.encode_float(inicio + numero * paso + 4, raices[numero].y)
		# Actualizar sólo UV2 evita volver a cuantizar normales y tangentes ya importadas.
		informacion["attribute_data"] = atributos
		superficies[superficie] = informacion
	preparada.clear_surfaces()
	preparada.set("_surfaces", superficies)
	return preparada


static func _raices(datos: Array) -> PackedVector2Array:
	var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	var padres: Array[int] = []
	var repetidos: Dictionary[Vector3, int] = {}
	for numero in vertices.size():
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
	for numero in range(0, indices.size(), 3):
		_unir(padres, indices[numero], indices[numero + 1])
		_unir(padres, indices[numero + 1], indices[numero + 2])
	var grupos: Dictionary[int, Array] = {}
	for numero in vertices.size():
		var grupo := _grupo(padres, numero)
		if not grupos.has(grupo):
			grupos[grupo] = []
		grupos[grupo].append(numero)
	var raices := PackedVector2Array()
	raices.resize(vertices.size())
	for grupo: Array in grupos.values():
		var techo := -INF
		for numero: int in grupo:
			techo = maxf(techo, vertices[numero].y)
		var anillo: Dictionary[Vector3, bool] = {}
		for numero: int in grupo:
			if absf(vertices[numero].y - techo) < 0.000001:
				anillo[vertices[numero]] = true
		var centro := Vector3.ZERO
		for vertice: Vector3 in anillo:
			centro += vertice
		centro /= anillo.size()
		for numero: int in grupo:
			raices[numero] = Vector2(centro.x, centro.z)
	return raices


static func _grupo(padres: Array[int], numero: int) -> int:
	while padres[numero] != numero:
		padres[numero] = padres[padres[numero]]
		numero = padres[numero]
	return numero


static func _unir(padres: Array[int], primero: int, segundo: int) -> void:
	padres[_grupo(padres, primero)] = _grupo(padres, segundo)
