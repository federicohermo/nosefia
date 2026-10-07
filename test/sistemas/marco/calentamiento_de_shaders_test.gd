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


func test_el_modelo_reemplazado_no_se_destapa_durante_el_calentamiento() -> void:
	var escena := _escena()
	var referencia := escena.get_child(0) as MeshInstance3D
	referencia.visible = false
	referencia.add_to_group(&"geometria_de_referencia")
	var cambios: Array[bool] = []
	referencia.visibility_changed.connect(func() -> void: cambios.append(referencia.visible))
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_array(cambios).is_empty()
	assert_bool(referencia.visible).is_false()
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


func _escena_con_gotas() -> Node3D:
	var escena: Node3D = auto_free(Node3D.new())
	var gotas := MultiMeshInstance3D.new()
	gotas.name = "Gotas"
	gotas.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	gotas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gotas.multimesh = MultiMesh.new()
	gotas.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	gotas.multimesh.mesh = SphereMesh.new()
	gotas.multimesh.instance_count = 24
	gotas.multimesh.visible_instance_count = 1
	gotas.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)))
	gotas.custom_aabb = AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	gotas.material_override = ShaderMaterial.new()
	gotas.visible = false
	escena.add_child(gotas)
	var omni := OmniLight3D.new()
	omni.name = "Omni"
	omni.position = Vector3(10, 2, 0)
	omni.omni_range = 2.0
	escena.add_child(omni)
	var foco := SpotLight3D.new()
	foco.name = "Foco"
	escena.add_child(foco)
	var area := AreaLight3D.new()
	area.name = "Area"
	area.position = omni.position
	area.area_range = 2.0
	escena.add_child(area)
	add_child(escena)
	return escena


func test_las_gotas_se_calientan_con_omni_y_area_sin_mover_el_lote_real() -> void:
	var escena := _escena_con_gotas()
	var gotas := escena.get_node("Gotas") as MultiMeshInstance3D
	var omni := escena.get_node("Omni") as OmniLight3D
	var foco := escena.get_node("Foco") as SpotLight3D
	var area := escena.get_node("Area") as AreaLight3D
	var original := gotas.global_transform
	var caja := gotas.custom_aabb
	var buffer := gotas.multimesh.buffer
	assert_float(gotas.get_aabb().get_center().distance_to(omni.position)).is_greater(
		omni.omni_range
	)
	var calentamiento := _calentamiento()
	var muestras: Array[MultiMeshInstance3D] = []
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for objeto: MultiMeshInstance3D in calentamiento.find_children(
				"*", "MultiMeshInstance3D", true, false
			):
				if not objeto.visible or foco.visible:
					continue
				var punto := objeto.global_transform * objeto.get_aabb().get_center()
				if (
					punto.distance_to(omni.global_position) >= omni.omni_range
					or punto.distance_to(area.global_position) >= area.area_range
				):
					continue
				assert_object(objeto.multimesh.mesh).is_same(gotas.multimesh.mesh)
				assert_object(objeto.material_override).is_same(gotas.material_override)
				assert_int(objeto.gi_mode).is_equal(gotas.gi_mode)
				assert_int(objeto.cast_shadow).is_equal(gotas.cast_shadow)
				assert_int(objeto.multimesh.visible_instance_count).is_equal(1)
				muestras.append(objeto)
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_array(muestras).is_not_empty()
	assert_that(gotas.global_transform).is_equal(original)
	assert_that(gotas.custom_aabb).is_equal(caja)
	assert_that(gotas.multimesh.buffer).is_equal(buffer)
	assert_int(gotas.multimesh.instance_count).is_equal(24)
	assert_int(gotas.multimesh.visible_instance_count).is_equal(1)
	assert_bool(gotas.visible).is_false()
	assert_bool(foco.visible).is_true()
	assert_float(area.area_range).is_equal(2.0)
	await get_tree().process_frame
	for muestra in muestras:
		assert_bool(is_instance_valid(muestra)).is_false()


