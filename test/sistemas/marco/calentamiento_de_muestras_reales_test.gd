extends GdUnitTestSuite

const ESPERA_MS := 5000
const CONTORNO := preload("res://src/sistemas/marco/contorno.gdshader")


## Una escena que deja algunos cuerpos para otra carga, como el almacén con los útiles.
class EscenaConPostergados:
	extends Node3D

	var postergados: Array[Node3D] = []

	func cuerpos_sin_copias() -> Array[Node3D]:
		return postergados


func _escena() -> Node3D:
	var escena: Node3D = auto_free(Node3D.new())
	add_child(escena)
	return escena


func _movible(escena: Node3D, malla: Mesh, lugar: Vector3) -> MeshInstance3D:
	var cuerpo := RigidBody3D.new()
	cuerpo.freeze = true
	cuerpo.position = lugar
	escena.add_child(cuerpo)
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	instancia.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	cuerpo.add_child(instancia)
	return instancia


func _calentamiento() -> CalentamientoDeShaders:
	var calentamiento: CalentamientoDeShaders = auto_free(CalentamientoDeShaders.new())
	calentamiento.unifica_variantes = func() -> bool: return false
	add_child(calentamiento)
	return calentamiento


func _caja(objeto: GeometryInstance3D) -> AABB:
	var caja := objeto.custom_aabb
	if caja == AABB():
		caja = objeto.get_aabb()
	return objeto.global_transform * caja


func _caja_de_la_sonda(sonda: ReflectionProbe) -> AABB:
	return sonda.global_transform * AABB(-sonda.size / 2.0, sonda.size)


func _muestras_visibles(
	calentamiento: CalentamientoDeShaders, malla: Mesh
) -> Array[MeshInstance3D]:
	var visibles: Array[MeshInstance3D] = []
	for muestra: MeshInstance3D in calentamiento.find_children("*", "MeshInstance3D", true, false):
		if muestra.visible and muestra.mesh == malla:
			visibles.append(muestra)
	return visibles


func test_el_movible_delgado_se_dibuja_entre_dos_sondas_sin_mover_el_real() -> void:
	var escena := _escena()
	var sondas: Array[ReflectionProbe] = []
	for x: float in [-1.015, 1.015]:
		var sonda := ReflectionProbe.new()
		sonda.position = Vector3(x, 1, 0)
		sonda.size = Vector3(2, 2, 2)
		escena.add_child(sonda)
		sondas.append(sonda)
	assert_bool(_caja_de_la_sonda(sondas[0]).intersects(_caja_de_la_sonda(sondas[1]))).is_false()
	var palo := BoxMesh.new()
	palo.size = Vector3(0.02, 1.2, 0.02)
	var mopa := _movible(escena, palo, Vector3(10, 1, 0))
	var pintura := ShaderMaterial.new()
	pintura.shader = CONTORNO
	mopa.set_surface_override_material(0, pintura)
	var original := mopa.global_transform
	var calentamiento := _calentamiento()
	var en_la_costura: Array[MeshInstance3D] = []
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for muestra: MeshInstance3D in _muestras_visibles(calentamiento, palo):
				assert_object(muestra.get_active_material(0)).is_same(pintura)
				if sondas.all(
					func(sonda: ReflectionProbe) -> bool:
						return _caja_de_la_sonda(sonda).intersects(_caja(muestra))
				):
					en_la_costura.append(muestra)
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_array(en_la_costura).is_not_empty()
	assert_that(mopa.global_transform).is_equal(original)
	for sonda: ReflectionProbe in sondas:
		assert_int(sonda.update_mode).is_equal(ReflectionProbe.UPDATE_ONCE)
	await get_tree().process_frame
	for muestra: MeshInstance3D in en_la_costura:
		assert_bool(is_instance_valid(muestra)).is_false()


