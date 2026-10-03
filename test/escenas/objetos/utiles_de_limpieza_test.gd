## Los útiles de limpieza en el almacén: son las mallas del modelo, arrancan cada noche en el baño,
## y el balde y la mopa muestran lo que el piso dice que tienen.
##
## Los gestos se dan como en el juego: la mira enfoca algo y llega el clic derecho. La mira se
## apaga para que el caso decida qué se enfoca, y el clic entra por la acción, no por el botón.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const UtilDeLimpieza := preload("res://src/escenas/objetos/util_de_limpieza.gd")

const LAVATORIO := "Estructura/vanitory/StaticBody3D"
const INODORO := "Estructura/inodoro/StaticBody3D"

## Justo adentro de la puerta del baño, del lado del cuarto: desde acá se ve todo lo que hay en él.
const ENTRADA_DEL_BANO := Vector3(8.8, 1.05, -4.658)

## Cuánto puede quedar lo apoyado por encima del piso, en metros.
const APOYADO := 0.005

## Adonde se llevan los útiles para probar que la noche siguiente vuelven: el local y el depósito.
const EN_EL_LOCAL := Vector3(0.0, 1.0, 3.0)
const EN_EL_DEPOSITO := Vector3(2.0, 1.0, -11.0)


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	return almacen


func _util(almacen: Node3D, nombre: String) -> UtilDeLimpieza:
	for util: UtilDeLimpieza in almacen.get("_utiles_de_limpieza"):
		if util.name == nombre:
			return util
	return null


## Le pone el foco al objetivo y le manda la acción, que es lo que hace el clic de verdad.
func _accion(almacen: Node3D, objetivo: Node3D, accion: StringName) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


## Agarra el útil, lo usa sobre el objetivo y lo vuelve a soltar.
func _usar(almacen: Node3D, util: Node3D, objetivo: Node3D) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(util.get("datos"), util)).is_true()
	_accion(almacen, objetivo, ReglasDelJugador.ACCION_USAR)
	agarre.soltar(true)


func _piso(almacen: Node3D) -> PisoDelLocal:
	return (almacen.get("_limpiador") as Limpiador).piso()


func test_cada_util_es_la_malla_del_modelo_donde_el_modelo_la_dibujaba() -> void:
	# **Sin copia en el medio**: la malla es el mismo recurso que el modelo trae, y queda donde el
	# modelo la dibujaba, apoyada en el piso. Una copia quedaría vieja el día que el artista toque
	# el balde.
	var almacen: Node3D = await _almacen()
	var utiles: Array = almacen.get("_utiles_de_limpieza")
	assert_int(utiles.size()).is_equal(5)
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Deposito")
	var piso := suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0
	for util: UtilDeLimpieza in utiles:
		var del_modelo: MeshInstance3D = almacen.get_node("Estructura/" + util.nodo_del_modelo)
		assert_object(util.malla.mesh).override_failure_message(util.name).is_not_null()
		assert_object(util.malla.mesh).is_same(del_modelo.mesh)
		# Donde lo pone la escena, y no donde quedó: al apoyarse, la física asienta la mopa unas
		# centésimas de milímetro. Medido el 2026-09-30: 0,08 mm en los primeros dos cuadros.
		var puesta := util.lugar_de_origen() * util.malla.transform
		(
			assert_bool(puesta.basis.is_equal_approx(del_modelo.global_basis))
			. override_failure_message("`%s` no está girado como en el modelo" % util.name)
			. is_true()
		)
		var aca := puesta.origin
		var alla := del_modelo.global_position
		(
			assert_float(Vector2(aca.x, aca.z).distance_to(Vector2(alla.x, alla.z)))
			. override_failure_message("`%s` no está donde lo dibujaba el modelo" % util.name)
			. is_less(0.001)
		)
		var abajo := (util.malla.global_transform * util.malla.get_aabb()).position.y
		(
			assert_float(abajo - piso)
			. override_failure_message("`%s` queda a %.3f m del piso" % [util.name, abajo - piso])
			. is_between(-APOYADO, APOYADO)
		)


