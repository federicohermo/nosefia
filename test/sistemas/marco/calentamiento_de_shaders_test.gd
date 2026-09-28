## El calentamiento de shaders: dibuja cada objeto una vez, un material nuevo por cuadro, y deja
## la escena como estaba.
extends GdUnitTestSuite

const CUANTOS := 20
const ESPERA_MS := 5000


## Todas las cajas comparten un material, salvo las que se le pidan con uno propio.
func _escena(con_material_propio: int = 0) -> Node3D:
	var escena: Node3D = auto_free(Node3D.new())
	var comun := StandardMaterial3D.new()
	for i: int in CUANTOS:
		var malla := MeshInstance3D.new()
		malla.mesh = BoxMesh.new()
		malla.material_override = StandardMaterial3D.new() if i < con_material_propio else comun
		malla.position = Vector3(i * 3.0, 0.0, 0.0)
		escena.add_child(malla)
	add_child(escena)
	return escena


func _visibles(escena: Node3D) -> int:
	return (
		escena
		. find_children("*", "GeometryInstance3D", true, false)
		. filter(func(objeto: GeometryInstance3D) -> bool: return objeto.visible)
		. size()
	)


func _calentamiento() -> CalentamientoDeShaders:
	var calentamiento: CalentamientoDeShaders = auto_free(CalentamientoDeShaders.new())
	add_child(calentamiento)
	return calentamiento


func test_un_cuadro_por_material_nuevo() -> void:
	var escena := _escena(3)
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	assert_int(_visibles(escena)).is_zero()
	await get_tree().process_frame
	var tras_el_primero := _visibles(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(tras_el_primero).is_less(CUANTOS)
	assert_int(_visibles(escena)).is_equal(CUANTOS)


func test_los_que_repiten_material_se_destapan_juntos() -> void:
	var escena := _escena()
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(_visibles(escena)).is_equal(CUANTOS)


func test_termina_con_todo_visible_y_la_camara_de_antes() -> void:
	var escena := _escena()
	var camara: Camera3D = auto_free(Camera3D.new())
	escena.add_child(camara)
	camara.make_current()
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	assert_object(get_viewport().get_camera_3d()).is_not_same(camara)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_int(_visibles(escena)).is_equal(CUANTOS)
	assert_float(calentamiento.progreso()).is_equal(1.0)
	assert_object(get_viewport().get_camera_3d()).is_same(camara)


func test_lo_oculto_se_dibuja_y_vuelve_a_quedar_oculto() -> void:
	var escena := _escena()
	var oculto: MeshInstance3D = escena.get_child(0)
	oculto.visible = false
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	var se_mostro := [false]
	oculto.visibility_changed.connect(func() -> void: se_mostro[0] = se_mostro[0] or oculto.visible)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(se_mostro[0]).is_true()
	assert_bool(oculto.visible).is_false()
	assert_int(_visibles(escena)).is_equal(CUANTOS - 1)


func test_una_escena_sin_objetos_termina_igual() -> void:
	var escena: Node3D = auto_free(Node3D.new())
	add_child(escena)
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_float(calentamiento.progreso()).is_equal(1.0)


func test_antes_de_calentar_no_hace_nada() -> void:
	var calentamiento := _calentamiento()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(calentamiento.is_processing()).is_false()