## La omni de una heladera es hija de su malla. Ocultar la malla la apagaba, y la muestra que
## pasaba por la heladera se dibujaba sin ella.
func test_la_omni_hija_de_una_malla_alcanza_a_las_muestras() -> void:
	var escena := _escena()
	var heladera := MeshInstance3D.new()
	heladera.mesh = BoxMesh.new()
	heladera.position = Vector3(5, 1, 0)
	escena.add_child(heladera)
	var omni := OmniLight3D.new()
	omni.shadow_enabled = true
	omni.omni_range = 1.5
	heladera.add_child(omni)
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE * 0.2
	_movible(escena, caja, Vector3(-5, 1, 0))
	var calentamiento := _calentamiento()
	var con_la_omni := [false]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for muestra: MeshInstance3D in _muestras_visibles(calentamiento, caja):
				var cerca := omni.global_position.clamp(_caja(muestra).position, _caja(muestra).end)
				if cerca.distance_to(omni.global_position) < omni.omni_range:
					assert_bool(heladera.visible).is_true()
					assert_bool(omni.is_visible_in_tree()).is_true()
					con_la_omni[0] = true
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(con_la_omni[0]).is_true()
	assert_bool(omni.visible).is_true()


func test_cada_combinacion_real_de_dos_luces_tiene_su_muestra() -> void:
	var escena := _escena()
	var luces: Array[OmniLight3D] = []
	for x: float in [-1.0, 1.0]:
		var omni := OmniLight3D.new()
		omni.position = Vector3(x, 1, 0)
		omni.omni_range = 1.5
		omni.shadow_enabled = x > 0.0
		escena.add_child(omni)
		luces.append(omni)
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE * 0.1
	_movible(escena, caja, Vector3(0, 1, 6))
	var calentamiento := _calentamiento()
	var combinaciones: Dictionary[int, bool] = {}
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for omni: OmniLight3D in luces:
				assert_bool(omni.visible).is_true()
				assert_float(omni.omni_range).is_equal(1.5)
			for muestra: MeshInstance3D in _muestras_visibles(calentamiento, caja):
				var combinacion := 0
				for indice: int in luces.size():
					var luz := luces[indice]
					var cerca := luz.global_position.clamp(
						_caja(muestra).position, _caja(muestra).end
					)
					if cerca.distance_to(luz.global_position) < luz.omni_range:
						combinacion |= 1 << indice
				combinaciones[combinacion] = true
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_array(combinaciones.keys()).contains_exactly_in_any_order([0, 1, 2, 3])


func test_las_muestras_destapan_a_lo_sumo_cuatro_materiales_nuevos_por_cuadro() -> void:
	var escena := _escena()
	var caja := BoxMesh.new()
	for indice: int in 6:
		var movible := _movible(escena, caja, Vector3(indice * 3.0, 0, 0))
		var material := ShaderMaterial.new()
		material.shader = Shader.new()
		material.shader.code = "shader_type spatial;"
		movible.material_override = material
	var calentamiento := _calentamiento()
	var vistos: Dictionary[Material, bool] = {}
	var mayor := [0]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			var nuevos := 0
			for muestra: MeshInstance3D in _muestras_visibles(calentamiento, caja):
				if not vistos.has(muestra.material_override):
					vistos[muestra.material_override] = true
					nuevos += 1
			mayor[0] = maxi(mayor[0], nuevos)
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_int(vistos.size()).is_equal(6)
	assert_int(mayor[0]).is_between(1, CalentamientoDeShaders.MATERIALES_NUEVOS_POR_CUADRO)


func test_el_contorno_del_foco_se_dibuja_en_cada_interactuable_y_se_retira() -> void:
	var escena := _escena()
	var puerta := Node3D.new()
	puerta.add_to_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
	escena.add_child(puerta)
	var hoja := MeshInstance3D.new()
	hoja.mesh = BoxMesh.new()
	var previo := StandardMaterial3D.new()
	hoja.material_overlay = previo
	puerta.add_child(hoja)
	var calentamiento := _calentamiento()
	var con_contorno := [false]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			var encima := hoja.material_overlay as ShaderMaterial
			if hoja.visible and encima != null and encima.shader == CONTORNO:
				con_contorno[0] = true
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(con_contorno[0]).is_true()
	assert_object(hoja.material_overlay).is_same(previo)


