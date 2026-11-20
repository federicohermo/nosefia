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


func _cuerpo_con_mallas(mallas_cfg: Array[Array], pose: Transform3D) -> Node3D:
	var cuerpo: RigidBody3D = auto_free(RigidBody3D.new())
	cuerpo.freeze = true
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3.ONE * 0.1
	forma.shape = caja
	cuerpo.add_child(forma)
	var mallas: Array[MeshInstance3D] = []
	for entrada in mallas_cfg:
		var malla := MeshInstance3D.new()
		malla.mesh = entrada[0] as Mesh
		malla.transform = entrada[1] as Transform3D
		malla.set_surface_override_material(0, ShaderMaterial.new())
		cuerpo.add_child(malla)
		mallas.append(malla)
	var oclusion: Node3D = Oclusion.new()
	oclusion.configurar(mallas, 0.0)
	cuerpo.add_child(oclusion)
	add_child(cuerpo)
	cuerpo.global_transform = pose
	return oclusion


func _bloque(tamano: Vector3) -> BoxMesh:
	var malla := BoxMesh.new()
	malla.size = tamano
	return malla


func _sombras_visibles(oclusion: Node3D) -> Array[MeshInstance3D]:
	var visibles: Array[MeshInstance3D] = []
	var todas: Array = oclusion.get("sombras")
	for nodo: MeshInstance3D in todas:
		if nodo.visible:
			visibles.append(nodo)
	return visibles


func _sombra_en_x(visibles: Array[MeshInstance3D], x_objetivo: float) -> MeshInstance3D:
	var mejor: MeshInstance3D = null
	var menor := INF
	for nodo in visibles:
		var dist := absf(nodo.global_position.x - x_objetivo)
		if dist < menor:
			menor = dist
			mejor = nodo
	return mejor


func _cubre_en_xz(sombra: MeshInstance3D, punto: Vector3) -> bool:
	var local := sombra.global_transform.affine_inverse() * punto
	return absf(local.x) <= 0.5 and absf(local.z) <= 0.5


func test_dos_zonas_de_contacto_separadas_dan_dos_manchas_y_nada_bajo_el_tramo_alto() -> void:
	_piso()
	var radio := Oclusion.RADIO_POR_DEFECTO
	var separacion := radio * 8.0
	var pie := Vector3(radio, radio, radio)
	var puente := Vector3(separacion, radio, radio)
	var mallas_cfg: Array[Array] = [
		[_bloque(pie), Transform3D(Basis.IDENTITY, Vector3(-separacion / 2.0, radio / 2.0, 0.0))],
		[_bloque(pie), Transform3D(Basis.IDENTITY, Vector3(separacion / 2.0, radio / 2.0, 0.0))],
		[_bloque(puente), Transform3D(Basis.IDENTITY, Vector3(0.0, radio * 3.0, 0.0))],
	]
	var oclusion := _cuerpo_con_mallas(mallas_cfg, Transform3D.IDENTITY)
	await _esperar()
	var visibles := _sombras_visibles(oclusion)
	assert_int(visibles.size()).is_equal(2)
	for sombra in visibles:
		assert_bool(_cubre_en_xz(sombra, Vector3.ZERO)).is_false()
	assert_float(_sombra_en_x(visibles, -separacion / 2.0).global_position.x).is_equal_approx(
		-separacion / 2.0, 0.01
	)
	assert_float(_sombra_en_x(visibles, separacion / 2.0).global_position.x).is_equal_approx(
		separacion / 2.0, 0.01
	)


func test_una_zona_cerca_de_la_superficie_da_una_mancha_con_todo_su_contorno() -> void:
	_piso()
	var radio := Oclusion.RADIO_POR_DEFECTO
	var centro_ancho := radio * 1.2
	var borde_ancho := radio * 5.0
	var altura_borde := radio * 0.5
	var mallas_cfg: Array[Array] = [
		[
			_bloque(Vector3(centro_ancho, radio * 0.4, centro_ancho)),
			Transform3D(Basis.IDENTITY, Vector3(0.0, radio * 0.2, 0.0)),
		],
		[
			_bloque(Vector3(borde_ancho, radio * 0.2, borde_ancho * 0.6)),
			Transform3D(Basis.IDENTITY, Vector3(0.0, altura_borde + radio * 0.1, 0.0)),
		],
	]
	var oclusion := _cuerpo_con_mallas(mallas_cfg, Transform3D.IDENTITY)
	await _esperar()
	var visibles := _sombras_visibles(oclusion)
	assert_int(visibles.size()).is_equal(1)
	var huella := _huella_de(oclusion)
	assert_float(huella[1]).is_equal_approx(borde_ancho / 2.0, 0.002)
	assert_float(huella[0]).is_equal_approx(borde_ancho * 0.3, 0.002)


