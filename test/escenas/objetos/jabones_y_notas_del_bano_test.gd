extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const UtilDeLimpieza := preload("res://src/escenas/objetos/util_de_limpieza.gd")
const NOTAS: Array[String] = ["nota baño inodoro", "nota instrucciones", "nota productos"]


func test_las_botellas_entran_en_su_colision_y_conservan_tres_etiquetas() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var etiquetas: Array[Texture2D] = []
	for nombre: String in ["JabonAzul", "JabonRosa", "JabonAmarillo"]:
		var jabon: UtilDeLimpieza = almacen.get_node("Objetos/" + nombre)
		var volumen: AABB = jabon.malla.transform * jabon.malla.mesh.get_aabb()
		assert_float(volumen.size.y).is_between(0.65, 0.67)
		assert_float(volumen.size.x).is_between(0.33, 0.35)
		var forma: CollisionShape3D = jabon.get_node("Forma")
		var cilindro: CylinderShape3D = forma.shape
		assert_float(cilindro.height).is_equal_approx(volumen.size.y, 0.001)
		assert_float(cilindro.radius * 2.0).is_greater_equal(volumen.size.x - 0.001)
		var textura: Texture2D = null
		for superficie in jabon.malla.mesh.get_surface_count():
			var material: StandardMaterial3D = jabon.malla.mesh.surface_get_material(superficie)
			if material.albedo_texture != null:
				textura = material.albedo_texture
				# El cuerpo lleva la imagen propia; las tapas comparten el atlas blanco.
				break
		assert_object(textura).override_failure_message(nombre).is_not_null()
		assert_bool(etiquetas.has(textura)).override_failure_message(nombre).is_false()
		etiquetas.append(textura)


func test_las_tres_notas_se_ven_en_el_bano_con_sus_imagenes() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	for nombre: String in NOTAS:
		var nota: MeshInstance3D = almacen.get_node_or_null("Estructura/" + nombre)
		assert_object(nota).override_failure_message(nombre).is_not_null()
		if nota == null:
			continue
		assert_bool(nota.is_visible_in_tree()).is_true()
		var alto_minimo := 0.3 if nombre == NOTAS[0] else 1.1
		assert_float(nota.mesh.get_aabb().size.y).is_greater(alto_minimo)
		assert_float(nota.global_position.x).is_between(8.0, 13.5)
		assert_float(nota.global_position.z).is_between(-8.0, -1.27768)
		assert_float(nota.global_position.y).is_between(1.2, 1.9)
		var centro := nota.to_global(nota.mesh.get_aabb().get_center())
		var frente := Vector3.FORWARD if nombre == NOTAS[0] else Vector3.BACK
		var rayo := PhysicsRayQueryParameters3D.create(centro + frente, centro, 1)
		var choque := almacen.get_world_3d().direct_space_state.intersect_ray(rayo)
		assert_bool(choque.is_empty()).is_false()
		assert_object((choque["collider"] as Node).get_parent()).is_equal(nota)
		var imagenes: Array[Texture2D] = []
		for superficie in nota.mesh.get_surface_count():
			var material: StandardMaterial3D = nota.mesh.surface_get_material(superficie)
			if material.albedo_texture != null:
				imagenes.append(material.albedo_texture)
		assert_int(imagenes.size()).override_failure_message(nombre).is_greater_equal(2)
