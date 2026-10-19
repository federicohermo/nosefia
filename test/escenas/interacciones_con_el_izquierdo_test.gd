## El primario conserva la mano y consume un único gesto, también ante un rechazo.
extends GdUnitTestSuite

var _controles_originales: Array[InputEvent] = []
var _reasignado := false


func after_test() -> void:
	if _reasignado:
		InputMap.action_erase_events(ReglasDeLosObjetos.ACCION_AGARRAR)
		for evento in _controles_originales:
			InputMap.action_add_event(ReglasDeLosObjetos.ACCION_AGARRAR, evento)
		_reasignado = false
		_controles_originales.clear()
	get_tree().paused = false


func _abrir() -> Node3D:
	var almacen: Node3D = auto_free(load("res://src/escenas/almacen.tscn").instantiate())
	almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	add_child(almacen)
	for cuadro in 3:
		await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func _accion(almacen: Node3D, objetivo: Node3D, primario: bool) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR if primario else ReglasDelJugador.ACCION_USAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _agarrar(almacen: Node3D, objeto: Node3D) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	if agarre.manos().sostenido() != null:
		agarre.soltar(false)
	assert_bool(agarre.pedir_agarrar(objeto.get("datos"), objeto)).is_true()


func _mancha(almacen: Node3D) -> Node3D:
	for mancha: Node3D in almacen.get("_limpieza").call("manchas"):
		if mancha.call("lugar_de_la_mancha") == PisoDelLocal.Lugar.ENTRADA:
			return mancha
	return null


func _un_uso(almacen: Node3D, objeto: Node3D, objetivo: Node3D) -> void:
	_agarrar(almacen, objeto)
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var pedidos: Array[Node3D] = []
	var soltados: Array[Node3D] = []
	var pedido := func(nodo: Node3D) -> void: pedidos.append(nodo)
	var soltado := func(nodo: Node3D) -> void: soltados.append(nodo)
	jugador.uso_pedido.connect(pedido)
	agarre.objeto_soltado.connect(soltado)
	_accion(almacen, objetivo, false)
	assert_array(pedidos).is_empty()
	assert_object(agarre.cuerpo_sostenido()).is_same(objeto)
	_accion(almacen, objetivo, true)
	assert_array(pedidos).contains_exactly([objetivo])
	assert_array(soltados).is_empty()
	assert_object(agarre.cuerpo_sostenido()).is_same(objeto)
	jugador.uso_pedido.disconnect(pedido)
	agarre.objeto_soltado.disconnect(soltado)


func test_los_seis_pares_ejecutan_un_uso_y_el_derecho_ninguno() -> void:  # AC-CLN-067 AC-PLY-097
	var almacen := await _abrir()
	var balde: Node3D = almacen.get_node("Objetos/Balde")
	var mopa: Node3D = almacen.get_node("Objetos/Mopa")
	var lavatorio: Node3D = almacen.get_node("Estructura/vanitory/StaticBody3D")
	var inodoro: Node3D = almacen.get_node("Estructura/inodoro/StaticBody3D")
	var limpiador: Limpiador = almacen.get("_limpiador")
	var efectos: Array[String] = []
	limpiador.balde_llenado.connect(func() -> void: efectos.append("llenar"))
	limpiador.balde_tenido.connect(
		func(_agua: ReglasDeLaLimpieza.Agua) -> void: efectos.append("teñir")
	)
	limpiador.mopa_mojada.connect(
		func(_agua: ReglasDeLaLimpieza.Agua) -> void: efectos.append("mojar")
	)
	limpiador.pasada_dada.connect(
		func(_lugar: PisoDelLocal.Lugar) -> void: efectos.append("limpiar")
	)
	limpiador.balde_vaciado.connect(func() -> void: efectos.append("vaciar"))
	_un_uso(almacen, balde, lavatorio)
	assert_int(limpiador.piso().balde().agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)
	_un_uso(almacen, almacen.get_node("Objetos/JabonAmarillo"), balde)
	_un_uso(almacen, mopa, balde)
	assert_int(limpiador.piso().mopa().agua()).is_equal(ReglasDeLaLimpieza.Agua.AMARILLO)
	var mancha := _mancha(almacen)
	assert_object(mancha).is_not_null()
	_un_uso(almacen, mopa, mancha)
	assert_bool(limpiador.piso().mancha_de(PisoDelLocal.Lugar.ENTRADA).esta_limpia()).is_true()
	_un_uso(almacen, mopa, inodoro)
	assert_int(limpiador.piso().mopa().agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)
	_un_uso(almacen, balde, inodoro)
	assert_bool(limpiador.piso().balde().tiene_agua()).is_false()
	assert_array(efectos).contains_exactly(
		["llenar", "teñir", "mojar", "limpiar", "mojar", "vaciar"]
	)