func test_la_copia_fija_del_modelo_ni_se_ve_ni_choca() -> void:
	# Si cualquiera de las dos viajara, el útil se dibujaría dos veces o chocaría con su fantasma.
	var almacen: Node3D = await _almacen()
	for util: UtilDeLimpieza in almacen.get("_utiles_de_limpieza"):
		var del_modelo: MeshInstance3D = almacen.get_node("Estructura/" + util.nodo_del_modelo)
		assert_bool(del_modelo.visible).override_failure_message(util.name).is_false()
		for forma: CollisionShape3D in del_modelo.find_children(
			"*", "CollisionShape3D", true, false
		):
			(
				assert_bool(forma.disabled)
				. override_failure_message("`%s` sigue siendo un sólido fijo" % del_modelo.name)
				. is_true()
			)


func test_los_utiles_arrancan_en_el_bano() -> void:  # AC-CLN-018
	# Desde adentro de la puerta del baño se ve cada útil sin una pared en el medio: están en el
	# cuarto, y no del otro lado de un tabique.
	var almacen: Node3D = await _almacen()
	var espacio := almacen.get_world_3d().direct_space_state
	var sueltos: Array[RID] = []
	for cuerpo: PhysicsBody3D in almacen.get("_utiles_de_limpieza") + almacen.get("_bolsas"):
		sueltos.append(cuerpo.get_rid())
	for util: Node3D in almacen.get("_utiles_de_limpieza"):
		var rayo := PhysicsRayQueryParameters3D.create(ENTRADA_DEL_BANO, util.global_position)
		rayo.exclude = sueltos
		var golpe := espacio.intersect_ray(rayo)
		(
			assert_bool(golpe.is_empty())
			. override_failure_message(
				(
					"`%s` no se ve desde la puerta del baño: tapa %s"
					% [util.name, golpe.get("collider")]
				)
			)
			. is_true()
		)


func test_abrir_la_jornada_devuelve_los_utiles_al_bano_vacios_y_secos() -> void:  # AC-CLN-018
	var almacen: Node3D = await _almacen()
	var utiles: Array = almacen.get("_utiles_de_limpieza")
	var balde := _util(almacen, "Balde")
	var mopa := _util(almacen, "Mopa")
	_usar(almacen, balde, almacen.get_node(LAVATORIO))
	_usar(almacen, _util(almacen, "JabonAzul"), balde)
	_usar(almacen, mopa, balde)
	assert_bool(balde.carga.visible).is_true()
	assert_bool(mopa.carga.visible).is_true()
	mopa.global_position = EN_EL_LOCAL
	balde.global_position = EN_EL_DEPOSITO
	var agarre: Agarre = almacen.get("_agarre")
	var jabon := _util(almacen, "JabonRosa")
	assert_bool(agarre.pedir_agarrar(jabon.datos, jabon)).is_true()
	almacen.get("_ciclo").abrir_la_jornada()
	assert_object(agarre.manos().sostenido()).is_null()
	for util: UtilDeLimpieza in utiles:
		(
			assert_bool(util.global_transform.is_equal_approx(util.lugar_de_origen()))
			. override_failure_message(
				"`%s` abrió la jornada en %v" % [util.name, util.global_position]
			)
			. is_true()
		)
	assert_bool(balde.carga.visible).is_false()
	assert_bool(mopa.carga.visible).is_false()
	assert_bool(_piso(almacen).balde().tiene_agua()).is_false()
	assert_bool(_piso(almacen).mopa().esta_mojada()).is_false()


