## De dónde sale la huella de un objeto que se apoya: lo que toca lo de abajo, sea cual sea su lado.
## Un objeto caído de costado o boca abajo deja su mancha igual que uno parado.
extends GdUnitTestSuite

const Oclusion := preload("res://src/escenas/objetos/oclusion_de_contacto.gd")

const GROSOR_DEL_PISO := 0.2

## Un tablón: sus tres lados son distintos, así que no se confunde uno con otro. En metros.
const TABLON := Vector3(0.4, 0.1, 0.2)


func _piso() -> void:
	var piso: StaticBody3D = auto_free(StaticBody3D.new())
	var forma := CollisionShape3D.new()
	var losa := BoxShape3D.new()
	losa.size = Vector3(10.0, GROSOR_DEL_PISO, 10.0)
	forma.shape = losa
	piso.add_child(forma)
	add_child(piso)
	piso.global_position = Vector3(0.0, -GROSOR_DEL_PISO / 2.0, 0.0)


## Un tablón quieto, con la pose que se le da. La física no lo mueve: lo que se mira es la huella.
func _tablon(pose: Transform3D) -> Node3D:
	var cuerpo: RigidBody3D = auto_free(RigidBody3D.new())
	cuerpo.freeze = true
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = TABLON
	forma.shape = caja
	cuerpo.add_child(forma)
	var malla := MeshInstance3D.new()
	var bloque := BoxMesh.new()
	bloque.size = TABLON
	malla.mesh = bloque
	malla.set_surface_override_material(0, ShaderMaterial.new())
	cuerpo.add_child(malla)
	var oclusion: Node3D = Oclusion.new()
	var mallas: Array[MeshInstance3D] = [malla]
	oclusion.configurar(mallas, 0.0)
	cuerpo.add_child(oclusion)
	add_child(cuerpo)
	cuerpo.global_transform = pose
	return oclusion


func _esperar() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


## Las dos mitades de la huella, de menor a mayor: qué eje de la mancha es cuál no importa.
func _huella_de(oclusion: Node3D) -> Array[float]:
	var huella: Vector2 = (
		(oclusion.sombra.material_override as ShaderMaterial).get_shader_parameter(&"huella")
	)
	var lados: Array[float] = [huella.x, huella.y]
	lados.sort()
	return lados


func _suelo_de(oclusion: Node3D) -> float:
	var material := oclusion.mallas[0].get_surface_override_material(0) as ShaderMaterial
	return material.get_shader_parameter(Oclusion.SUELO_DE_LA_MALLA)


func test_parado_sobre_su_lado_angosto_la_huella_es_la_de_ese_lado() -> void:
	_piso()
	var parado := Basis(Vector3.BACK, PI / 2.0)
	var oclusion := _tablon(Transform3D(parado, Vector3.UP * TABLON.x / 2.0))
	await _esperar()
	assert_bool(oclusion.sombra.visible).is_true()
	assert_float(_suelo_de(oclusion)).is_equal_approx(0.0, 0.001)
	var huella := _huella_de(oclusion)
	assert_float(huella[0]).is_equal_approx(TABLON.y / 2.0, 0.002)
	assert_float(huella[1]).is_equal_approx(TABLON.z / 2.0, 0.002)


func test_boca_abajo_deja_su_mancha_igual_que_derecho() -> void:
	_piso()
	var boca_abajo := Basis(Vector3.RIGHT, PI)
	var oclusion := _tablon(Transform3D(boca_abajo, Vector3.UP * TABLON.y / 2.0))
	await _esperar()
	assert_bool(oclusion.sombra.visible).is_true()
	assert_float(_suelo_de(oclusion)).is_equal_approx(0.0, 0.001)
	var huella := _huella_de(oclusion)
	assert_float(huella[0]).is_equal_approx(TABLON.z / 2.0, 0.002)
	assert_float(huella[1]).is_equal_approx(TABLON.x / 2.0, 0.002)


func test_al_cambiar_de_lado_la_huella_se_pone_al_dia() -> void:
	_piso()
	var oclusion := _tablon(Transform3D(Basis.IDENTITY, Vector3.UP * TABLON.y / 2.0))
	await _esperar()
	var acostado := _huella_de(oclusion)
	assert_float(acostado[1]).is_equal_approx(TABLON.x / 2.0, 0.002)
	var cuerpo := oclusion.get_parent() as Node3D
	cuerpo.global_transform = Transform3D(
		Basis(Vector3.BACK, PI / 2.0), Vector3.UP * TABLON.x / 2.0
	)
	await _esperar()
	var parado := _huella_de(oclusion)
	assert_float(parado[0]).is_equal_approx(TABLON.y / 2.0, 0.002)
	assert_float(parado[1]).is_equal_approx(TABLON.z / 2.0, 0.002)