func test_rechazar_conserva_util_agua_y_carga() -> void:  # AC-CLN-068 AC-PLY-097
	var almacen := await _abrir()
	var limpiador: Limpiador = almacen.get("_limpiador")
	var balde: Node3D = almacen.get_node("Objetos/Balde")
	var mopa: Node3D = almacen.get_node("Objetos/Mopa")
	var amarillo: Node3D = almacen.get_node("Objetos/JabonAmarillo")
	var azul: Node3D = almacen.get_node("Objetos/JabonAzul")
	var inodoro: Node3D = almacen.get_node("Estructura/inodoro/StaticBody3D")
	var lavatorio: Node3D = almacen.get_node("Estructura/vanitory/StaticBody3D")
	var rechazos: Array[ReglasDeLaLimpieza.Resultado] = []
	limpiador.uso_rechazado.connect(
		func(motivo: ReglasDeLaLimpieza.Resultado) -> void: rechazos.append(motivo)
	)
	_un_uso(almacen, mopa, balde)
	_un_uso(almacen, balde, inodoro)
	_un_uso(almacen, amarillo, balde)
	_un_uso(almacen, mopa, _mancha(almacen))
	_un_uso(almacen, balde, lavatorio)
	_un_uso(almacen, mopa, balde)
	_un_uso(almacen, mopa, _mancha(almacen))
	_un_uso(almacen, balde, lavatorio)
	_un_uso(almacen, azul, balde)
	_un_uso(almacen, amarillo, balde)
	_un_uso(almacen, mopa, balde)
	var carga := limpiador.piso().mopa().carga_restante()
	_un_uso(almacen, mopa, _mancha(almacen))
	assert_float(limpiador.piso().mopa().carga_restante()).is_equal(carga)
	assert_int(limpiador.piso().balde().agua()).is_equal(ReglasDeLaLimpieza.Agua.AZUL)
	assert_bool(limpiador.piso().mancha_de(PisoDelLocal.Lugar.ENTRADA).esta_limpia()).is_false()
	assert_array(rechazos).contains_exactly(
		[
			ReglasDeLaLimpieza.Resultado.BALDE_VACIO,
			ReglasDeLaLimpieza.Resultado.BALDE_VACIO,
			ReglasDeLaLimpieza.Resultado.BALDE_VACIO,
			ReglasDeLaLimpieza.Resultado.MOPA_SECA,
			ReglasDeLaLimpieza.Resultado.SIN_JABON,
			ReglasDeLaLimpieza.Resultado.BALDE_YA_LLENO,
			ReglasDeLaLimpieza.Resultado.BALDE_YA_TENIDO,
			ReglasDeLaLimpieza.Resultado.JABON_EQUIVOCADO
		]
	)


func test_caja_separa_gestos_y_rechaza_repeticion() -> void:  # AC-STK-038 AC-PLY-097
	var almacen := await _abrir()
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ACTRONCITO]
	var repositor: Repositor = almacen.get("_repositor")
	var contenido := repositor.caja(Producto.Id.ACTRONCITO)
	var agarre: Agarre = almacen.get("_agarre")
	var antes := contenido.unidades()
	_accion(almacen, caja, false)
	var unidad := agarre.manos().sostenido()
	var cuerpo := agarre.cuerpo_sostenido()
	assert_object(unidad as UnidadDeProducto).is_not_null()
	assert_int(contenido.unidades()).is_equal(antes - 1)
	_accion(almacen, caja, false)
	assert_object(agarre.manos().sostenido()).is_same(unidad)
	assert_int(contenido.unidades()).is_equal(antes - 1)
	_accion(almacen, caja, true)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(contenido.unidades()).is_equal(antes)
	cuerpo.set("datos", unidad)
	assert_bool(agarre.pedir_agarrar(unidad, cuerpo)).is_true()
	_accion(almacen, caja, true)
	assert_object(agarre.manos().sostenido()).is_same(unidad)
	assert_int(contenido.unidades()).is_equal(antes)
	agarre.entregar()
	_accion(almacen, caja, true)
	assert_object(agarre.cuerpo_sostenido()).is_same(caja)
	assert_int(contenido.unidades()).is_equal(antes)


func test_reasignar_primario_cambia_el_gesto_y_el_corchete() -> void:  # AC-PLY-088
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	var balde: Node3D = almacen.get_node("Objetos/Balde")
	var lavatorio: Node3D = almacen.get_node("Estructura/vanitory/StaticBody3D")
	_agarrar(almacen, balde)
	_controles_originales.assign(InputMap.action_get_events(ReglasDeLosObjetos.ACCION_AGARRAR))
	_reasignado = true
	InputMap.action_erase_events(ReglasDeLosObjetos.ACCION_AGARRAR)
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_F
	InputMap.action_add_event(ReglasDeLosObjetos.ACCION_AGARRAR, tecla)
	jugador.set("_enfocado", lavatorio)
	jugador.call("_publicar_la_referencia")
	var label: Label = almacen.get("_hud").get_node("Controles")
	assert_str(label.text).is_equal("[E] Examinar (mano)\n[F] Llenar")
	tecla.pressed = true
	jugador.call("_unhandled_input", tecla)
	assert_bool((almacen.get("_limpiador") as Limpiador).piso().balde().tiene_agua()).is_true()
	assert_object((almacen.get("_agarre") as Agarre).cuerpo_sostenido()).is_same(balde)