func test_el_lavatorio_y_el_inodoro_se_enfocan_y_no_se_levantan() -> void:  # AC-CLN-018
	var almacen: Node3D = await _almacen()
	var agarre: Agarre = almacen.get("_agarre")
	var rechazos: Array[Manos.Rechazo] = []
	agarre.agarre_rechazado.connect(func(motivo: Manos.Rechazo) -> void: rechazos.append(motivo))
	var destinos := {
		LAVATORIO: ReglasDeLaLimpieza.ID_DEL_LAVATORIO,
		INODORO: ReglasDeLaLimpieza.ID_DEL_INODORO,
	}
	for ruta: String in destinos:
		var artefacto: Node3D = almacen.get_node(ruta)
		assert_bool(artefacto.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
		assert_str(String(artefacto.call("destino_del_uso"))).is_equal(String(destinos[ruta]))
		_accion(almacen, artefacto, ReglasDeLosObjetos.ACCION_AGARRAR)
		assert_object(agarre.manos().sostenido()).is_null()
	assert_array(rechazos).is_equal(
		[Manos.Rechazo.NO_ES_LEVANTABLE, Manos.Rechazo.NO_ES_LEVANTABLE]
	)


func test_el_agua_del_balde_se_ve_celeste_y_despues_del_color_del_jabon() -> void:  # AC-CLN-019
	var almacen: Node3D = await _almacen()
	var balde := _util(almacen, "Balde")
	assert_bool(balde.carga.visible).is_false()
	_usar(almacen, balde, almacen.get_node(LAVATORIO))
	assert_bool(balde.carga.visible).is_true()
	var celeste: Color = balde.color_de_la_carga()
	assert_float(celeste.b).is_greater_equal(celeste.g)
	assert_float(celeste.b).is_greater(celeste.r)
	assert_float(minf(celeste.r, minf(celeste.g, celeste.b))).is_greater_equal(0.6)
	_usar(almacen, _util(almacen, "JabonRosa"), balde)
	var rosa: Color = balde.color_de_la_carga()
	assert_that(rosa).is_equal(ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.ROSA])


func test_un_segundo_jabon_no_cambia_el_agua_que_se_ve() -> void:  # AC-CLN-020
	var almacen: Node3D = await _almacen()
	var balde := _util(almacen, "Balde")
	_usar(almacen, balde, almacen.get_node(LAVATORIO))
	_usar(almacen, _util(almacen, "JabonRosa"), balde)
	_usar(almacen, _util(almacen, "JabonAmarillo"), balde)
	var agua: Color = balde.color_de_la_carga()
	assert_that(agua).is_equal(ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.ROSA])


func test_vaciar_en_el_inodoro_esconde_el_agua() -> void:  # AC-CLN-021
	var almacen: Node3D = await _almacen()
	var balde := _util(almacen, "Balde")
	_usar(almacen, balde, almacen.get_node(LAVATORIO))
	_usar(almacen, _util(almacen, "JabonRosa"), balde)
	_usar(almacen, balde, almacen.get_node(INODORO))
	assert_bool(balde.carga.visible).is_false()
	assert_bool(_piso(almacen).balde().tiene_agua()).is_false()


func test_la_punta_de_la_mopa_se_ve_del_color_del_agua() -> void:  # AC-CLN-022
	var almacen: Node3D = await _almacen()
	var balde := _util(almacen, "Balde")
	var mopa := _util(almacen, "Mopa")
	assert_bool(mopa.carga.visible).is_false()
	_usar(almacen, balde, almacen.get_node(LAVATORIO))
	_usar(almacen, mopa, balde)
	assert_bool(mopa.carga.visible).is_true()
	var punta: Color = (mopa.carga.material_override as StandardMaterial3D).albedo_color
	var agua: Color = balde.color_de_la_carga()
	assert_that(punta).is_equal(agua)
	_usar(almacen, _util(almacen, "JabonAmarillo"), balde)
	_usar(almacen, mopa, balde)
	punta = (mopa.carga.material_override as StandardMaterial3D).albedo_color
	assert_that(punta).is_equal(ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.AMARILLO])


