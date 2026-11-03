extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Jugador := preload("res://src/escenas/jugador.gd")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")


class JugadorDoble:
	extends Jugador


func test_el_campo_real_resalta_la_computadora() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var hud: Hud = almacen.get("_hud")
	var computadora: Node3D = almacen.get_node("Estructura/base compu/StaticBody3D")
	# Fibras y asa preparan sus mallas de forma diferida, antes de probar el foco.
	await get_tree().process_frame
	var mallas := almacen.find_children("*", "MeshInstance3D", true, false)
	var previos := _overlays(mallas)
	var geometria: Dictionary[MeshInstance3D, Mesh] = {}
	var materiales := _overrides(mallas)
	for malla: MeshInstance3D in mallas:
		geometria[malla] = malla.mesh
	var avisos := _avisos(jugador)
	var perdidos: Array[bool] = []
	jugador.objetivo_perdido.connect(func() -> void: perdidos.append(true))
	var ojo := computadora.global_position + Vector3(0, 1, 1)
	await _mirar(jugador, ojo, computadora.global_position)
	assert_object(jugador.get("_enfocado")).is_same(computadora)
	assert_array(avisos).contains([computadora])
	assert_bool(hud.foco_presente).is_true()
	assert_bool(hud.get_node("Mira").color == IndicacionDelFoco.COLOR).is_true()
	var vinculadas: Array = computadora.get("mallas")
	assert_array(vinculadas).is_not_empty()
	for malla: MeshInstance3D in mallas:
		if vinculadas.has(malla):
			assert_object(malla.material_overlay).is_not_null()
		else:
			assert_bool(malla.material_overlay == previos[malla]).is_true()
		assert_object(malla.mesh).is_same(geometria[malla])
		assert_bool(malla.material_override == materiales[malla]).is_true()
	await _mirar(jugador, Vector3(0, 10, 0), Vector3(0, 10, -1))
	assert_object(jugador.get("_enfocado")).is_null()
	assert_array(perdidos).is_not_empty()
	assert_bool(hud.foco_presente).is_false()
	for malla: MeshInstance3D in mallas:
		assert_bool(malla.material_overlay == previos[malla]).is_true()


## La vista previa aparece sólo en el hueco enfocado, sin ocultar ni reordenar sus referencias.
func test_la_vista_previa_aparece_solo_en_el_hueco_enfocado() -> void:  # AC-PLY-047
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var hud: Hud = almacen.get("_hud")
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var faltantes: Dictionary[Producto.Id, int] = {actroncito.id: 2}
	AperturaConLugar.abrir_con_faltantes(almacen, faltantes)
	puesto.call("retirar", actroncito.id)
	var estante: Estante = almacen.get("_repositor").estante()
	var vacios := estante.casilleros_vacios(actroncito)
	assert_int(vacios.size()).is_equal(2)
	var huecos: MultiMeshInstance3D = puesto.get_node("HuecosDe" + actroncito.nombre)
	var referencias := huecos.multimesh.buffer
	assert_int(huecos.multimesh.visible_instance_count).is_equal(vacios.size())
	var uno: Node3D = puesto.call("casillero", actroncito.id, vacios[0])
	var otro: Node3D = puesto.call("casillero", actroncito.id, vacios[1])
	var mallas := almacen.find_children("*", "MeshInstance3D", true, false)
	var previos := _overlays(mallas)
	var materiales := _overrides(mallas)
	var dibujadas := _dibujadas(mallas)
	var avisos := _avisos(jugador)
	for apuntado: Node3D in [uno, otro]:
		var previa: MeshInstance3D = apuntado.get("previsualizacion")
		assert_bool(dibujadas[previa]).is_false()
		await _mirar(jugador, _ojo_frente_a(puesto, apuntado), apuntado.global_position)
		assert_object(jugador.get("_enfocado")).is_same(apuntado)
		assert_array(avisos).contains([apuntado])
		assert_bool(hud.foco_presente).is_true()
		assert_bool(previa.visible).is_true()
		assert_bool(huecos.multimesh.buffer == referencias).is_true()
		assert_int(huecos.multimesh.visible_instance_count).is_equal(vacios.size())
		for malla: MeshInstance3D in mallas:
			assert_bool(malla.material_overlay == previos[malla]).is_true()
			assert_bool(malla.material_override == materiales[malla]).is_true()
			if malla != previa:
				assert_bool(malla.visible).is_equal(dibujadas[malla])
	await _mirar(jugador, Vector3(0, 10, 0), Vector3(0, 10, -1))
	assert_object(jugador.get("_enfocado")).is_null()
	assert_bool(huecos.multimesh.buffer == referencias).is_true()
	assert_int(huecos.multimesh.visible_instance_count).is_equal(vacios.size())
	for malla: MeshInstance3D in mallas:
		assert_bool(malla.visible).is_equal(dibujadas[malla])


