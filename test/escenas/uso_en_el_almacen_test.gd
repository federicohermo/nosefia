extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const JUGADOR := preload("res://src/escenas/jugador.tscn")


func test_la_accion_tiene_nombre_unico_y_clic_derecho() -> void:
	var reglas := load("res://src/dominio/jugador/reglas_del_jugador.gd") as Script
	assert_str(reglas.get_script_constant_map().get("ACCION_USAR", "")).is_equal("usar")
	assert_bool(InputMap.has_action("usar")).is_true()
	if InputMap.has_action("usar"):
		var derecho := false
		for evento in InputMap.action_get_events("usar"):
			if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_RIGHT:
				derecho = true
		assert_bool(derecho).is_true()
	for ruta in _scripts("res://src"):
		var texto := FileAccess.get_file_as_string(ruta)
		assert_bool(texto.contains("MOUSE_BUTTON_RIGHT")).override_failure_message(ruta).is_false()
		if not ruta.ends_with("reglas_del_jugador.gd"):
			assert_bool(texto.contains('"usar"')).override_failure_message(ruta).is_false()
	var jugador := FileAccess.get_file_as_string("res://src/escenas/jugador.gd")
	assert_array(RegEx.create_from_string("\\b(Uso|Efecto)\\b").search_all(jugador)).is_empty()


func test_el_jugador_declara_un_solo_pedido_tipado() -> void:
	var texto := FileAccess.get_file_as_string("res://src/escenas/jugador.gd")
	assert_bool(texto.contains("signal uso_pedido(objetivo: Node3D)")).is_true()
	assert_int(texto.count("uso_pedido.emit(")).is_equal(1)


func test_sin_foco_o_suspendido_no_emite_y_al_reanudar_si() -> void:
	var jugador: Node3D = auto_free(JUGADOR.instantiate())
	var objetivo: Node3D = auto_free(Node3D.new())
	var avisos: Array[Node3D] = []
	assert_bool(jugador.has_signal("uso_pedido")).is_true()
	if not jugador.has_signal("uso_pedido"):
		return
	jugador.connect("uso_pedido", func(nodo: Node3D) -> void: avisos.append(nodo))
	var evento := InputEventAction.new()
	evento.action = &"usar"
	evento.pressed = true
	jugador.call("_unhandled_input", evento)
	assert_array(avisos).is_empty()
	jugador.set("_enfocado", objetivo)
	jugador.call("suspender")
	jugador.call("_unhandled_input", evento)
	assert_array(avisos).is_empty()
	jugador.call("reanudar")
	jugador.call("_unhandled_input", evento)
	assert_array(avisos).contains_exactly([objetivo])


func test_el_clic_derecho_limpia_una_mancha_de_punta_a_punta() -> void:  # AC-CLN-023
	# El camino entero, con el clic de verdad: la mano vacía y la mopa seca no borran; el balde se
	# llena en el lavatorio, el jabón lo tiñe, la mopa se moja, y recién ahí la mancha se va.
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var mancha := _mancha_de(almacen, PisoDelLocal.Lugar.ENTRADA)
	var piso: PisoDelLocal = (almacen.get("_limpiador") as Limpiador).piso()
	var estado := piso.mancha_de(PisoDelLocal.Lugar.ENTRADA)
	await _enfocar(jugador, mancha)
	await _clic(true)
	await _clic(false)
	assert_bool(estado.esta_limpia()).is_false()
	var mopa: Node3D = almacen.get_node("Objetos/Mopa")
	assert_bool(agarre.pedir_agarrar(mopa.call("interactuar"), mopa)).is_true()
	await _enfocar(jugador, mancha)
	await _clic(true)
	await _clic(false)
	assert_bool(estado.esta_limpia()).is_false()
	agarre.soltar(true)
	mopa.global_transform = mopa.call(ReglasDeLosObjetos.METODO_LUGAR_DE_ORIGEN)
	var balde: Node3D = almacen.get_node("Objetos/Balde")
	await _usar_con(jugador, agarre, balde, almacen.get_node("Estructura/vanitory/StaticBody3D"))
	await _usar_con(jugador, agarre, almacen.get_node("Objetos/JabonAmarillo"), balde)
	assert_bool(agarre.pedir_agarrar(mopa.call("interactuar"), mopa)).is_true()
	jugador.set("_enfocado", balde)
	await _clic(true)
	await _clic(false)
	assert_int(piso.mopa().agua()).is_equal(ReglasDeLaLimpieza.Agua.AMARILLO)
	await _enfocar(jugador, mancha)
	await _clic(true)
	assert_bool(estado.esta_limpia()).is_true()
	assert_bool(mancha.visible).is_false()
	await _clic(false)


