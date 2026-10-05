extends GdUnitTestSuite

const OBJETOS := preload("res://src/escenas/puestos/objetos_del_almacen.tscn")
const CONTORNO_FIJO := preload("res://src/sistemas/marco/contorno.gdshader")


func _objetos() -> Node3D:
	var objetos: Node3D = auto_free(OBJETOS.instantiate())
	add_child(objetos)
	for cuerpo: Node in objetos.get_children():
		if cuerpo is RigidBody3D:
			cuerpo.freeze = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	objetos.get_node("Mopa/Malla").set_physics_process(false)
	objetos.get_node("Balde/Malla").set_process(false)
	return objetos


func _bordes(malla: MeshInstance3D, campo: String) -> Array[ShaderMaterial]:
	var bordes: Array[ShaderMaterial] = []
	bordes.assign(malla.get(campo))
	assert_array(bordes).is_not_empty()
	return bordes


func _seleccion(material: ShaderMaterial) -> int:
	var seleccion: Variant = material.get_shader_parameter("deformacion")
	return -1 if seleccion == null else int(seleccion)


func test_las_tres_partes_animadas_comparten_shader_con_materiales_independientes() -> void:
	var objetos := await _objetos()
	var mopa: MeshInstance3D = objetos.get_node("Mopa/Malla")
	var balde: MeshInstance3D = objetos.get_node("Balde/Malla")
	var fibras := _bordes(mopa, "_contornos_fibra")
	var cabeza := _bordes(mopa, "_contornos_rigidos")
	var manija := _bordes(balde, "_contornos")
	var shader := fibras[0].shader
	assert_object(shader).is_not_null()
	for borde: ShaderMaterial in fibras + cabeza + manija:
		assert_object(borde.shader).is_same(shader)
	assert_object(cabeza[0]).is_not_same(fibras[0])
	assert_object(manija[0]).is_not_same(cabeza[0])
	assert_object(shader).is_not_same(CONTORNO_FIJO)
	for malla: MeshInstance3D in [mopa, balde]:
		var pases: Dictionary = malla.get("_segundos_pases")
		var fijos := 0
		for pintura: Material in pases:
			if pintura is StandardMaterial3D:
				assert_object((pases[pintura] as ShaderMaterial).shader).is_same(CONTORNO_FIJO)
				fijos += 1
		assert_int(fijos).is_greater(0)


func test_cada_parte_selecciona_su_deformacion_y_el_foco_conserva_color_y_grosor() -> void:
	var objetos := await _objetos()
	var mopa: MeshInstance3D = objetos.get_node("Mopa/Malla")
	var balde: MeshInstance3D = objetos.get_node("Balde/Malla")
	var foco := ShaderMaterial.new()
	foco.shader = CONTORNO_FIJO
	foco.set_shader_parameter("color", Color(.9, .75, .3))
	foco.set_shader_parameter("grosor", .008)
	mopa.call("mostrar_contorno", foco)
	balde.call("mostrar_contorno", foco)
	var grupos := [
		_bordes(mopa, "_contornos_fibra"),
		_bordes(mopa, "_contornos_rigidos"),
		_bordes(balde, "_contornos"),
	]
	for seleccion: int in grupos.size():
		for borde: ShaderMaterial in grupos[seleccion]:
			assert_int(_seleccion(borde)).is_equal(seleccion)
			assert_that(borde.get_shader_parameter("color")).is_equal(Color(.9, .75, .3))
			assert_float(borde.get_shader_parameter("grosor")).is_equal(.008)
	for malla: MeshInstance3D in [mopa, balde]:
		var pases: Dictionary = malla.get("_segundos_pases")
		for pintura: Material in pases:
			assert_object(pintura.next_pass).is_same(pases[pintura])
		malla.call("mostrar_contorno", null)
		for pintura: Material in pases:
			assert_object(pintura.next_pass).is_null()


func test_el_contorno_recibe_la_misma_pose_flexion_e_inmersion_que_la_mopa() -> void:
	var objetos := await _objetos()
	var cuerpo: RigidBody3D = objetos.get_node("Mopa")
	var mopa: MeshInstance3D = cuerpo.get_node("Malla")
	var balde: Node3D = objetos.get_node("Balde")
	cuerpo.global_position = Vector3(0, 10, 0)
	cuerpo.rotation.z = PI / 3.0
	for cuadro: int in 20:
		cuerpo.position.x += .005 * cuadro
		mopa.call("_physics_process", 1.0 / 60.0)
	mopa.call("limitar_en", balde, 1.0)
	var pinturas := _bordes(mopa, "_pinturas")
	var fibras := _bordes(mopa, "_contornos_fibra")
	var rigidas := _bordes(mopa, "_rigidas")
	var cabeza := _bordes(mopa, "_contornos_rigidos")
	assert_float((pinturas[0].get_shader_parameter("caida") as Vector3).length()).is_greater(.01)
	assert_float(pinturas[0].get_shader_parameter("inmersion")).is_equal(1.0)
	for campo: String in [
		"articulacion", "flexion", "caida", "suelo_y", "centro_balde", "vertical_balde", "inmersion"
	]:
		for borde: ShaderMaterial in fibras:
			assert_that(borde.get_shader_parameter(campo)).is_equal(
				pinturas[0].get_shader_parameter(campo)
			)
	for borde: ShaderMaterial in cabeza:
		assert_that(borde.get_shader_parameter("articulacion")).is_equal(
			rigidas[0].get_shader_parameter("articulacion")
		)


func test_el_contorno_del_asa_sigue_el_giro_sin_cambiar_el_selector_de_la_mopa() -> void:
	var objetos := await _objetos()
	var cuerpo: RigidBody3D = objetos.get_node("Balde")
	var balde: MeshInstance3D = cuerpo.get_node("Malla")
	var mopa: MeshInstance3D = objetos.get_node("Mopa/Malla")
	var pinturas := _bordes(balde, "_pinturas")
	var bordes := _bordes(balde, "_contornos")
	cuerpo.top_level = false
	balde.call("_process", .125)
	var angulo: float = pinturas[0].get_shader_parameter("angulo")
	assert_float(angulo).is_between(.01, PI / 2.0 - .01)
	for borde: ShaderMaterial in bordes:
		assert_float(borde.get_shader_parameter("angulo")).is_equal(angulo)
		assert_int(_seleccion(borde)).is_equal(2)
	for borde: ShaderMaterial in _bordes(mopa, "_contornos_fibra"):
		assert_int(_seleccion(borde)).is_equal(0)
