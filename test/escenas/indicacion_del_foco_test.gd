extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Jugador := preload("res://src/escenas/jugador.gd")


class JugadorDoble:
	extends Jugador


func test_el_campo_real_resalta_la_computadora_y_solo_la_zona_de_reposicion() -> void:  # 039-AC9
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var hud: Hud = almacen.get("_hud")
	var computadora: Node3D = almacen.get_node("Estructura/compu/StaticBody3D")
	var estante: Node3D = almacen.get("_reposicion_manual").get_node("ZonaDeYerba")
	var mallas := almacen.find_children("*", "MeshInstance3D", true, false)
	var previos: Dictionary[MeshInstance3D, Material] = {}
	var geometria: Dictionary[MeshInstance3D, Mesh] = {}
	var materiales: Dictionary[MeshInstance3D, Material] = {}
	for malla: MeshInstance3D in mallas:
		previos[malla] = malla.material_overlay
		geometria[malla] = malla.mesh
		materiales[malla] = malla.material_override
	var avisos: Array[Node3D] = []
	var perdidos: Array[bool] = []
	jugador.objetivo_enfocado.connect(
		func(objetivo: Node3D, _distancia: float) -> void: avisos.append(objetivo)
	)
	jugador.objetivo_perdido.connect(func() -> void: perdidos.append(true))
	for objetivo in [computadora, estante]:
		var ojo := computadora.global_position + Vector3(0, 1, 1)
		var punto := computadora.global_position
		if objetivo == estante:
			almacen.get("_cajas_de_productos")[0].call("interactuar")
			punto = estante.global_position
			ojo = punto + Vector3(0, 0, 1.5)
		await _mirar(jugador, ojo, punto)
		assert_object(jugador.get("_enfocado")).is_same(objetivo)
		assert_array(avisos).contains([objetivo])
		assert_bool(hud.foco_presente).is_true()
		assert_bool(hud.get_node("Mira").color == IndicacionDelFoco.COLOR).is_true()
		var vinculadas: Array = objetivo.get("mallas")
		assert_array(vinculadas).is_not_empty()
		if objetivo == estante:
			assert_object(vinculadas[0].material_overlay).is_same(estante.material_de_foco)
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


func test_las_senales_del_doble_llegan_al_marco_y_al_hud() -> void:  # 039-AC9
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	var jugador: JugadorDoble = auto_free(JugadorDoble.new())
	almacen.get("_jugador").set_physics_process(false)
	almacen.set("_jugador", jugador)
	add_child(almacen)
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
	jugador.get_node("Camara").look_at(punto)
	for cuadro in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
