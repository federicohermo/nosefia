## Conserva el lector del almacén en una escena propia para poder retirarlo en la tercera noche.
## Se ejecuta después de exportar e importar el modelo completo.
extends SceneTree


func _initialize() -> void:
	_extraer.call_deferred()


func _extraer() -> void:
	var escena: PackedScene = load("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")
	var modelo: Node3D = escena.instantiate()
	root.add_child(modelo)
	var lector: MeshInstance3D = modelo.get_node("EscritorioComputadora/lector de productos")
	var base := lector.global_basis
	var normal := base.inverse().transposed()
	var reflejado := base.determinant() < 0.0
	var malla := ArrayMesh.new()
	for superficie: int in lector.mesh.get_surface_count():
		var datos := lector.mesh.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
		for indice: int in vertices.size():
			vertices[indice] = base * vertices[indice]
		datos[Mesh.ARRAY_VERTEX] = vertices
		var normales: PackedVector3Array = datos[Mesh.ARRAY_NORMAL]
		for indice: int in normales.size():
			normales[indice] = (normal * normales[indice]).normalized()
		datos[Mesh.ARRAY_NORMAL] = normales
		var tangentes: PackedFloat32Array = datos[Mesh.ARRAY_TANGENT]
		for indice: int in range(0, tangentes.size(), 4):
			var tangente := (
				(base * Vector3(tangentes[indice], tangentes[indice + 1], tangentes[indice + 2]))
				. normalized()
			)
			tangentes[indice] = tangente.x
			tangentes[indice + 1] = tangente.y
			tangentes[indice + 2] = tangente.z
			if reflejado:
				tangentes[indice + 3] *= -1.0
		datos[Mesh.ARRAY_TANGENT] = tangentes
		var indices: PackedInt32Array = datos[Mesh.ARRAY_INDEX]
		if reflejado:
			for indice: int in range(0, indices.size(), 3):
				var anterior := indices[indice + 1]
				indices[indice + 1] = indices[indice + 2]
				indices[indice + 2] = anterior
		datos[Mesh.ARRAY_INDEX] = indices
		malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, datos)
		malla.surface_set_material(superficie, lector.mesh.surface_get_material(superficie))
	var guardado := ResourceSaver.save(malla, "res://assets/models/lector_del_almacen.res")
	assert(guardado == OK)
	guardado = ResourceSaver.save(
		malla.create_convex_shape(true, false),
		"res://assets/models/lector_del_almacen_colision.res"
	)
	assert(guardado == OK)
	modelo.free()
	quit()