func test_la_mezcla_espera_aunque_se_suelten_los_utiles_en_otro_cuarto() -> void:  # AC-CLN-025
	var almacen: Node3D = await _almacen()
	var balde := _util(almacen, "Balde")
	var mopa := _util(almacen, "Mopa")
	_usar(almacen, balde, almacen.get_node(LAVATORIO))
	_usar(almacen, _util(almacen, "JabonAzul"), balde)
	_usar(almacen, mopa, balde)
	balde.global_position = EN_EL_DEPOSITO
	mopa.global_position = EN_EL_LOCAL
	var agarre: Agarre = almacen.get("_agarre")
	var bolsa: Node3D = almacen.get("_bolsas")[0]
	assert_bool(agarre.pedir_agarrar(bolsa.get("datos"), bolsa)).is_true()
	agarre.soltar(true)
	assert_bool(agarre.pedir_agarrar(balde.datos, balde)).is_true()
	for cuadro in 5:
		await get_tree().physics_frame
	var azul: Color = ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.AZUL]
	assert_int(_piso(almacen).balde().agua()).is_equal(ReglasDeLaLimpieza.Agua.AZUL)
	assert_int(_piso(almacen).mopa().agua()).is_equal(ReglasDeLaLimpieza.Agua.AZUL)
	assert_bool(balde.carga.visible).is_true()
	assert_that(balde.color_de_la_carga()).is_equal(azul)
	assert_bool(mopa.carga.visible).is_true()
	assert_that((mopa.carga.material_override as StandardMaterial3D).albedo_color).is_equal(azul)


func _mopa_en_la_mano(almacen: Node3D, con_agua: bool = true) -> UtilDeLimpieza:
	var jugador: Node3D = almacen.get("_jugador")
	jugador.global_position = Vector3(-1.91, jugador.global_position.y, 5.2)
	var balde := _util(almacen, "Balde")
	if con_agua:
		_usar(almacen, balde, almacen.get_node(LAVATORIO))
	var mopa := _util(almacen, "Mopa")
	assert_bool((almacen.get("_agarre") as Agarre).pedir_agarrar(mopa.datos, mopa)).is_true()
	return mopa


func _camara(almacen: Node3D) -> Camera3D:
	return (almacen.get("_jugador") as Node3D).get_node("Giro/Camara")


func _ver_la_punta(camara: Camera3D, mopa: UtilDeLimpieza) -> void:
	assert_bool(camara.is_position_in_frustum(mopa.carga.global_position)).is_true()


## Pasos explicitos del tween: cinco instantes, sin depender del ritmo del headless.
func _muestrear_la_mojada(almacen: Node3D, mopa: UtilDeLimpieza) -> void:
	var camara := _camara(almacen)
	var antes := Transform3D(mopa.orientacion_en_mano, Vector3.ZERO)
	# El gesto entra en el objetivo real: el jugador debe estar mirando ese balde.
	var objetivo := _util(almacen, "Balde")
	camara.look_at(objetivo.carga.global_position)
	var vista := camara.global_transform
	_accion(almacen, _util(almacen, "Balde"), ReglasDelJugador.ACCION_USAR)
	var bajada: Tween = mopa.get("_bajada")
	assert_object(bajada).is_not_null()
	if bajada == null:
		return
	var termino: Array[bool] = []
	bajada.finished.connect(func() -> void: termino.append(true))
	bajada.pause()
	for instante in 5:
		bajada.custom_step(0.04)
		_ver_la_punta(camara, mopa)
		assert_bool(camara.global_transform.is_equal_approx(vista)).is_true()
	var balde := _util(almacen, "Balde")
	var cabeza := balde.to_local(mopa.carga.global_position)
	assert_float(Vector2(cabeza.x, cabeza.z).length()).is_less(0.001)
	assert_float(cabeza.y).is_equal_approx(0.07, 0.001)
	assert_float(mopa.global_basis.y.angle_to(balde.global_basis.y)).is_less(0.001)
	for instante in 4:
		bajada.custom_step(0.04)
		_ver_la_punta(camara, mopa)
		assert_bool(camara.global_transform.is_equal_approx(vista)).is_true()
	assert_array(termino).is_empty()
	bajada.custom_step(0.04001)
	_ver_la_punta(camara, mopa)
	assert_bool(camara.global_transform.is_equal_approx(vista)).is_true()
	assert_array(termino).is_equal([true])
	assert_float(bajada.get_total_elapsed_time()).is_equal_approx(0.4, 0.0001)
	assert_bool(mopa.transform.is_equal_approx(antes)).is_true()
	assert_that((mopa.carga.material_override as StandardMaterial3D).albedo_color).is_equal(
		_piso(almacen).balde().color()
	)