func _clic_real(boton: MouseButton, posicion: Vector2) -> void:
	for presionado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = boton
		evento.pressed = presionado
		evento.position = posicion
		evento.global_position = posicion
		get_viewport().push_input(evento)
		await get_tree().process_frame


func test_salir_de_computadora_caja_y_nota_consume_el_clic() -> void:  # AC-PLY-098
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	almacen.get("_reposicion_manual").call("retirar", Producto.Id.ACTRONCITO)
	var unidad := agarre.manos().sostenido()
	var cuerpo := agarre.cuerpo_sostenido()
	var padre := cuerpo.get_parent()
	assert_object(unidad as UnidadDeProducto).is_not_null()
	var mundo: Array[String] = []
	jugador.uso_pedido.connect(func(_nodo: Node3D) -> void: mundo.append("uso"))
	agarre.objeto_agarrado.connect(func(_nodo: Node3D) -> void: mundo.append("agarre"))
	agarre.objeto_soltado.connect(func(_nodo: Node3D) -> void: mundo.append("soltado"))
	var computadora: Node3D = almacen.get_node("Estructura/base compu/StaticBody3D")
	var caja: Node3D = almacen.get_node("Estructura/cajaregistradora/StaticBody3D")
	var nota: Node3D = almacen.get_node("Estructura/NotasDelAlmacen").get("notas")[0]
	var centro := get_viewport().get_visible_rect().get_center()
	var fuera := get_viewport().get_visible_rect().position + Vector2.ONE
	var programa: ProgramaDeTickets = almacen.get_node("Interfaz/ProgramaDeTickets")
	var margenes := (programa.borrar.get_parent() as Control).get_global_rect()
	assert_bool(get_viewport().get_visible_rect().has_point(fuera)).is_true()
	assert_bool(margenes.has_point(fuera)).is_false()
	# Sólo el derecho sale; el izquierdo, en la nota o por fuera del panel de tickets, no.
	for caso: Array in [
		[computadora, MOUSE_BUTTON_RIGHT, centro],
		[caja, MOUSE_BUTTON_RIGHT, centro],
		[nota, MOUSE_BUTTON_RIGHT, centro],
		[nota, MOUSE_BUTTON_LEFT, centro],
		[caja, MOUSE_BUTTON_LEFT, fuera]
	]:
		_accion(almacen, caso[0], true)
		assert_bool(jugador.call("suspendido")).is_true()
		await get_tree().process_frame
		await _clic_real(caso[1], caso[2])
		if caso[1] == MOUSE_BUTTON_LEFT:
			assert_bool(jugador.call("suspendido")).override_failure_message(str(caso)).is_true()
			await _clic_real(MOUSE_BUTTON_RIGHT, centro)
		assert_bool(jugador.call("suspendido")).override_failure_message(str(caso)).is_false()
		assert_object(agarre.manos().sostenido()).is_same(unidad)
		assert_object(agarre.cuerpo_sostenido()).is_same(cuerpo)
		assert_object(cuerpo.get_parent()).is_same(padre)
		assert_array(mundo).is_empty()


func _bloqueado(almacen: Node3D, objetivo: Node3D, unidad: ObjetoDelAlmacen) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var caja: CajaRegistradora = almacen.get("_caja")
	for primario: bool in [true, false]:
		_accion(almacen, objetivo, primario)
		jugador.call("_publicar_la_referencia")
		assert_object(agarre.manos().sostenido()).is_same(unidad)
		assert_array(caja.generador().renglones()).is_empty()
		assert_str((almacen.get("_hud").get_node("Controles") as Label).text).is_empty()


func test_examen_celular_pausa_y_cierre_bloquean_ambos_gestos() -> void:  # AC-PLY-098
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	almacen.get("_reposicion_manual").call("retirar", Producto.Id.ACTRONCITO)
	var unidad := agarre.manos().sostenido()
	assert_object(unidad as UnidadDeProducto).is_not_null()
	var lector: Node3D = almacen.get_node("Estructura/Lector")
	var pedidos: Array[Node3D] = []
	jugador.uso_pedido.connect(func(nodo: Node3D) -> void: pedidos.append(nodo))
	var examen: Examen = jugador.get("examen")
	assert_bool(examen.iniciar(unidad, "Unidad")).is_true()
	_bloqueado(almacen, lector, unidad)
	examen.terminar()
	almacen.call("_al_abrir_el_celular")
	_bloqueado(almacen, lector, unidad)
	almacen.call("_al_cerrar_el_celular")
	jugador.call("declarar_la_pausa", true)
	get_tree().paused = true
	_bloqueado(almacen, lector, unidad)
	get_tree().paused = false
	jugador.call("declarar_la_pausa", false)
	almacen.get("_reloj").avanzar(Reglas.DURACION_DEL_TURNO)
	_bloqueado(almacen, lector, unidad)
	assert_array(pedidos).is_empty()
