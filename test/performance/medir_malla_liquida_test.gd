extends GdUnitTestSuite

const Medicion := preload("res://test/performance/medir_malla_liquida.gd")
const Superficie := preload("res://src/escenas/objetos/superficie_liquida.gd")


func _superficies() -> Array[Superficie]:
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	return [Medicion.crear(raiz, true), Medicion.crear(raiz, false)]


func test_las_poses_cruzan_cuatro_niveles_con_tres_fases_sin_repetir() -> void:
	var vistas := {}
	for pose: Dictionary in Medicion.poses():
		assert_bool(Medicion.NIVELES.has(pose.nivel)).is_true()
		assert_bool(Medicion.FASES.has(pose.fase)).is_true()
		vistas["%s/%s" % [pose.nivel, pose.fase]] = true
	assert_int(vistas.size()).is_equal(Medicion.NIVELES.size() * Medicion.FASES.size())


func test_cada_pose_dibuja_la_malla_entera_y_deja_activa_la_superficie() -> void:
	for superficie: Superficie in _superficies():
		for pose: Dictionary in Medicion.poses():
			(superficie.mesh as ArrayMesh).clear_surfaces()
			Medicion.posar(superficie, pose.nivel, pose.fase)
			var huella := Medicion.huella(superficie)
			assert_int(huella.superficies).is_equal(1)
			assert_int(huella.vertices).is_equal(1 + Superficie.ANILLOS * Superficie.SEGMENTOS)
			assert_bool(superficie.get("_estaba_quieta")).is_false()


func test_el_nivel_cambia_la_malla_del_balde_y_la_fase_la_de_la_mancha() -> void:
	var superficies := _superficies()
	for caso: Array in [[superficies[0], 0.2, 0.0], [superficies[1], 1.0, 7.0]]:
		var superficie: Superficie = caso[0]
		Medicion.posar(superficie, 1.0, 0.0)
		var llena: String = Medicion.huella(superficie).vertices_sha256
		Medicion.posar(superficie, caso[1], caso[2])
		assert_str(Medicion.huella(superficie).vertices_sha256).is_not_equal(llena)


func test_el_pedido_transitorio_ve_un_array_que_nace_y_muere_en_la_llamada() -> void:
	assert_bool(OS.is_debug_build()).is_true()
	assert_int(Medicion.pedido_transitorio(func() -> void: pass)).is_equal(0)
	var elementos := 1 + Superficie.ANILLOS * Superficie.SEGMENTOS
	var pedido := Medicion.pedido_transitorio(
		func() -> void:
			var temporal := PackedVector3Array()
			temporal.resize(elementos)
	)
	assert_int(pedido).is_between(elementos * 12, elementos * 12 + 256)