func test_la_cabeza_de_la_mopa_se_ve_y_el_agarre_sigue_en_el_origen() -> void:
	var almacen: Node3D = await _almacen()
	var mopa := _mopa_en_la_mano(almacen)
	assert_bool(_camara(almacen).is_position_in_frustum(mopa.carga.global_position)).is_true()
	assert_vector(mopa.position).is_equal(Vector3.ZERO)
	assert_bool(mopa.basis.is_equal_approx(mopa.orientacion_en_mano)).is_true()
	var abajo := (mopa.malla.global_transform * mopa.malla.get_aabb()).position.y
	assert_float(abajo).is_greater(0.1)


func test_mojar_baja_la_punta_a_la_vista_y_vuelve_sin_mover_la_camara() -> void:
	var almacen: Node3D = await _almacen()
	var mopa := _mopa_en_la_mano(almacen)
	assert_bool(_piso(almacen).balde().tiene_agua()).is_true()
	_muestrear_la_mojada(almacen, mopa)


func test_la_punta_sigue_a_la_vista_con_el_brazo_acortado_y_mirando_abajo() -> void:
	var almacen: Node3D = await _almacen()
	var mopa := _mopa_en_la_mano(almacen)
	var camara := _camara(almacen)
	camara.rotation.x = deg_to_rad(-40.0)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_process(false)
	var balde := _util(almacen, "Balde")
	balde.freeze = true
	var brazo: SpringArm3D = camara.get_node("BrazoDeCarga")
	balde.global_position = brazo.global_transform * Vector3(0.0, 0.0, 0.45)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(brazo.get_hit_length()).is_less(brazo.spring_length / 2.0)
	jugador.call("_acomodar_las_manos", 1.0)
	var ancla := mopa.get_parent() as Node3D
	assert_float(ancla.position.z).is_greater(-0.3)
	_muestrear_la_mojada(almacen, mopa)


func test_rechazar_el_mojado_no_mueve_la_mopa() -> void:
	var almacen: Node3D = await _almacen()
	var mopa := _mopa_en_la_mano(almacen, false)
	var antes := mopa.transform
	for destino: Node3D in [_util(almacen, "Balde"), almacen.get_node(INODORO)]:
		_accion(almacen, destino, ReglasDelJugador.ACCION_USAR)
		await get_tree().process_frame
		assert_bool(mopa.transform.is_equal_approx(antes)).is_true()
		assert_object(mopa.get("_bajada")).is_null()


func test_mojar_dos_veces_reinicia_sin_acumular_desplazamiento() -> void:
	var almacen: Node3D = await _almacen()
	var mopa := _mopa_en_la_mano(almacen)
	var antes := mopa.transform
	_accion(almacen, _util(almacen, "Balde"), ReglasDelJugador.ACCION_USAR)
	var primera: Tween = mopa.get("_bajada")
	assert_object(primera).is_not_null()
	if primera == null:
		return
	primera.pause()
	primera.custom_step(0.1)
	_muestrear_la_mojada(almacen, mopa)
	assert_bool(primera.is_valid()).is_false()
	assert_bool(mopa.transform.is_equal_approx(antes)).is_true()