func test_el_movible_se_dibuja_junto_a_la_cara_de_la_sonda_por_fuera() -> void:
	var escena := _escena()
	var sonda := ReflectionProbe.new()
	sonda.position = Vector3(0, 1, 0)
	sonda.size = Vector3(4, 2, 4)
	escena.add_child(sonda)
	var local := MeshInstance3D.new()
	local.mesh = BoxMesh.new()
	local.mesh.size = Vector3(4, 2.4, 4)
	local.position = Vector3(0, 1.2, 0)
	local.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	escena.add_child(local)
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE * 0.2
	_movible(escena, caja, Vector3(0, 1, 0))
	var volumen := local.global_transform * local.get_aabb()
	var calentamiento := _calentamiento()
	var en_la_franja := [false]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for muestra: MeshInstance3D in _muestras_visibles(calentamiento, caja):
				var suya := _caja(muestra)
				if (
					not suya.intersects(_caja_de_la_sonda(sonda))
					and volumen.has_point(suya.get_center())
				):
					en_la_franja[0] = true
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(en_la_franja[0]).is_true()


## La cámara del jugador recorta las luces que no ve, y el motor las saca de cada objeto ese
## cuadro: la variante cambia aunque nada se mueva. Se mira desde adentro de cada sonda.
func test_se_mira_desde_cada_sonda_con_la_escena_a_la_vista() -> void:
	var escena := _escena()
	var sonda := ReflectionProbe.new()
	sonda.position = Vector3(3, 1.5, 0)
	sonda.size = Vector3(4, 3, 4)
	escena.add_child(sonda)
	var estante := MeshInstance3D.new()
	estante.mesh = BoxMesh.new()
	escena.add_child(estante)
	var del_jugador := Camera3D.new()
	escena.add_child(del_jugador)
	del_jugador.make_current()
	var calentamiento := _calentamiento()
	var miradas: Dictionary[Vector3, bool] = {}
	var termino := [false]
	calentamiento.terminado.connect(func() -> void: termino[0] = true)
	calentamiento.calentar(escena)
	for _cuadro: int in 600:
		if termino[0]:
			break
		var camara := get_viewport().get_camera_3d()
		if (
			camara != del_jugador
			and camara.projection == Camera3D.PROJECTION_PERSPECTIVE
			and camara.global_position.is_equal_approx(sonda.global_position)
			and estante.visible
		):
			miradas[(-camara.global_basis.z).snappedf(0.1)] = true
		await get_tree().process_frame
	assert_bool(termino[0]).is_true()
	assert_int(miradas.size()).is_greater_equal(6)
	assert_object(get_viewport().get_camera_3d()).is_same(del_jugador)


func test_cancelar_mientras_mira_restaura_la_camara_y_el_contorno() -> void:
	var escena := _escena()
	var sonda := ReflectionProbe.new()
	sonda.size = Vector3(4, 3, 4)
	escena.add_child(sonda)
	var puerta := Node3D.new()
	puerta.add_to_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
	escena.add_child(puerta)
	var hoja := MeshInstance3D.new()
	hoja.mesh = BoxMesh.new()
	puerta.add_child(hoja)
	var del_jugador := Camera3D.new()
	escena.add_child(del_jugador)
	del_jugador.make_current()
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	var mirando := false
	for _cuadro: int in 600:
		var camara := get_viewport().get_camera_3d()
		if camara != del_jugador and camara.projection == Camera3D.PROJECTION_PERSPECTIVE:
			mirando = true
			break
		await get_tree().process_frame
	assert_bool(mirando).is_true()
	assert_object(hoja.material_overlay).is_not_null()
	calentamiento.queue_free()
	await get_tree().process_frame
	assert_object(get_viewport().get_camera_3d()).is_same(del_jugador)
	assert_object(hoja.material_overlay).is_null()


func _sondas_que_recibe(muestra: GeometryInstance3D, sondas: Array[ReflectionProbe]) -> int:
	var cuantas := 0
	for sonda: ReflectionProbe in sondas:
		if (
			sonda.reflection_mask & muestra.layers
			and _caja_de_la_sonda(sonda).intersects(_caja(muestra))
		):
			cuantas += 1
	return mini(cuantas, 2)


