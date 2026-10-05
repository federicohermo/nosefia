extends GdUnitTestSuite

const Agua := preload("res://src/escenas/objetos/superficie_liquida.gd")
const LIMPIA := Color(0.25, 0.45, 0.65, 0.8)
const JABON := Color(0.9, 0.15, 0.55, 0.8)


func _agua(en_balde: bool = true) -> Agua:
	var recipiente: Node3D = auto_free(Recipiente.new())
	add_child(recipiente)
	var agua := Agua.new()
	agua.en_balde = en_balde
	agua.mesh = CylinderMesh.new()
	var pintura := StandardMaterial3D.new()
	pintura.albedo_color = LIMPIA
	agua.material_override = pintura
	recipiente.add_child(agua)
	agua.set_process(false)
	agua.set_physics_process(false)
	return agua


func _progreso(agua: Agua) -> float:
	return (agua.material_override as ShaderMaterial).get_shader_parameter("progreso_de_mezcla")


# AC-CLN-033: destino inmediato, aspecto previo al empezar y dos colores en la transición.
func test_el_jabon_aceptado_conserva_el_aspecto_previo_y_se_mezcla_en_setecientos_ms() -> void:
	var agua := _agua()
	agua.mezclar(JABON)
	var pintura := agua.material_override as ShaderMaterial
	assert_bool(agua.color_de_la_superficie() == JABON).is_true()
	assert_bool(pintura.get_shader_parameter("color_previo") == LIMPIA).is_true()
	assert_float(_progreso(agua)).is_equal(0.0)
	for paso: int in 7:
		agua.call("_physics_process", 0.05)
	assert_float(_progreso(agua)).is_between(0.45, 0.55)
	assert_bool(pintura.get_shader_parameter("color_previo") == LIMPIA).is_true()
	assert_bool(pintura.get_shader_parameter("color_del_agua") == JABON).is_true()
	for paso: int in 8:
		agua.call("_physics_process", 0.05)
	assert_float(_progreso(agua)).is_equal(1.0)
	assert_bool(agua.color_de_la_superficie() == JABON).is_true()


# AC-CLN-033: las actualizaciones del mismo destino no vuelven a iniciar la mezcla.
func test_repintar_o_repetir_el_destino_no_corta_ni_reinicia_la_mezcla() -> void:
	var agua := _agua()
	agua.mezclar(JABON)
	agua.call("_physics_process", 0.1)
	var anterior := _progreso(agua)
	agua.pintar(JABON)
	assert_float(_progreso(agua)).is_equal(anterior)
	agua.mezclar(JABON)
	assert_float(_progreso(agua)).is_equal(anterior)
	agua.call("_physics_process", 0.1)
	assert_float(_progreso(agua)).is_greater(anterior)


# AC-CLN-033: vaciar o reiniciar la jornada quita el frente de mezcla anterior.
func test_vaciar_y_reiniciar_cancelan_la_mezcla_y_no_reusan_su_color_previo() -> void:
	var agua := _agua()
	agua.mezclar(JABON)
	agua.call("_physics_process", 0.1)
	agua.presentar(false)
	assert_float(_progreso(agua)).is_equal(1.0)
	agua.pintar(LIMPIA)
	agua.presentar(true)
	agua.mezclar(JABON)
	assert_float(_progreso(agua)).is_equal(0.0)
	(
		assert_bool(
			(
				(agua.material_override as ShaderMaterial).get_shader_parameter("color_previo")
				== LIMPIA
			)
		)
		. is_true()
	)
	agua.reiniciar()
	assert_float(_progreso(agua)).is_equal(1.0)
	(
		assert_bool(
			(agua.material_override as ShaderMaterial).get_shader_parameter("color_previo") == JABON
		)
		. is_true()
	)


func test_los_liquidos_ajenos_al_balde_conservan_su_pintado_inmediato() -> void:
	var agua := _agua(false)
	agua.configurar_agua(true)
	agua.mezclar(JABON)
	assert_bool(agua.color_de_la_superficie() == JABON).is_true()
	assert_float(_progreso(agua)).is_equal(1.0)


func _densidad(pintura: ShaderMaterial, nombre: StringName) -> float:
	var valor: Variant = pintura.get_shader_parameter(nombre)
	return -1.0 if valor == null else float(valor)


func test_el_contraste_del_producto_se_mezcla_sin_cambiar_el_agua_limpia() -> void:
	var agua := _agua()
	var limpia: Color = ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.LIMPIA]
	var rosa: Color = ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.ROSA]
	agua.pintar(limpia)
	var pintura := agua.material_override as ShaderMaterial
	assert_float(_densidad(pintura, &"densidad_de_solucion")).is_equal(0.0)
	assert_float(_densidad(pintura, &"densidad_previa")).is_equal(0.0)
	agua.mezclar(rosa)
	assert_float(_densidad(pintura, &"densidad_de_solucion")).is_equal(1.0)
	assert_float(_densidad(pintura, &"densidad_previa")).is_equal(0.0)
	assert_float(_progreso(agua)).is_equal(0.0)
	agua.call("_physics_process", .1)
	var progreso := _progreso(agua)
	assert_float(progreso).is_between(.1, .2)
	agua.pintar(rosa)
	assert_float(_progreso(agua)).is_equal(progreso)
	agua.vaciar()
	assert_float(_progreso(agua)).is_equal(1.0)
	assert_float(_densidad(pintura, &"densidad_previa")).is_equal(1.0)
	assert_bool(agua.color_de_la_superficie() == rosa).is_true()
	agua.reiniciar()
	agua.pintar(limpia)
	assert_float(_densidad(pintura, &"densidad_de_solucion")).is_equal(0.0)
	assert_float(_densidad(pintura, &"densidad_previa")).is_equal(0.0)
	var ajena := _agua(false)
	ajena.configurar_agua(true)
	ajena.pintar(rosa)
	assert_float(_densidad(ajena.material_override, &"densidad_de_solucion")).is_equal(0.0)


class Recipiente:
	extends Node3D
	var lugar := 0