func test_usar_cierra_cada_panel_sin_pasada_ni_pedido_y_el_reloj_avanza() -> void:
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	var limpiador: Limpiador = almacen.get("_limpiador")
	limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	limpiador.usar(&"jabon_amarillo", ReglasDeLaLimpieza.ID_DEL_BALDE)
	limpiador.usar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, ReglasDeLaLimpieza.ID_DEL_BALDE)
	var mancha := _mancha_de(almacen, PisoDelLocal.Lugar.ENTRADA)
	await _enfocar(jugador, mancha)
	var agarre: Agarre = almacen.get("_agarre")
	var mopa: Node3D = almacen.get_node("Objetos/Mopa")
	assert_bool(agarre.pedir_agarrar(mopa.call("interactuar"), mopa)).is_true()
	var avisos: Array[Node3D] = []
	if jugador.has_signal("uso_pedido"):
		jugador.connect("uso_pedido", func(nodo: Node3D) -> void: avisos.append(nodo))
	var estado := limpiador.piso().mancha_de(PisoDelLocal.Lugar.ENTRADA)
	for ruta: String in ["Estructura/base compu/StaticBody3D", "Estructura/Ventanilla"]:
		var puesto: Node3D = almacen.get_node(ruta)
		var panel: CanvasLayer = puesto.get("pantalla") if "compu" in ruta else puesto.get("panel")
		puesto.call("abrir")
		assert_bool(panel.visible).is_true()
		assert_bool(jugador.get("_control").esta_suspendido()).is_true()
		var reloj: RelojDelTurno = almacen.get("_reloj")
		var tiempos: Array[float] = []
		var anotar := func(restante: float) -> void: tiempos.append(restante)
		reloj.tiempo_consumido.connect(anotar)
		for cuadro in 4:
			await get_tree().process_frame
		reloj.tiempo_consumido.disconnect(anotar)
		assert_int(tiempos.size()).is_greater_equal(2)
		if tiempos.size() >= 2:
			assert_float(tiempos.back()).is_less(tiempos.front())
		await _clic(true)
		await _clic(false)
		assert_bool(jugador.get("_control").esta_suspendido()).is_false()
		assert_bool(panel.visible).is_false()
		assert_array(avisos).is_empty()
		assert_bool(estado.esta_limpia()).is_false()
	await _enfocar(jugador, mancha)
	await _clic(true)
	await _clic(false)
	assert_int(avisos.size()).is_equal(1)
	assert_bool(estado.esta_limpia()).is_true()


## Agarra el útil, lo usa con el clic derecho sobre el objetivo y lo devuelve a su lugar del baño:
## soltado adelante, taparía la mancha que el caso enfoca después. Lo que se tiene adelante lo
## pone el caso: la mira del jugador está apagada.
func _usar_con(jugador: Node3D, agarre: Agarre, util: Node3D, objetivo: Node3D) -> void:
	assert_bool(agarre.pedir_agarrar(util.call("interactuar"), util)).is_true()
	jugador.set("_enfocado", objetivo)
	await _clic(true)
	await _clic(false)
	agarre.soltar(true)
	util.global_transform = util.call(ReglasDeLosObjetos.METODO_LUGAR_DE_ORIGEN)


func _mancha_de(almacen: Node3D, lugar: PisoDelLocal.Lugar) -> Node3D:
	for mancha: Node3D in almacen.get("_limpieza").call("manchas"):
		if mancha.call("lugar_de_la_mancha") == lugar:
			return mancha
	return null


func _abrir() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	for cuadro in 4:
		await get_tree().physics_frame
	return almacen


func _enfocar(jugador: Node3D, mancha: Node3D) -> void:
	jugador.set_physics_process(false)
	jugador.global_position = mancha.global_position + Vector3.BACK
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.look_at(mancha.global_position + Vector3.UP * 0.03)
	for cuadro in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
	assert_object(jugador.get("_enfocado")).is_same(mancha)


func _clic(presionado: bool) -> void:
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_RIGHT
	evento.pressed = presionado
	evento.position = get_viewport().get_visible_rect().get_center()
	get_viewport().push_input(evento)
	await get_tree().process_frame


func _scripts(carpeta: String) -> Array[String]:
	var encontrados: Array[String] = []
	for archivo in DirAccess.get_files_at(carpeta):
		if archivo.ends_with(".gd"):
			encontrados.append(carpeta.path_join(archivo))
	for subcarpeta in DirAccess.get_directories_at(carpeta):
		encontrados.append_array(_scripts(carpeta.path_join(subcarpeta)))
	return encontrados