## Una sonda cuya máscara no incluye la capa del objeto no lo refleja. Contarla juntaba dos
## lugares distintos en una sola muestra: el cuartito tiene la suya sólo para su capa.
func test_la_sonda_de_otra_capa_no_cuenta_para_la_muestra() -> void:
	var escena := _escena()
	var sondas: Array[ReflectionProbe] = []
	for datos: Array in [
		[Vector3(0, 1.5, 0), Vector3(8, 3, 8), 1048575],
		[Vector3(0, 1.5, 0), Vector3(8, 3, 8), 4],
		[Vector3(2, 1.5, 0), Vector3(2, 3, 2), 1048575],
	]:
		var sonda := ReflectionProbe.new()
		sonda.position = datos[0]
		sonda.size = datos[1]
		sonda.reflection_mask = datos[2]
		escena.add_child(sonda)
		sondas.append(sonda)
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE * 0.2
	var movible := _movible(escena, caja, Vector3(-3, 1, 0))
	assert_int(movible.layers & sondas[1].reflection_mask).is_zero()
	var calentamiento := _calentamiento()
	var cuantas: Dictionary[int, bool] = {}
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for muestra: MeshInstance3D in _muestras_visibles(calentamiento, caja):
				cuantas[_sondas_que_recibe(muestra, sondas)] = true
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_array(cuantas.keys()).contains([1, 2])


func _frustum_corta_esfera(planos: Array[Plane], centro: Vector3, radio: float) -> bool:
	return planos.all(func(plano: Plane) -> bool: return plano.distance_to(centro) < radio)


## Lo de afuera se ve desde adentro con alguna luz en cuadro, y desde la vereda sin ninguna: la
## cámara recorta la luz y el objeto compila otra variante.
func test_lo_estatico_fuera_de_las_sondas_se_mira_sin_ninguna_luz_en_cuadro() -> void:
	var escena := _escena()
	var sonda := ReflectionProbe.new()
	sonda.position = Vector3(0, 1.5, 0)
	sonda.size = Vector3(4, 3, 4)
	escena.add_child(sonda)
	var omni := OmniLight3D.new()
	omni.position = Vector3(0, 1.5, 0)
	omni.omni_range = 3.0
	escena.add_child(omni)
	var vereda := MeshInstance3D.new()
	vereda.mesh = BoxMesh.new()
	vereda.position = Vector3(8, 0.5, 0)
	vereda.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	escena.add_child(vereda)
	var del_jugador := Camera3D.new()
	escena.add_child(del_jugador)
	del_jugador.make_current()
	var calentamiento := _calentamiento()
	var sin_luces := [false]
	var termino := [false]
	calentamiento.terminado.connect(func() -> void: termino[0] = true)
	calentamiento.calentar(escena)
	for _cuadro: int in 600:
		if termino[0]:
			break
		var camara := get_viewport().get_camera_3d()
		if camara != del_jugador and camara.projection == Camera3D.PROJECTION_PERSPECTIVE:
			var planos: Array[Plane] = camara.get_frustum()
			var caja := _caja(vereda)
			if (
				vereda.visible
				and _frustum_corta_esfera(planos, caja.get_center(), caja.size.length() / 2.0)
				and not _frustum_corta_esfera(planos, omni.global_position, omni.omni_range)
			):
				sin_luces[0] = true
		await get_tree().process_frame
	assert_bool(termino[0]).is_true()
	assert_bool(sin_luces[0]).is_true()


func _planos_de(camara: Camera3D) -> Array[Plane]:
	var proyeccion := camara.get_camera_projection()
	var planos: Array[Plane] = []
	for indice: int in 6:
		planos.append(camara.global_transform * proyeccion.get_projection_plane(indice))
	return planos


