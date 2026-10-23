## Donde el motor unifica variantes (la web y el motor de escritorio que las unifica), la omni y
## el foco sin sombra y las sondas compilan el mismo programa: las copias no se multiplican por
## ellos. Lo que sigue cambiando el programa (sombras, área y GI) conserva su copia.
extends GdUnitTestSuite

const ESPERA_MS := 5000
const CONTORNO := preload("res://src/sistemas/marco/contorno.gdshader")


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
	add_child(calentamiento)
	return calentamiento


func _caja(objeto: GeometryInstance3D) -> AABB:
	var caja := objeto.custom_aabb
	if caja == AABB():
		caja = objeto.get_aabb()
	return objeto.global_transform * caja


func _muestras_visibles(
	calentamiento: CalentamientoDeShaders, malla: Mesh
) -> Array[MeshInstance3D]:
	var visibles: Array[MeshInstance3D] = []
	for muestra: MeshInstance3D in calentamiento.find_children("*", "MeshInstance3D", true, false):
		if muestra.visible and muestra.mesh == malla:
			visibles.append(muestra)
	return visibles


func _con_variantes_unificadas(calentamiento: CalentamientoDeShaders, unifica: bool) -> void:
	calentamiento.unifica_variantes = func() -> bool: return unifica


func _omni(escena: Node3D, lugar: Vector3, alcance: float, con_sombra: bool) -> OmniLight3D:
	var omni := OmniLight3D.new()
	omni.position = lugar
	omni.omni_range = alcance
	omni.shadow_enabled = con_sombra
	escena.add_child(omni)
	return omni


func _copias_de(escena: Node3D, malla: Mesh, unifica: bool) -> Array[AABB]:
	var calentamiento := _calentamiento()
	_con_variantes_unificadas(calentamiento, unifica)
	var cajas: Dictionary[MeshInstance3D, AABB] = {}
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for muestra: MeshInstance3D in _muestras_visibles(calentamiento, malla):
				cajas[muestra] = _caja(muestra)
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	return cajas.values()


## Con las variantes unificadas, la omni sin sombra no cambia el programa: dos que se cruzan ya no
## multiplican las copias. Sin unificar, siguen siendo las cuatro combinaciones.
func test_con_variantes_unificadas_las_omni_sin_sombra_no_multiplican_copias() -> void:
	var escena := _escena()
	for x: float in [-1.0, 1.0]:
		_omni(escena, Vector3(x, 1, 0), 1.5, false)
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE * 0.1
	_movible(escena, caja, Vector3(0, 1, 6))
	var sin_unificar: Array[AABB] = await _copias_de(escena, caja, false)
	var unificadas: Array[AABB] = await _copias_de(escena, caja, true)
	assert_int(sin_unificar.size()).is_greater(1)
	assert_int(unificadas.size()).is_equal(1)


## La omni con sombra va en su propia pasada: aun unificadas, hay copia con ella y sin ella.
func test_con_variantes_unificadas_la_omni_con_sombra_sigue_separando() -> void:
	var escena := _escena()
	var omni := _omni(escena, Vector3(0, 1, 0), 1.5, true)
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE * 0.1
	_movible(escena, caja, Vector3(0, 1, 6))
	var alcanzadas: Dictionary[bool, bool] = {}
	for copia: AABB in await _copias_de(escena, caja, true):
		var cerca := omni.global_position.clamp(copia.position, copia.end)
		alcanzadas[cerca.distance_to(omni.global_position) < omni.omni_range] = true
	assert_array(alcanzadas.keys()).contains_exactly_in_any_order([true, false])


## Achicar el recorrido a las luces que cuentan no puede perder el borde de la GI: una luz con
## sombra que cubre sólo un rincón del volumen deja igual una copia adentro y otra afuera.
func test_con_variantes_unificadas_se_conserva_adentro_y_afuera_de_la_gi() -> void:
	var escena := _escena()
	var local := MeshInstance3D.new()
	local.mesh = BoxMesh.new()
	local.mesh.size = Vector3(12, 3, 12)
	local.position = Vector3(0, 1.5, 0)
	local.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	escena.add_child(local)
	_omni(escena, Vector3(5, 1, 5), 0.5, true)
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE * 0.2
	_movible(escena, caja, Vector3(0, 0.1, 0))
	var volumen := local.global_transform * local.get_aabb()
	var lados: Dictionary[bool, bool] = {}
	for copia: AABB in await _copias_de(escena, caja, true):
		lados[volumen.has_point(copia.get_center())] = true
	assert_array(lados.keys()).contains_exactly_in_any_order([true, false])


func _mas_copias_por_cuadro(escena: Node3D, malla: Mesh, unifica: bool) -> int:
	var calentamiento := _calentamiento()
	_con_variantes_unificadas(calentamiento, unifica)
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
	return mayor[0]


## El contorno no tiene luz: con las variantes unificadas compila una vez por clase de objeto, y
## deja de ocupar el cupo en cada combinación.
func test_con_variantes_unificadas_el_contorno_ocupa_el_cupo_una_sola_vez() -> void:
	var escena := _escena()
	for x: float in [-1.0, 1.0]:
		_omni(escena, Vector3(x, 1, 0), 1.5, true)
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE * 0.1
	var movible := _movible(escena, caja, Vector3(0, 1, 6))
	var pintura := ShaderMaterial.new()
	pintura.shader = Shader.new()
	pintura.shader.code = "shader_type spatial;"
	movible.set_surface_override_material(0, pintura)
	var contorno := ShaderMaterial.new()
	contorno.shader = CONTORNO
	movible.material_overlay = contorno
	var sin_unificar := await _mas_copias_por_cuadro(escena, caja, false)
	var unificadas := await _mas_copias_por_cuadro(escena, caja, true)
	assert_int(unificadas).is_greater(sin_unificar)


func test_las_variantes_se_unifican_en_la_web_y_en_el_motor_que_las_unifica() -> void:
	var otro := "%s_otro" % CalentamientoDeShaders.BUILD_CON_VARIANTES_UNIFICADAS
	assert_bool(CalentamientoDeShaders.unifica_variantes_en(true, otro)).is_true()
	(
		assert_bool(
			CalentamientoDeShaders.unifica_variantes_en(
				false, CalentamientoDeShaders.BUILD_CON_VARIANTES_UNIFICADAS
			)
		)
		. is_true()
	)
	assert_bool(CalentamientoDeShaders.unifica_variantes_en(false, otro)).is_false()
	assert_bool(CalentamientoDeShaders.unifica_variantes_en(false, "")).is_false()