func test_cancelar_el_calentamiento_restaura_luces_y_gotas_y_libera_muestras() -> void:
	var escena := _escena_con_gotas()
	var gotas := escena.get_node("Gotas") as MultiMeshInstance3D
	var area := escena.get_node("Area") as AreaLight3D
	var foco := escena.get_node("Foco") as SpotLight3D
	var camara := Camera3D.new()
	escena.add_child(camara)
	camara.make_current()
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	while foco.visible:
		await calentamiento.avanzo
	var muestras := calentamiento.find_children("*", "MultiMeshInstance3D", true, false)
	assert_array(muestras).is_not_empty()
	assert_float(area.area_range).is_greater(2.0)
	calentamiento.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(foco.visible).is_true()
	assert_float(area.area_range).is_equal(2.0)
	assert_bool(gotas.visible).is_false()
	assert_object(get_viewport().get_camera_3d()).is_same(camara)
	for muestra in muestras:
		assert_bool(is_instance_valid(muestra)).is_false()


## La cola la maneja el caso: es lo que la plantilla web le publica a la página.
func _calentamiento_con_cola(cola: Array[int]) -> CalentamientoDeShaders:
	var calentamiento := _calentamiento()
	calentamiento.programas_en_cola = func() -> int: return cola[0]
	return calentamiento


func test_fuera_de_la_web_la_plantilla_no_enlaza_en_paralelo() -> void:
	assert_int(_calentamiento().programas_en_cola.call()).is_equal(-1)


func test_con_cola_la_pasada_destapa_todos_sus_objetos_en_un_cuadro() -> void:
	var escena := _escena(3)
	var cola: Array[int] = [0]
	var calentamiento := _calentamiento_con_cola(cola)
	calentamiento.calentar(escena)
	assert_int(_visibles(escena)).is_zero()
	await calentamiento.avanzo
	assert_int(_visibles(escena)).is_equal(CUANTOS)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_int(_visibles(escena)).is_equal(CUANTOS)
	assert_float(calentamiento.progreso()).is_equal(1.0)


func test_no_termina_mientras_quedan_programas_en_cola() -> void:
	var escena := _escena()
	var cola: Array[int] = [0]
	var calentamiento := _calentamiento_con_cola(cola)
	var termino := [false]
	calentamiento.terminado.connect(func() -> void: termino[0] = true)
	calentamiento.calentar(escena)
	await calentamiento.avanzo
	cola[0] = 5
	for _cuadro: int in 10:
		await get_tree().process_frame
	assert_bool(termino[0]).is_false()
	cola[0] = 0
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_float(calentamiento.progreso()).is_equal(1.0)


func test_las_pasadas_no_esperan_la_cola_y_el_final_espera_la_de_la_ultima() -> void:
	var escena := _escena()
	(escena.get_child(0) as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	var foco := SpotLight3D.new()
	escena.add_child(foco)
	var cola: Array[int] = [1]
	var calentamiento := _calentamiento_con_cola(cola)
	var termino := [false]
	calentamiento.terminado.connect(func() -> void: termino[0] = true)
	calentamiento.calentar(escena)
	for _cuadro: int in 10:
		await get_tree().process_frame
	# La pasada sin focos es la última: llegó con la cola de la primera todavía ocupada.
	assert_bool(foco.visible).is_false()
	assert_bool(termino[0]).is_false()
	cola[0] = 0
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(foco.visible).is_true()


func test_con_cola_el_progreso_sale_de_los_programas_que_terminaron() -> void:
	var escena := _escena()
	var cola: Array[int] = [0]
	var calentamiento := _calentamiento_con_cola(cola)
	var progresos: Array[float] = []
	calentamiento.avanzo.connect(func(progreso: float) -> void: progresos.append(progreso))
	calentamiento.calentar(escena)
	await calentamiento.avanzo
	assert_float(progresos[-1]).is_zero()
	cola[0] = 4
	await calentamiento.avanzo
	assert_float(progresos[-1]).is_zero()
	cola[0] = 1
	await calentamiento.avanzo
	assert_float(progresos[-1]).is_equal_approx(0.75, 0.001)
	# Una variante que entra tarde a la cola no hace retroceder la barra.
	cola[0] = 3
	await calentamiento.avanzo
	assert_float(progresos[-1]).is_equal_approx(0.75, 0.001)
	cola[0] = 0
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_float(calentamiento.progreso()).is_equal(1.0)
