extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Jugador := preload("res://src/escenas/jugador.gd")


class JugadorDoble:
	extends Jugador


func test_el_campo_real_resalta_la_computadora() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var hud: Hud = almacen.get("_hud")
	var computadora: Node3D = almacen.get_node("Estructura/base compu/StaticBody3D")
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


## El casillero que la mira enfoca titila en color y con emisión, y ninguna otra malla cambia: la
## marca del foco no lo pinta, porque el casillero se pinta solo. Cuando la mira se va, vuelve a
## quedar quieto y en blanco y negro.
func test_el_casillero_apuntado_titila_y_nada_mas_cambia() -> void:  # AC-PLY-047
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var hud: Hud = almacen.get("_hud")
	var puesto: Node3D = almacen.get("_reposicion_manual")
	puesto.call("retirar", Producto.Id.ACTRONCITO)
	var casillero: Node3D = puesto.call("casillero", Producto.Id.ACTRONCITO)
	var vista: MeshInstance3D = casillero.get("vista")
	var mallas := almacen.find_children("*", "MeshInstance3D", true, false)
	var previos := _overlays(mallas)
	var materiales := _overrides(mallas)
	var avisos := _avisos(jugador)
	# Del lado del pasillo de su tanda, que lo mide el modelo.
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var frente := DisposicionDeLaGondola.frente(
		disposicion.principales[Producto.Id.ACTRONCITO],
		disposicion.filas_de_adelante[Producto.Id.ACTRONCITO]
	)
	var punto := casillero.global_position
	await _mirar(jugador, punto + frente * 1.2 + Vector3.UP * 0.3, punto)
	assert_object(jugador.get("_enfocado")).is_same(casillero)
	assert_array(avisos).contains([casillero])
	assert_bool(hud.foco_presente).is_true()
	assert_array(casillero.get("mallas")).is_empty()
	assert_bool(vista.visible).is_true()
	assert_object(vista.material_override).is_same(casillero.get("material_apuntado"))
	var apuntado: ShaderMaterial = vista.material_override
	assert_float(apuntado.get_shader_parameter("saturacion")).is_equal(1.0)
	assert_float(apuntado.get_shader_parameter("opacidad_minima")).is_equal(
		ReglasDelEstante.OPACIDAD_DEL_CASILLERO
	)
	assert_float(apuntado.get_shader_parameter("opacidad_maxima")).is_equal(
		ReglasDelEstante.OPACIDAD_DEL_APUNTADO
	)
	assert_float(apuntado.get_shader_parameter("emision")).is_equal(
		ReglasDelEstante.EMISION_DEL_CASILLERO
	)
	assert_float(apuntado.get_shader_parameter("periodo")).is_equal(
		ReglasDelEstante.PERIODO_DEL_TITILEO
	)
	for malla: MeshInstance3D in mallas:
		assert_bool(malla.material_overlay == previos[malla]).is_true()
		if malla != vista:
			assert_bool(malla.material_override == materiales[malla]).is_true()
	await _mirar(jugador, Vector3(0, 10, 0), Vector3(0, 10, -1))
	assert_object(jugador.get("_enfocado")).is_null()
	assert_object(vista.material_override).is_same(casillero.get("material_quieto"))


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
	var jugador: JugadorDoble = auto_free(JugadorDoble.new())
	almacen.get("_jugador").set_physics_process(false)
	# Abrir la jornada termina el examen del jugador: el doble usa el de la escena.
	jugador.examen = almacen.get("_jugador").examen
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
	jugador.get_node("Giro/Camara").look_at(punto)
	for cuadro in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