## Cuántas poses distintas de la cámara miran alguna vereda sin la luz en cuadro. Cada vereda
## queda lejos de la otra, y una misma pose no puede ver las dos.
func _poses_sin_la_luz(materiales: Array[Material]) -> int:
	var escena := _escena()
	var sonda := ReflectionProbe.new()
	sonda.position = Vector3(0, 1.5, 0)
	sonda.size = Vector3(4, 3, 4)
	escena.add_child(sonda)
	var omni := OmniLight3D.new()
	omni.position = Vector3(0, 1.5, 0)
	omni.omni_range = 3.0
	escena.add_child(omni)
	var veredas: Array[MeshInstance3D] = []
	for indice: int in materiales.size():
		var malla := BoxMesh.new()
		malla.size = Vector3.ONE * (1.0 + indice)
		var vereda := MeshInstance3D.new()
		vereda.mesh = malla
		vereda.material_override = materiales[indice]
		vereda.position = Vector3(8.0 if indice == 0 else -8.0, 0.5, 0)
		vereda.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		escena.add_child(vereda)
		veredas.append(vereda)
	var del_jugador := Camera3D.new()
	escena.add_child(del_jugador)
	del_jugador.make_current()
	var calentamiento := _calentamiento()
	var poses: Dictionary[Transform3D, bool] = {}
	var termino := [false]
	calentamiento.terminado.connect(func() -> void: termino[0] = true)
	calentamiento.calentar(escena)
	for _cuadro: int in 600:
		if termino[0]:
			break
		var camara := get_viewport().get_camera_3d()
		if camara != del_jugador and camara.projection == Camera3D.PROJECTION_PERSPECTIVE:
			var planos := _planos_de(camara)
			if not _frustum_corta_esfera(planos, omni.global_position, omni.omni_range):
				for vereda: MeshInstance3D in veredas:
					var caja := _caja(vereda)
					if (
						vereda.visible
						and _frustum_corta_esfera(
							planos, caja.get_center(), caja.size.length() / 2.0
						)
					):
						poses[camara.global_transform] = true
		await get_tree().process_frame
	assert_bool(termino[0]).is_true()
	return poses.size()


func test_dos_objetos_con_el_mismo_programa_se_miran_una_sola_vez_sin_luces() -> void:
	var materiales: Array[Material] = [StandardMaterial3D.new(), StandardMaterial3D.new()]
	assert_int(await _poses_sin_la_luz(materiales)).is_equal(1)


func test_dos_objetos_con_otro_programa_se_miran_cada_uno_sin_luces() -> void:
	var transparente := StandardMaterial3D.new()
	transparente.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var materiales: Array[Material] = [StandardMaterial3D.new(), transparente]
	assert_int(await _poses_sin_la_luz(materiales)).is_equal(2)


func test_lo_que_se_mueve_no_se_dibuja_mas_alto_de_donde_lo_suelta_la_mano() -> void:
	var escena := _escena()
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE * 0.2
	var movible := _movible(escena, caja, Vector3(0, 0.1, 0))
	var alcance := (
		ReglasDelJugador.ALTURA_DE_LA_CAMARA
		+ ReglasDeLosObjetos.DISTANCIA_DE_SOLTADO * sin(ReglasDelJugador.PITCH_MAXIMO)
	)
	var omni := OmniLight3D.new()
	omni.omni_range = 1.0
	omni.position = Vector3(0, movible.global_position.y + alcance + omni.omni_range * 3.0, 0)
	escena.add_child(omni)
	var calentamiento := _calentamiento()
	var dibujadas := [0]
	var con_la_omni := [false]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for muestra: MeshInstance3D in _muestras_visibles(calentamiento, caja):
				dibujadas[0] += 1
				var cerca := omni.global_position.clamp(_caja(muestra).position, _caja(muestra).end)
				if cerca.distance_to(omni.global_position) < omni.omni_range:
					con_la_omni[0] = true
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_int(dibujadas[0]).is_greater(0)
	assert_bool(con_la_omni[0]).is_false()