func test_un_tramo_a_mas_de_radio_de_la_superficie_no_da_mancha() -> void:
	_piso()
	var radio := Oclusion.RADIO_POR_DEFECTO
	var separacion := radio * 8.0
	var pie := Vector3(radio, radio, radio)
	var mallas_cfg: Array[Array] = [
		[_bloque(pie), Transform3D(Basis.IDENTITY, Vector3(-separacion / 2.0, radio / 2.0, 0.0))],
		[
			_bloque(pie),
			Transform3D(Basis.IDENTITY, Vector3(separacion / 2.0, radio * 2.0, 0.0)),
		],
	]
	var oclusion := _cuerpo_con_mallas(mallas_cfg, Transform3D.IDENTITY)
	await _esperar()
	var visibles := _sombras_visibles(oclusion)
	assert_int(visibles.size()).is_equal(1)
	assert_float(visibles[0].global_position.x).is_equal_approx(-separacion / 2.0, 0.01)


func test_cada_mancha_extra_se_crea_solo_cuando_hace_falta_y_se_reusa() -> void:
	_piso()
	var radio := Oclusion.RADIO_POR_DEFECTO
	var separacion := radio * 8.0
	var pie := Vector3(radio, radio, radio)
	var mallas_cfg: Array[Array] = [
		[_bloque(pie), Transform3D(Basis.IDENTITY, Vector3(-separacion / 2.0, radio / 2.0, 0.0))],
		[_bloque(pie), Transform3D(Basis.IDENTITY, Vector3(separacion / 2.0, radio / 2.0, 0.0))],
	]
	# Parado sobre un solo pie: necesita una sola mancha.
	var parado := Transform3D(
		Basis(Vector3.BACK, PI / 2.0), Vector3(0.0, separacion / 2.0 + radio / 2.0, 0.0)
	)
	var oclusion := _cuerpo_con_mallas(mallas_cfg, parado)
	await _esperar()
	assert_int((oclusion.get("sombras") as Array).size()).is_equal(1)
	assert_int(_sombras_visibles(oclusion).size()).is_equal(1)
	var cuerpo := oclusion.get_parent() as Node3D
	cuerpo.global_transform = Transform3D.IDENTITY
	await _esperar()
	assert_int((oclusion.get("sombras") as Array).size()).is_equal(2)
	assert_int(_sombras_visibles(oclusion).size()).is_equal(2)
	var extra: MeshInstance3D = (oclusion.get("sombras") as Array)[1]
	cuerpo.global_transform = parado
	await _esperar()
	assert_int((oclusion.get("sombras") as Array).size()).is_equal(2)
	assert_int(_sombras_visibles(oclusion).size()).is_equal(1)
	cuerpo.global_transform = Transform3D.IDENTITY
	await _esperar()
	assert_int((oclusion.get("sombras") as Array).size()).is_equal(2)
	assert_int(_sombras_visibles(oclusion).size()).is_equal(2)
	assert_object((oclusion.get("sombras") as Array)[1]).is_same(extra)


func test_dos_grupos_a_distinta_altura_llevan_intensidad_segun_su_altura() -> void:
	_piso()
	var radio := Oclusion.RADIO_POR_DEFECTO
	var separacion := radio * 8.0
	var altura_alta := radio * 0.5
	var pie := Vector3(radio, radio, radio)
	var mallas_cfg: Array[Array] = [
		[_bloque(pie), Transform3D(Basis.IDENTITY, Vector3(-separacion / 2.0, radio / 2.0, 0.0))],
		[
			_bloque(pie),
			Transform3D(Basis.IDENTITY, Vector3(separacion / 2.0, altura_alta + radio / 2.0, 0.0)),
		],
	]
	var oclusion := _cuerpo_con_mallas(mallas_cfg, Transform3D.IDENTITY)
	await _esperar()
	var visibles := _sombras_visibles(oclusion)
	assert_int(visibles.size()).is_equal(2)
	var baja := _sombra_en_x(visibles, -separacion / 2.0)
	var alta := _sombra_en_x(visibles, separacion / 2.0)
	var int_baja: float = (baja.material_override as ShaderMaterial).get_shader_parameter(
		&"intensidad"
	)
	var int_alta: float = (alta.material_override as ShaderMaterial).get_shader_parameter(
		&"intensidad"
	)
	assert_float(int_baja).is_equal_approx(oclusion.intensidad_a(0.0), 0.001)
	assert_float(int_alta).is_equal_approx(oclusion.intensidad_a(altura_alta), 0.001)
	assert_float(int_alta).is_less(int_baja)