func test_soltar_a_mitad_del_mojado_mata_el_tween_y_conserva_la_orientacion() -> void:
	var almacen: Node3D = await _almacen()
	var mopa := _mopa_en_la_mano(almacen)
	_accion(almacen, _util(almacen, "Balde"), ReglasDelJugador.ACCION_USAR)
	var bajada: Tween = mopa.get("_bajada")
	assert_object(bajada).is_not_null()
	if bajada == null:
		return
	bajada.pause()
	bajada.custom_step(0.1)
	var orientacion := mopa.global_basis
	var agarre: Agarre = almacen.get("_agarre")
	agarre.soltar(true)
	assert_bool(bajada.is_valid()).is_false()
	assert_bool(mopa.global_basis.is_equal_approx(orientacion)).is_true()
	var soltada := mopa.global_transform
	bajada.custom_step(0.2)
	assert_bool(mopa.global_transform.is_equal_approx(soltada)).is_true()
	assert_bool(agarre.pedir_agarrar(mopa.datos, mopa)).is_true()
	assert_vector(mopa.position).is_equal(Vector3.ZERO)
	assert_bool(mopa.basis.is_equal_approx(mopa.orientacion_en_mano)).is_true()


func test_mojar_con_el_balde_en_el_piso_y_la_vista_abajo_mantiene_la_punta_visible() -> void:
	var almacen: Node3D = await _almacen()
	var mopa := _mopa_en_la_mano(almacen)
	var camara := _camara(almacen)
	camara.rotation.x = deg_to_rad(-40.0)
	var balde := _util(almacen, "Balde")
	balde.freeze = true
	var forma := balde.get_node("Forma") as CollisionShape3D
	var base := (forma.transform * forma.shape.get_debug_mesh().get_aabb()).position.y
	var suelo := almacen.get_node("Estructura/SueloSolido/Local") as CollisionShape3D
	var piso := suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0
	var jugador: Node3D = almacen.get("_jugador")
	balde.global_basis = Basis.IDENTITY
	balde.global_position = Vector3(
		jugador.global_position.x, piso - base, jugador.global_position.z - 0.7
	)
	assert_float(balde.global_position.y + base).is_equal_approx(piso, 0.001)
	_muestrear_la_mojada(almacen, mopa)
	# El arbol retira los tweens terminados en el cuadro siguiente.
	await get_tree().process_frame
	await get_tree().process_frame


func test_la_mopa_soltada_entre_dos_paredes_no_atraviesa_la_de_atras() -> void:
	var almacen: Node3D = await _almacen()
	var mopa := _mopa_en_la_mano(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_process(false)
	var camara := _camara(almacen)
	var ojo := camara.global_transform
	_util(almacen, "Balde").global_position += Vector3.RIGHT * 5.0
	for distancia: float in [-0.5, 0.3]:
		var pared := StaticBody3D.new()
		var forma := CollisionShape3D.new()
		var volumen := BoxShape3D.new()
		volumen.size = Vector3(4.0, 4.0, 0.05)
		forma.shape = volumen
		pared.add_child(forma)
		almacen.add_child(pared)
		pared.global_transform = Transform3D(ojo.basis, ojo.origin + ojo.basis.z * distancia)
		assert_float(ojo.origin.distance_to(pared.global_position)).is_equal_approx(
			absf(distancia), 0.001
		)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var forma := mopa.get_node("Forma") as CollisionShape3D
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = Transform3D(mopa.global_basis, ojo.origin) * forma.transform
	consulta.collision_mask = ReglasDeLosObjetos.CAPA_DEL_CONTORNO | 1
	consulta.exclude = [mopa.get_rid()]
	var espacio := almacen.get_world_3d().direct_space_state
	# La forma en el ojo ya toca la pared de adelante: es la premisa que falla en cast_motion.
	assert_bool(espacio.intersect_shape(consulta, 1).is_empty()).is_false()
	var agarre: Agarre = almacen.get("_agarre")
	agarre.soltar(true)
	assert_object(agarre.manos().sostenido()).is_null()
	consulta.transform = forma.global_transform
	consulta.collision_mask = mopa.collision_mask | (jugador as CollisionObject3D).collision_layer
	assert_array(espacio.intersect_shape(consulta)).is_empty()
	assert_float(ojo.basis.z.dot(mopa.global_position - ojo.origin)).is_less(0.3)
	await get_tree().process_frame
	await get_tree().process_frame
