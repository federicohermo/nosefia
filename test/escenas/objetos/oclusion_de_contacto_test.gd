## La oclusión de contacto de la caja: se apoya con una mancha abajo, se va al levantarla y no
## gasta un rayo por cuadro cuando está quieta.
##
## Se mira lo que el efecto escribe —la mancha y los valores de los materiales de la malla—, no lo
## que dibuja la pantalla: eso lo cubren las capturas.
extends GdUnitTestSuite

const CAJA := preload("res://src/escenas/objetos/caja_de_productos.tscn")
const Oclusion := preload("res://src/escenas/objetos/oclusion_de_contacto.gd")

## El piso es una losa con la cara de arriba en y = 0.
const GROSOR_DEL_PISO := 0.2

## Cuánto se corre una caja sobre la otra, en metros: menos que su mitad, así la de abajo la
## sostiene.
const CORRIDA := 0.1


func _piso(inclinacion := 0.0) -> StaticBody3D:
	var piso: StaticBody3D = auto_free(StaticBody3D.new())
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(10.0, GROSOR_DEL_PISO, 10.0)
	forma.shape = caja
	piso.add_child(forma)
	add_child(piso)
	piso.global_position = Vector3(0.0, -GROSOR_DEL_PISO / 2.0, 0.0)
	piso.rotation.z = inclinacion
	return piso


## Una caja con su base `altura` metros sobre el piso, y lo que le toca a la física asentarse.
func _caja_a(altura: float, corrida := Vector3.ZERO) -> RigidBody3D:
	var caja: RigidBody3D = auto_free(CAJA.instantiate())
	add_child(caja)
	caja.global_position = corrida + Vector3.UP * (caja.call("media") + altura)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return caja


func _oclusion_de(caja: Node) -> Node3D:
	for nodo in get_tree().get_nodes_in_group(Oclusion.GRUPO):
		if caja.is_ancestor_of(nodo):
			return nodo
	return null


func _de_la_mancha(oclusion: Node3D, nombre: StringName) -> Variant:
	return (oclusion.sombra.material_override as ShaderMaterial).get_shader_parameter(nombre)