func test_lo_largo_se_dibuja_tan_alto_como_lo_lleva_el_examen() -> void:
	var escena := _escena()
	var cuerpo := RigidBody3D.new()
	cuerpo.freeze = true
	escena.add_child(cuerpo)
	var palo := BoxMesh.new()
	palo.size = Vector3(0.05, 1.0, 0.05)
	var instancia := MeshInstance3D.new()
	instancia.mesh = palo
	instancia.position = Vector3.UP * palo.size.y / 2.0
	cuerpo.add_child(instancia)
	var mirando_arriba := (
		sin(ReglasDelJugador.PITCH_MAXIMO)
		+ ReglasDeLosObjetos.ELEVACION_DEL_EXAMEN * cos(ReglasDelJugador.PITCH_MAXIMO)
	)
	var en_la_mano := (
		ReglasDelJugador.ALTURA_DE_LA_CAMARA
		+ ReglasDeLosObjetos.distancia_de_examen(Examen._radio(cuerpo)) * mirando_arriba
		+ instancia.position.y
	)
	var omni := OmniLight3D.new()
	omni.omni_range = 0.3
	omni.position = Vector3.UP * (en_la_mano + palo.size.y / 2.0 + omni.omni_range * 0.5)
	escena.add_child(omni)
	var calentamiento := _calentamiento()
	var con_la_omni := [false]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for muestra: MeshInstance3D in _muestras_visibles(calentamiento, palo):
				var cerca := omni.global_position.clamp(_caja(muestra).position, _caja(muestra).end)
				if cerca.distance_to(omni.global_position) < omni.omni_range:
					con_la_omni[0] = true
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(con_la_omni[0]).is_true()


func test_lo_que_se_prepara_en_otra_carga_se_dibuja_en_su_lugar_pero_sin_copias() -> void:
	var escena: EscenaConPostergados = auto_free(EscenaConPostergados.new())
	add_child(escena)
	var omni := OmniLight3D.new()
	omni.omni_range = 1.5
	escena.add_child(omni)
	var postergada := BoxMesh.new()
	postergada.size = Vector3.ONE * 0.2
	var de_otra_carga := _movible(escena, postergada, Vector3(4, 0.1, 0))
	var preparada := BoxMesh.new()
	preparada.size = Vector3.ONE * 0.3
	_movible(escena, preparada, Vector3(-4, 0.1, 0))
	var calentamiento := _calentamiento()
	var en_su_lugar := [false]
	var copias := [0]
	var de_la_otra := [0]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			en_su_lugar[0] = en_su_lugar[0] or de_otra_carga.visible
			copias[0] += _muestras_visibles(calentamiento, postergada).size()
			de_la_otra[0] += _muestras_visibles(calentamiento, preparada).size()
	)
	escena.postergados.append(de_otra_carga.get_parent() as Node3D)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(en_su_lugar[0]).is_true()
	assert_int(copias[0]).is_zero()
	assert_int(de_la_otra[0]).is_greater(0)


## El cupo cuenta materiales que compilan. La clase de una malla no compila nada: contarla dejaba
## una sola copia de la mopa por cuadro, y la noche esperaba cuadros sin compilar.
func test_la_clase_de_una_malla_no_ocupa_lugar_en_el_cupo_de_materiales() -> void:
	var escena := _escena()
	for x: float in [-1.0, 1.0]:
		var omni := OmniLight3D.new()
		omni.position = Vector3(x, 1, 0)
		omni.omni_range = 1.5
		escena.add_child(omni)
	var malla := ArrayMesh.new()
	for _superficie: int in 2:
		malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().get_mesh_arrays())
	var movible := _movible(escena, malla, Vector3(0, 1, 6))
	for superficie: int in malla.get_surface_count():
		var pintura := ShaderMaterial.new()
		pintura.shader = Shader.new()
		pintura.shader.code = "shader_type spatial;"
		movible.set_surface_override_material(superficie, pintura)
	var contorno := ShaderMaterial.new()
	contorno.shader = CONTORNO
	movible.material_overlay = contorno
	var materiales := malla.get_surface_count() + 1
	assert_int(materiales).is_less(CalentamientoDeShaders.MATERIALES_NUEVOS_POR_CUADRO)
	var calentamiento := _calentamiento()
	var vistas: Dictionary[MeshInstance3D, bool] = {}
	var mayor := [0]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			var nuevas := 0
			for muestra: MeshInstance3D in _muestras_visibles(calentamiento, malla):
				if not vistas.has(muestra):
					vistas[muestra] = true
					nuevas += 1
			mayor[0] = maxi(mayor[0], nuevas)
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_int(vistas.size()).is_greater(1)
	assert_int(mayor[0]).is_greater(1)