func test_apoyado_sobre_dos_superficies_a_distinta_altura_cada_grupo_usa_la_suya() -> void:
	_piso()
	var radio := Oclusion.RADIO_POR_DEFECTO
	var escalon_alto := radio * 0.5
	var escalon_ancho := radio * 3.0
	var separacion := radio * 8.0
	var escalon: StaticBody3D = auto_free(StaticBody3D.new())
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(escalon_ancho, escalon_alto, escalon_ancho)
	forma.shape = caja
	escalon.add_child(forma)
	add_child(escalon)
	escalon.global_position = Vector3(separacion / 2.0, escalon_alto / 2.0, 0.0)
	var pie := Vector3(radio, radio, radio)
	var mallas_cfg: Array[Array] = [
		[_bloque(pie), Transform3D(Basis.IDENTITY, Vector3(-separacion / 2.0, radio / 2.0, 0.0))],
		[
			_bloque(pie),
			Transform3D(Basis.IDENTITY, Vector3(separacion / 2.0, escalon_alto + radio / 2.0, 0.0)),
		],
	]
	var oclusion := _cuerpo_con_mallas(mallas_cfg, Transform3D.IDENTITY)
	await _esperar()
	var visibles := _sombras_visibles(oclusion)
	assert_int(visibles.size()).is_equal(2)
	var en_piso := _sombra_en_x(visibles, -separacion / 2.0)
	var en_escalon := _sombra_en_x(visibles, separacion / 2.0)
	assert_float(en_piso.global_position.y).is_equal_approx(Oclusion.ELEVACION, 0.002)
	assert_float(en_escalon.global_position.y).is_equal_approx(
		escalon_alto + Oclusion.ELEVACION, 0.002
	)
	var int_escalon: float = (en_escalon.material_override as ShaderMaterial).get_shader_parameter(
		&"intensidad"
	)
	assert_float(int_escalon).is_equal_approx(oclusion.intensidad_a(0.0), 0.001)


func test_trasladar_en_la_mano_sin_girar_no_recalcula_los_grupos() -> void:
	_piso()
	var oclusion := _tablon(Transform3D(Basis.IDENTITY, Vector3.UP * 2.0))
	await _esperar()
	var calculos_iniciales: int = oclusion.get("calculos_de_apoyo")
	assert_int(calculos_iniciales).is_equal(1)
	var cuerpo := oclusion.get_parent() as Node3D
	for paso in 5:
		cuerpo.global_position += Vector3(0.2, 0.0, 0.1)
		await _esperar()
	assert_int(oclusion.get("calculos_de_apoyo")).is_equal(calculos_iniciales)
	cuerpo.global_basis = Basis(Vector3.RIGHT, PI / 2.0)
	await _esperar()
	assert_int(oclusion.get("calculos_de_apoyo")).is_greater(calculos_iniciales)


func test_un_objeto_alargado_girado_sobre_su_eje_mantiene_huellas_ajustadas() -> void:
	_piso()
	var radio := Oclusion.RADIO_POR_DEFECTO
	var largo := radio * 18.0
	var ancho_fino := radio * 0.6
	var ancho_grueso := radio * 2.0
	var mallas_cfg: Array[Array] = [
		[
			_bloque(Vector3(ancho_grueso, radio, ancho_grueso)),
			Transform3D(Basis.IDENTITY, Vector3(0.0, -largo / 2.0, 0.0)),
		],
		[
			_bloque(Vector3(ancho_fino, radio * 2.0, ancho_fino)),
			Transform3D(Basis.IDENTITY, Vector3(0.0, largo / 2.0, 0.0)),
		],
	]
	var inclinacion := atan2(ancho_grueso - ancho_fino, 2.0 * largo)
	var base_acostada := Basis(Vector3.RIGHT, PI / 2.0 + inclinacion)
	var oclusion := _cuerpo_con_mallas(mallas_cfg, Transform3D.IDENTITY)
	var cuerpo := oclusion.get_parent() as Node3D
	for grados: float in [0.0, 45.0, 84.0, 90.0]:
		var giro := base_acostada * Basis(Vector3.UP, deg_to_rad(grados))
		cuerpo.global_transform = Transform3D(giro, Vector3(0.0, ancho_grueso / 2.0, 0.0))
		await _esperar()
		var visibles := _sombras_visibles(oclusion)
		assert_int(visibles.size()).is_equal(2)
		for sombra in visibles:
			var huella: Vector2 = (sombra.material_override as ShaderMaterial).get_shader_parameter(
				&"huella"
			)
			assert_float(maxf(huella.x, huella.y)).is_less(largo * 0.25)
			assert_bool(_cubre_en_xz(sombra, Vector3.ZERO)).is_false()