func _de_la_malla(oclusion: Node3D, nombre: StringName) -> Variant:
	return (oclusion.malla.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter(
		nombre
	)


func _intensidad(oclusion: Node3D) -> float:
	return _de_la_mancha(oclusion, &"intensidad")


func test_apoyada_deja_su_mancha_y_oscurece_su_base() -> void:
	_piso()
	var caja := await _caja_a(0.0)
	var oclusion := _oclusion_de(caja)
	assert_object(oclusion).is_not_null()
	assert_bool(oclusion.sombra.visible).is_true()
	assert_float(_intensidad(oclusion)).is_equal(Oclusion.intensidad_a(0.0))
	var suelo: float = _de_la_malla(oclusion, Oclusion.SUELO_DE_LA_MALLA)
	assert_float(suelo).is_equal_approx(0.0, 0.001)
	var activo: float = _de_la_malla(oclusion, Oclusion.PARAMETRO_DE_LA_MALLA)
	assert_float(activo).is_greater(0.0)


func test_la_mancha_se_aclara_al_levantarla_y_se_apaga_pasado_el_alcance() -> void:
	_piso()
	var caja := await _caja_a(0.0)
	var oclusion := _oclusion_de(caja)
	var apoyada := _intensidad(oclusion)
	caja.global_position += Vector3.UP * Oclusion.ALCANCE / 2.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(oclusion.sombra.visible).is_true()
	assert_float(_intensidad(oclusion)).is_less(apoyada)
	caja.global_position += Vector3.UP * Oclusion.ALCANCE
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(oclusion.sombra.visible).is_false()


func test_lejos_de_toda_superficie_la_malla_no_se_entera_de_ningun_suelo() -> void:
	_piso()
	var caja := await _caja_a(Oclusion.ALCANCE * 2.0)
	var oclusion := _oclusion_de(caja)
	assert_bool(oclusion.sombra.visible).is_false()
	var suelo: float = _de_la_malla(oclusion, Oclusion.SUELO_DE_LA_MALLA)
	assert_float(suelo).is_equal(Oclusion.SIN_SUELO)


func test_sin_nada_abajo_no_hay_mancha() -> void:
	var caja := await _caja_a(0.0)
	assert_bool(_oclusion_de(caja).sombra.visible).is_false()


func test_una_pared_no_sostiene_ninguna_mancha() -> void:
	_piso(deg_to_rad(80.0))
	var caja := await _caja_a(0.0)
	assert_bool(_oclusion_de(caja).sombra.visible).is_false()


func test_una_superficie_inclinada_lleva_la_mancha_pegada_a_ella() -> void:
	var inclinacion := deg_to_rad(15.0)
	_piso(inclinacion)
	var caja: RigidBody3D = auto_free(CAJA.instantiate())
	add_child(caja)
	caja.global_position = Vector3(0.0, caja.call("media") + Oclusion.ALCANCE / 4.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var sombra: MeshInstance3D = _oclusion_de(caja).sombra
	assert_bool(sombra.visible).is_true()
	var normal := Vector3.UP.rotated(Vector3.BACK, inclinacion)
	assert_vector(sombra.global_basis.y.normalized()).is_equal_approx(normal, Vector3.ONE * 0.001)


func test_sobre_otra_caja_la_mancha_se_corta_en_el_borde_de_la_de_abajo() -> void:
	_piso()
	var abajo := await _caja_a(0.0)
	var media: float = abajo.call("media")
	var arriba := await _caja_a(2.0 * media, Vector3.RIGHT * CORRIDA)
	var oclusion := _oclusion_de(arriba)
	assert_bool(oclusion.sombra.visible).is_true()
	var recorte: Vector4 = _de_la_mancha(oclusion, &"recorte")
	# Hacia donde se corrió, la caja de abajo termina a su mitad menos lo corrido del punto.
	assert_float(recorte.z).is_equal_approx(media - CORRIDA, 0.001)
	assert_float(recorte.x).is_equal_approx(-(media + CORRIDA), 0.001)


func test_apagarla_oculta_la_mancha_y_prenderla_la_devuelve() -> void:
	_piso()
	var caja := await _caja_a(0.0)
	var oclusion := _oclusion_de(caja)
	oclusion.activa = false
	assert_bool(oclusion.sombra.visible).is_false()
	oclusion.activa = true
	assert_bool(oclusion.sombra.visible).is_true()


func test_una_caja_quieta_no_lanza_rayos_y_moverla_los_retoma() -> void:
	_piso()
	var caja := await _caja_a(0.0)
	var oclusion := _oclusion_de(caja)
	for _cuadro in 5:
		await get_tree().physics_frame
	var lanzados: int = oclusion.rayos
	assert_int(lanzados).is_greater(0)
	for _cuadro in 30:
		await get_tree().physics_frame
	assert_int(oclusion.rayos).is_equal(lanzados)
	caja.global_position += Vector3.RIGHT
	for _cuadro in 3:
		await get_tree().physics_frame
	assert_int(oclusion.rayos).is_greater(lanzados)


func test_la_mancha_se_va_con_la_caja_y_reparentarla_no_la_deja_atras() -> void:
	_piso()
	var caja := await _caja_a(0.0)
	var sombra: MeshInstance3D = _oclusion_de(caja).sombra
	var otro: Node3D = auto_free(Node3D.new())
	add_child(otro)
	caja.reparent(otro)
	await get_tree().physics_frame
	assert_bool(otro.is_ancestor_of(sombra)).is_true()
	caja.free()
	assert_bool(is_instance_valid(sombra)).is_false()


func test_cada_caja_lleva_lo_suyo_y_una_no_pisa_a_la_otra() -> void:
	_piso()
	var apoyada := await _caja_a(0.0)
	var en_el_aire := await _caja_a(Oclusion.ALCANCE * 2.0, Vector3.RIGHT * 2.0)
	var de_la_apoyada := _oclusion_de(apoyada)
	var de_la_del_aire := _oclusion_de(en_el_aire)
	assert_object(de_la_apoyada.malla.get_surface_override_material(0)).is_not_same(
		de_la_del_aire.malla.get_surface_override_material(0)
	)
	assert_object(de_la_apoyada.sombra.material_override).is_not_same(
		de_la_del_aire.sombra.material_override
	)
	assert_float(_de_la_malla(de_la_apoyada, Oclusion.SUELO_DE_LA_MALLA)).is_equal_approx(
		0.0, 0.001
	)
	assert_float(_de_la_malla(de_la_del_aire, Oclusion.SUELO_DE_LA_MALLA)).is_equal(
		Oclusion.SIN_SUELO
	)


func test_la_base_se_apaga_y_se_prende_con_la_propiedad_del_nodo() -> void:
	_piso()
	var oclusion := _oclusion_de(await _caja_a(0.0))
	oclusion.base = 0.0
	assert_float(_de_la_malla(oclusion, Oclusion.PARAMETRO_DE_LA_MALLA)).is_zero()
	oclusion.base = 1.0
	assert_float(_de_la_malla(oclusion, Oclusion.PARAMETRO_DE_LA_MALLA)).is_equal(1.0)


## En la web los uniformes por instancia llegan al shader en cero, y el efecto no se ve aunque el
## código los escriba bien.
func test_ningun_shader_del_efecto_declara_uniformes_por_instancia() -> void:
	var rutas := [
		"res://src/escenas/objetos/sombra_de_contacto.gdshader",
		"res://src/escenas/objetos/oclusion_de_contacto.gdshaderinc",
		"res://src/escenas/puestos/producto_de_la_gondola.gdshader",
		"res://src/escenas/objetos/manija_del_balde.gdshader",
	]
	for ruta: String in rutas:
		(
			assert_bool(FileAccess.get_file_as_string(ruta).contains("instance uniform"))
			. override_failure_message("%s declara un uniforme por instancia" % ruta)
			. is_false()
		)