## Entre noches la escena sigue en juego detrás de la persiana: el calentamiento de la transición
## sólo agrega las copias de lo pedido, y no oculta ni destapa nada de la escena.
func test_las_copias_de_la_transicion_no_tocan_la_escena_ni_otros_cuerpos() -> void:
	var escena := _escena()
	var omni := OmniLight3D.new()
	omni.omni_range = 1.5
	escena.add_child(omni)
	var sonda := ReflectionProbe.new()
	escena.add_child(sonda)
	var mueble := MeshInstance3D.new()
	mueble.mesh = BoxMesh.new()
	escena.add_child(mueble)
	var guardado := MeshInstance3D.new()
	guardado.mesh = BoxMesh.new()
	guardado.hide()
	escena.add_child(guardado)
	var pedida := BoxMesh.new()
	pedida.size = Vector3.ONE * 0.2
	var util := _movible(escena, pedida, Vector3(3, 0.1, 0))
	var ajena := BoxMesh.new()
	ajena.size = Vector3.ONE * 0.3
	_movible(escena, ajena, Vector3(-3, 0.1, 0))
	var del_jugador := Camera3D.new()
	escena.add_child(del_jugador)
	del_jugador.make_current()
	var calentamiento := _calentamiento()
	var tocada := [false]
	var copias := [0]
	var ajenas := [0]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			tocada[0] = (
				tocada[0]
				or not mueble.visible
				or guardado.visible
				or not util.visible
				or sonda.update_mode == ReflectionProbe.UPDATE_ALWAYS
			)
			copias[0] += _muestras_visibles(calentamiento, pedida).size()
			ajenas[0] += _muestras_visibles(calentamiento, ajena).size()
	)
	calentamiento.calentar_copias(escena, [util.get_parent() as Node3D])
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(tocada[0]).is_false()
	assert_int(copias[0]).is_greater(0)
	assert_int(ajenas[0]).is_zero()
	assert_object(get_viewport().get_camera_3d()).is_same(del_jugador)
	assert_bool(guardado.visible).is_false()


## La transición también prepara el contorno del foco sobre lo pedido: en la carga, la copia lo
## lleva porque se copia con el foco puesto.
func test_las_copias_de_la_transicion_llevan_el_contorno_del_foco() -> void:
	var escena := _escena()
	var pedida := BoxMesh.new()
	pedida.size = Vector3.ONE * 0.2
	var util := _movible(escena, pedida, Vector3(0, 0.1, 0))
	util.get_parent().add_to_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
	var calentamiento := _calentamiento()
	var con_contorno := [false]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for muestra: MeshInstance3D in _muestras_visibles(calentamiento, pedida):
				var encima := muestra.material_overlay as ShaderMaterial
				con_contorno[0] = con_contorno[0] or (encima != null and encima.shader == CONTORNO)
	)
	calentamiento.calentar_copias(escena, [util.get_parent() as Node3D])
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(con_contorno[0]).is_true()
	assert_object(util.material_overlay).is_null()


## Una caja ausente en la jornada que termina está oculta y fuera del grupo del foco. La siguiente
## la muestra, y su contorno tiene que estar listo igual.
func test_lo_pedido_oculto_y_fuera_del_foco_se_copia_con_el_contorno() -> void:
	var escena := _escena()
	var pedida := BoxMesh.new()
	pedida.size = Vector3.ONE * 0.2
	var util := _movible(escena, pedida, Vector3(0, 0.1, 0))
	var cuerpo := util.get_parent() as Node3D
	cuerpo.hide()
	var calentamiento := _calentamiento()
	var con_contorno := [false]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for muestra: MeshInstance3D in _muestras_visibles(calentamiento, pedida):
				var encima := muestra.material_overlay as ShaderMaterial
				con_contorno[0] = con_contorno[0] or (encima != null and encima.shader == CONTORNO)
	)
	calentamiento.calentar_copias(escena, [cuerpo])
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(con_contorno[0]).is_true()
	assert_object(util.material_overlay).is_null()
	assert_bool(cuerpo.visible).is_false()