## Desde dónde se apunta a un casillero: del lado del pasillo de su tanda, que lo mide el modelo.
func _ojo_frente_a(puesto: Node3D, casillero: Node3D) -> Vector3:
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var id: Producto.Id = casillero.get("producto")
	var frente := DisposicionDeLaGondola.frente(
		disposicion.principales[id], disposicion.filas_de_adelante[id]
	)
	return casillero.global_position + frente * 1.2 + Vector3.UP * 0.3


func _dibujadas(mallas: Array[Node]) -> Dictionary[MeshInstance3D, bool]:
	var dibujadas: Dictionary[MeshInstance3D, bool] = {}
	for malla: MeshInstance3D in mallas:
		dibujadas[malla] = malla.visible
	return dibujadas


func _overlays(mallas: Array[Node]) -> Dictionary[MeshInstance3D, Material]:
	var previos: Dictionary[MeshInstance3D, Material] = {}
	for malla: MeshInstance3D in mallas:
		previos[malla] = malla.material_overlay
	return previos


func _overrides(mallas: Array[Node]) -> Dictionary[MeshInstance3D, Material]:
	var materiales: Dictionary[MeshInstance3D, Material] = {}
	for malla: MeshInstance3D in mallas:
		materiales[malla] = malla.material_override
	return materiales


func _avisos(jugador: CharacterBody3D) -> Array[Node3D]:
	var avisos: Array[Node3D] = []
	jugador.objetivo_enfocado.connect(
		func(objetivo: Node3D, _distancia: float) -> void: avisos.append(objetivo)
	)
	return avisos


func test_las_senales_del_doble_llegan_al_marco_y_al_hud() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	# El cableado lee transforms globales: el doble necesita la escena real montada.
	var jugador: Jugador = almacen.get("_jugador")
	var agarre := jugador.agarre
	var examen := jugador.examen
	jugador.set_script(JugadorDoble)
	jugador.agarre = agarre
	jugador.examen = examen
	jugador.set_physics_process(false)
	add_child(almacen)
	assert_object(jugador.get_script()).is_same(JugadorDoble)
	assert_bool(jugador.is_inside_tree()).is_true()
	var hud: Hud = almacen.get("_hud")
	var objetivo: Node3D = almacen.get("_estante")
	var malla: MeshInstance3D = objetivo.get("mallas")[0]
	jugador.objetivo_enfocado.emit(objetivo, 1.0)
	assert_bool(hud.foco_presente).is_true()
	assert_object(malla.material_overlay).is_not_null()
	jugador.objetivo_perdido.emit()
	assert_bool(hud.foco_presente).is_false()
	assert_object(malla.material_overlay).is_null()


func _mirar(jugador: CharacterBody3D, ojo: Vector3, punto: Vector3) -> void:
	jugador.global_position = ojo - Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	jugador.get_node("Giro/Camara").look_at(punto)
	for cuadro in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
