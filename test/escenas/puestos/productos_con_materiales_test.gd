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


func test_la_fila_apagada_conserva_la_textura_de_cada_parte_del_producto() -> void:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	add_child(local)
	var puesto: Node3D = local.get("_reposicion_manual")
	var contenido: Node3D = puesto.get("contenido")
	for producto in Catalogo.todos():
		var original: Mesh = contenido.get_child(producto.id).mesh
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		for superficie in original.get_surface_count():
			var material := grupo.material_override as ShaderMaterial
			if material == null:
				material = grupo.multimesh.mesh.surface_get_material(superficie) as ShaderMaterial
			assert_object(material).is_not_null()
			if material == null:
				continue
			var fuente := original.surface_get_material(superficie) as BaseMaterial3D
			if fuente.albedo_texture == null:
				assert_object(material.get_shader_parameter("textura")).is_null()
			else:
				assert_object(material.get_shader_parameter("textura")).is_same(
					fuente.albedo_texture
				)
			assert_str(str(material.get_shader_parameter("color"))).is_equal(
				str(fuente.albedo_color)
			)
			assert_float(material.get_shader_parameter("rugosidad")).is_equal(fuente.roughness)
			assert_float(material.get_shader_parameter("metalico")).is_equal(fuente.metallic)
			# Lo que va antes de los casilleros es fijo, y es lo único apagado.
			var cupos: Dictionary = puesto.call("casilleros")
			var fijas: int = grupo.multimesh.instance_count - cupos[producto.id]
			assert_int(material.get_shader_parameter("hasta_atras")).is_equal(fijas)
