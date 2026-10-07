extends GdUnitTestSuite

const Medicion := preload("res://test/performance/medir_malla_liquida.gd")
const Superficie := preload("res://src/escenas/objetos/superficie_liquida.gd")
const ELEMENTOS := 1 + Superficie.ANILLOS * Superficie.SEGMENTOS


func _superficie(en_balde: bool) -> Superficie:
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	return Medicion.crear(raiz, en_balde)


func _normales_de_la_malla(superficie: Superficie) -> PackedVector3Array:
	return superficie.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]


func test_las_normales_viven_en_un_buffer_del_tamano_de_la_malla_que_no_se_reemplaza() -> void:
	for en_balde: bool in [true, false]:
		var superficie := _superficie(en_balde)
		var normales: PackedVector3Array = superficie.get("_normales")
		assert_int(normales.size()).is_equal(ELEMENTOS)
		for pose: Dictionary in Medicion.poses():
			Medicion.posar(superficie, pose.nivel, pose.fase)
			assert_bool(is_same(normales, superficie.get("_normales"))).is_true()
		(superficie.mesh as ArrayMesh).clear_surfaces()
		Medicion.posar(superficie, 1.0, 7.0)
		assert_bool(is_same(normales, superficie.get("_normales"))).is_true()
		assert_int(normales.size()).is_equal(ELEMENTOS)


func test_el_buffer_de_normales_es_el_de_la_malla_en_cada_pose() -> void:
	for en_balde: bool in [true, false]:
		var superficie := _superficie(en_balde)
		var anteriores := PackedVector3Array()
		for pose: Vector2 in [Vector2(1.0, 0.0), Vector2(0.2, 7.0)]:
			Medicion.posar(superficie, pose.x, pose.y)
			var normales: PackedVector3Array = superficie.get("_normales")
			var leidas := _normales_de_la_malla(superficie)
			assert_int(normales.size()).is_equal(leidas.size())
			# La malla guarda cada normal en dos enteros de 16 bits: la diferencia es ese redondeo.
			var mayor := 0.0
			for indice: int in normales.size():
				mayor = maxf(mayor, normales[indice].distance_to(leidas[indice]))
			assert_float(mayor).is_less(0.0001)
			assert_bool(leidas == anteriores).is_false()
			anteriores = leidas


func test_cada_superficie_escribe_su_propio_buffer_de_normales() -> void:
	var una := _superficie(true)
	var otra := _superficie(true)
	Medicion.posar(otra, 1.0, 0.0)
	var de_la_otra: PackedVector3Array = otra.get("_normales")
	var copia := de_la_otra.duplicate()
	assert_int(copia.size()).is_equal(ELEMENTOS)
	Medicion.posar(una, 0.2, 0.0)
	assert_bool(is_same(una.get("_normales"), de_la_otra)).is_false()
	assert_bool(de_la_otra == copia).is_true()
	assert_bool(una.get("_normales") == copia).is_false()


func test_un_dibujo_activo_no_pide_mas_memoria_que_la_conversion_que_sube() -> void:
	var superficie := _superficie(false)
	# Sin pantalla la superficie se recrea en cada dibujo: acá se mide el camino que la actualiza.
	superficie.set("_recrea_la_superficie", false)
	var vertices: PackedVector3Array = superficie.get("_vertices")
	var conversion := Medicion.pedido_transitorio(vertices.to_byte_array)
	var arrays_de_creacion := Medicion.pedido_transitorio(
		func() -> void:
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
	)
	assert_int(conversion).is_greater_equal(ELEMENTOS * 12)
	assert_int(arrays_de_creacion).is_greater(0)
	var pedido := Medicion.pedido_transitorio(Callable(superficie, "_dibujar"))
	assert_bool(superficie.get("_estaba_quieta")).is_false()
	assert_int(superficie.mesh.get_surface_count()).is_equal(1)
	assert_int(pedido - conversion).is_less(arrays_de_creacion)


func test_quitar_las_superficies_reconstruye_la_misma_malla() -> void:
	for en_balde: bool in [true, false]:
		var superficie := _superficie(en_balde)
		Medicion.posar(superficie, 1.0, 7.0)
		var antes := Medicion.huella(superficie)
		# Desde acá sólo se crea la superficie si falta, como con un renderizador real.
		superficie.set("_recrea_la_superficie", false)
		(superficie.mesh as ArrayMesh).clear_surfaces()
		assert_int(superficie.mesh.get_surface_count()).is_equal(0)
		Medicion.posar(superficie, 1.0, 7.0)
		assert_dict(Medicion.huella(superficie)).is_equal(antes)


func test_el_agua_quieta_no_se_vuelve_a_dibujar_hasta_que_se_mueve() -> void:
	for en_balde: bool in [true, false]:
		var superficie := _superficie(en_balde)
		superficie.set("_onda", 0.0)
		superficie.set("_pendiente", Vector2.ZERO)
		superficie.call("_dibujar")
		(superficie.mesh as ArrayMesh).clear_surfaces()
		superficie.call("_dibujar")
		assert_int(superficie.mesh.get_surface_count()).is_equal(0)
		superficie.set("_onda", 1.0)
		superficie.call("_dibujar")
		assert_int(superficie.mesh.get_surface_count()).is_equal(1)
