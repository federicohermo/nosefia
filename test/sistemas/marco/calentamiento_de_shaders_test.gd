## El calentamiento de shaders: dibuja cada objeto una vez, un material nuevo por cuadro, y deja
## la escena como estaba.
extends GdUnitTestSuite

const CUANTOS := 20
const ESPERA_MS := 5000


class MallaConContorno:
	extends MeshInstance3D

	var borde := ShaderMaterial.new()

	func _init() -> void:
		mesh = BoxMesh.new()
		material_override = StandardMaterial3D.new()
		borde.shader = preload("res://src/sistemas/marco/contorno.gdshader")
		borde.set_shader_parameter("grosor", .023)
		borde.set_shader_parameter("color", Color.CYAN)

	func mostrar_contorno(presentacion: ShaderMaterial) -> void:
		material_override.next_pass = borde if presentacion != null else null
		if presentacion != null:
			borde.set_shader_parameter("grosor", presentacion.get_shader_parameter("grosor"))
			borde.set_shader_parameter("color", presentacion.get_shader_parameter("color"))


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
	var por_cuadro: Array[int] = []
	for _cuadro: int in 4:
		await calentamiento.avanzo
		por_cuadro.append(_visibles(escena))
	assert_array(por_cuadro).is_equal([1, CUANTOS - 2, CUANTOS - 1, CUANTOS])


func test_el_material_de_un_multimesh_cuenta_como_nuevo() -> void:
	var escena: Node3D = auto_free(Node3D.new())
	for _i: int in 3:
		var malla := BoxMesh.new()
		malla.material = StandardMaterial3D.new()
		var instancias := MultiMeshInstance3D.new()
		instancias.multimesh = MultiMesh.new()
		instancias.multimesh.mesh = malla
		escena.add_child(instancias)
	add_child(escena)
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	await calentamiento.avanzo
	await calentamiento.avanzo
	assert_int(_visibles(escena)).is_equal(2)


func test_el_material_reemplazado_en_una_superficie_cuenta_como_nuevo() -> void:
	var escena: Node3D = auto_free(Node3D.new())
	var comun := BoxMesh.new()
	comun.material = StandardMaterial3D.new()
	for _i: int in 3:
		var malla := MeshInstance3D.new()
		malla.mesh = comun
		malla.set_surface_override_material(0, ShaderMaterial.new())
		escena.add_child(malla)
	add_child(escena)
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	await calentamiento.avanzo
	await calentamiento.avanzo
	assert_int(_visibles(escena)).is_equal(2)


func test_los_que_repiten_material_se_destapan_juntos() -> void:
	var escena := _escena()
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	await calentamiento.avanzo
	await calentamiento.avanzo
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


func test_los_objetos_movibles_se_dibujan_tambien_sin_los_focos_del_cuarto() -> void:
	var escena := _escena()
	var movible := escena.get_child(0) as MeshInstance3D
	movible.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	var foco := SpotLight3D.new()
	escena.add_child(foco)
	var apagado := SpotLight3D.new()
	apagado.visible = false
	escena.add_child(apagado)
	var area := AreaLight3D.new()
	area.area_range = 2.0
	escena.add_child(area)
	var calentamiento := _calentamiento()
	var sin_focos := [false]
	var con_ambas_luces := [false]
	var camara := Camera3D.new()
	camara.position = Vector3(1.0, 2.0, 2.0)
	escena.add_child(camara)
	camara.make_current()
	var original := movible.global_transform
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			sin_focos[0] = sin_focos[0] or (movible.visible and not foco.visible)
			con_ambas_luces[0] = (
				con_ambas_luces[0] or (movible.visible and foco.visible and area.area_range > 2.0)
			)
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(sin_focos[0]).is_true()
	assert_bool(con_ambas_luces[0]).is_true()
	assert_float(area.area_range).is_equal(2.0)
	assert_that(movible.global_transform).is_equal(original)
	assert_bool(foco.visible).is_true()
	assert_bool(apagado.visible).is_false()
	assert_int(_visibles(escena)).is_equal(CUANTOS)


func test_el_contorno_se_dibuja_antes_de_jugar_y_se_retira_al_terminar() -> void:
	var escena: Node3D = auto_free(Node3D.new())
	var malla := MallaConContorno.new()
	escena.add_child(malla)
	add_child(escena)
	var calentamiento := _calentamiento()
	var se_dibujo := [false]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			se_dibujo[0] = (
				se_dibujo[0] or (malla.visible and malla.material_override.next_pass == malla.borde)
			)
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(se_dibujo[0]).is_true()
	assert_object(malla.material_override.next_pass).is_null()


func test_el_calentamiento_restaura_el_pase_y_los_uniformes_del_foco_previo() -> void:
	var escena: Node3D = auto_free(Node3D.new())
	var malla := MallaConContorno.new()
	escena.add_child(malla)
	add_child(escena)
	malla.material_override.next_pass = malla.borde
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_object(malla.material_override.next_pass).is_same(malla.borde)
	assert_float(float(malla.borde.get_shader_parameter("grosor"))).is_equal(.023)
	assert_that(malla.borde.get_shader_parameter("color")).is_equal(Color.CYAN)
