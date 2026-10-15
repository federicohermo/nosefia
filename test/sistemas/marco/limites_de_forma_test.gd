extends GdUnitTestSuite


func test_la_caja_conserva_sus_tres_dimensiones() -> void:
	var forma := BoxShape3D.new()
	forma.size = Vector3(2.0, 4.0, 6.0)
	var limites := LimitesDeForma.de(forma)
	assert_vector(limites.position).is_equal(Vector3(-1.0, -2.0, -3.0))
	assert_vector(limites.size).is_equal(Vector3(2.0, 4.0, 6.0))


func test_la_esfera_llega_al_radio_en_los_tres_ejes() -> void:
	var forma := SphereShape3D.new()
	forma.radius = 1.25
	var limites := LimitesDeForma.de(forma)
	assert_vector(limites.position).is_equal(Vector3(-1.25, -1.25, -1.25))
	assert_vector(limites.size).is_equal(Vector3(2.5, 2.5, 2.5))


func test_el_cilindro_conserva_el_diametro_y_la_altura() -> void:
	var forma := CylinderShape3D.new()
	forma.radius = 1.5
	forma.height = 4.0
	var limites := LimitesDeForma.de(forma)
	assert_vector(limites.position).is_equal(Vector3(-1.5, -2.0, -1.5))
	assert_vector(limites.size).is_equal(Vector3(3.0, 4.0, 3.0))


func test_la_capsula_incluye_los_dos_extremos_redondos() -> void:
	var forma := CapsuleShape3D.new()
	forma.radius = 0.75
	forma.height = 3.0
	var limites := LimitesDeForma.de(forma)
	assert_vector(limites.position).is_equal(Vector3(-0.75, -1.5, -0.75))
	assert_vector(limites.size).is_equal(Vector3(1.5, 3.0, 1.5))


func test_el_casco_desplazado_no_incluye_el_origen() -> void:
	var forma := ConvexPolygonShape3D.new()
	forma.points = PackedVector3Array(
		[Vector3(2, 3, 4), Vector3(5, 3, 4), Vector3(2, 6, 4), Vector3(2, 3, 8)]
	)
	var limites := LimitesDeForma.de(forma)
	assert_vector(limites.position).is_equal(Vector3(2, 3, 4))
	assert_vector(limites.size).is_equal(Vector3(3, 3, 4))


func test_las_caras_desplazadas_conservan_sus_extremos() -> void:
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(PackedVector3Array([Vector3(-5, 2, 3), Vector3(-2, 2, 3), Vector3(-5, 6, 7)]))
	var limites := LimitesDeForma.de(forma)
	assert_vector(limites.position).is_equal(Vector3(-5, 2, 3))
	assert_vector(limites.size).is_equal(Vector3(3, 4, 4))


func test_redimensionar_la_misma_forma_actualiza_su_volumen() -> void:
	var forma := BoxShape3D.new()
	forma.size = Vector3.ONE
	var limites := LimitesDeForma.de(forma)
	assert_vector(limites.position).is_equal(Vector3.ONE * -0.5)
	assert_vector(limites.size).is_equal(Vector3.ONE)
	forma.size = Vector3(4, 2, 8)
	limites = LimitesDeForma.de(forma)
	assert_vector(limites.position).is_equal(Vector3(-2, -1, -4))
	assert_vector(limites.size).is_equal(Vector3(4, 2, 8))


func test_cambiar_los_puntos_no_deja_limites_viejos() -> void:
	var forma := ConvexPolygonShape3D.new()
	forma.points = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK])
	var limites := LimitesDeForma.de(forma)
	assert_vector(limites.position).is_equal(Vector3.ZERO)
	assert_vector(limites.size).is_equal(Vector3.ONE)
	forma.points = PackedVector3Array(
		[Vector3(2, 3, 4), Vector3(5, 3, 4), Vector3(2, 6, 4), Vector3(2, 3, 8)]
	)
	limites = LimitesDeForma.de(forma)
	assert_vector(limites.position).is_equal(Vector3(2, 3, 4))
	assert_vector(limites.size).is_equal(Vector3(3, 3, 4))


func test_un_poligono_sin_vertices_no_declara_volumen() -> void:
	var limites := LimitesDeForma.de(ConvexPolygonShape3D.new())
	assert_vector(limites.position).is_equal(Vector3.ZERO)
	assert_vector(limites.size).is_equal(Vector3.ZERO)
	limites = LimitesDeForma.de(ConcavePolygonShape3D.new())
	assert_vector(limites.position).is_equal(Vector3.ZERO)
	assert_vector(limites.size).is_equal(Vector3.ZERO)
