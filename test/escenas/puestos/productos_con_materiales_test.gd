extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_la_gondola_y_la_unidad_de_la_mano_conservan_todas_las_partes_del_producto() -> void:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	add_child(local)
	var puesto: Node3D = local.get("_reposicion_manual")
	var contenido: Node3D = puesto.get("contenido")
	var modelos: Array = puesto.get("_modelos")
	assert_int(modelos.size()).is_equal(Catalogo.todos().size())
	for producto in Catalogo.todos():
		var original: Mesh = contenido.get_child(producto.id).mesh
		var preparado: Mesh = modelos[producto.id]
		(
			assert_int(preparado.get_surface_count())
			. override_failure_message(producto.nombre)
			. is_equal(original.get_surface_count())
		)
		assert_int(preparado.get_faces().size()).override_failure_message(producto.nombre).is_equal(
			original.get_faces().size()
		)
		for superficie: int in mini(preparado.get_surface_count(), original.get_surface_count()):
			assert_object(preparado.surface_get_material(superficie)).is_same(
				original.surface_get_material(superficie)
			)
