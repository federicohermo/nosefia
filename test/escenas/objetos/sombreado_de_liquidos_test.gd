extends GdUnitTestSuite

const Superficie := preload("res://src/escenas/objetos/superficie_liquida.gd")
const BANO := preload("res://src/escenas/puestos/agua_del_bano.tscn")
const COLOR := Color(0.35, 0.5, 0.6, 0.8)


func _superficie(en_balde: bool = false) -> Superficie:
	var recipiente: Node3D = auto_free(Recipiente.new())
	add_child(recipiente)
	var superficie := Superficie.new()
	superficie.en_balde = en_balde
	superficie.mesh = CylinderMesh.new()
	var pintura := StandardMaterial3D.new()
	pintura.albedo_color = COLOR
	superficie.material_override = pintura
	recipiente.add_child(superficie)
	superficie.set_process(false)
	superficie.set_physics_process(false)
	return superficie


func _modo(superficie: MeshInstance3D) -> int:
	var pintura := superficie.material_override as ShaderMaterial
	var valor: Variant = pintura.get_shader_parameter("es_mancha")
	return -1 if valor == null else int(valor)


func test_agua_y_mancha_comparten_shader_con_materiales_independientes() -> void:
	var agua := _superficie(true)
	var mancha := _superficie()
	mancha.configurar_mancha(ReglasDeLaLimpieza.TipoDeMancha.MOHO, false)
	var pintura_agua := agua.material_override as ShaderMaterial
	var pintura_mancha := mancha.material_override as ShaderMaterial
	assert_bool(pintura_agua != pintura_mancha).is_true()
	assert_bool(pintura_agua.shader.get_rid() == pintura_mancha.shader.get_rid()).is_true()
	assert_int(_modo(agua)).is_equal(0)
	assert_int(_modo(mancha)).is_equal(1)
	mancha.pintar(Color.BROWN)
	assert_bool(agua.color_de_la_superficie() == COLOR).is_true()


func test_cambiar_de_aspecto_conserva_color_material_y_textura_de_la_mancha() -> void:
	var superficie := _superficie(true)
	var pintura := superficie.material_override as ShaderMaterial
	superficie.configurar_mancha(ReglasDeLaLimpieza.TipoDeMancha.POLVO, true)
	assert_bool(superficie.material_override == pintura).is_true()
	assert_int(_modo(superficie)).is_equal(1)
	assert_bool(superficie.color_de_la_superficie() == COLOR).is_true()
	assert_object(pintura.get_shader_parameter("guia_de_manchas")).is_not_null()
	superficie.configurar_agua(true)
	assert_bool(superficie.material_override == pintura).is_true()
	assert_int(_modo(superficie)).is_equal(0)
	assert_bool(superficie.color_de_la_superficie() == COLOR).is_true()


func test_el_bano_usa_el_mismo_shader_de_agua_y_manchas() -> void:
	var bano: Node3D = auto_free(BANO.instantiate())
	var superficie := _superficie()
	superficie.configurar_mancha(ReglasDeLaLimpieza.TipoDeMancha.MOHO, false)
	var compartido := (superficie.material_override as ShaderMaterial).shader
	for nombre: String in ["Lavatorio", "Inodoro"]:
		var pintura := (bano.get_node(nombre) as MeshInstance3D).material_override as ShaderMaterial
		assert_bool(pintura.shader.get_rid() == compartido.get_rid()).is_true()
		var valor: Variant = pintura.get_shader_parameter("es_mancha")
		assert_int(-1 if valor == null else int(valor)).is_equal(0)


func test_una_mancha_no_inicia_la_mezcla_del_agua_aunque_comparta_shader() -> void:
	var superficie := _superficie(true)
	superficie.configurar_mancha(ReglasDeLaLimpieza.TipoDeMancha.MOHO, false)
	superficie.mezclar(Color.BROWN)
	assert_int(_modo(superficie)).is_equal(1)
	assert_bool(superficie.color_de_la_superficie() == Color.BROWN).is_true()
	var pintura := superficie.material_override as ShaderMaterial
	var valor: Variant = pintura.get_shader_parameter("progreso_de_mezcla")
	assert_float(-1.0 if valor == null else float(valor)).is_equal(1.0)


class Recipiente:
	extends Node3D
	var lugar := 0
