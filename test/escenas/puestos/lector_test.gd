extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const UNIDAD := preload("res://src/escenas/objetos/objeto_agarrable.tscn")
const PAPEL := preload("res://src/escenas/objetos/ticket.tscn")

var _almacenes: Array[Node3D] = []


func after_test() -> void:
	get_tree().paused = false
	for almacen: Node3D in _almacenes:
		var reproductor: ReproductorDeSonidos = almacen.get_node(
			"Servicios/AudioDelAlmacen/Reproductor"
		)
		reproductor.silenciar()
		almacen.queue_free()
	_almacenes.clear()
	for _cuadro in 4:
		await get_tree().process_frame


func _abrir() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	_almacenes.append(almacen)
	add_child(almacen)
	almacen.get_node("Jugador").set_physics_process(false)
	for _cuadro in 4:
		await get_tree().physics_frame
	return almacen


func _accion(jugador: Node3D, objetivo: Node3D, accion: StringName) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _derecho() -> void:
	for presionado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_RIGHT
		evento.pressed = presionado
		evento.position = get_viewport().get_visible_rect().get_center()
		get_viewport().push_input(evento)
		await get_tree().process_frame


func _unidad(almacen: Node3D) -> ObjetoAgarrable:
	var unidad: ObjetoAgarrable = UNIDAD.instantiate()
	unidad.datos = UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI))
	almacen.add_child(unidad)
	return unidad


func _vista(almacen: Node3D) -> ProgramaDeTickets:
	return almacen.get_node("Interfaz/ProgramaDeTickets")


func _caja(almacen: Node3D) -> CajaRegistradora:
	return almacen.get_node("Servicios/CajaRegistradora")


func _puesto(almacen: Node3D) -> StaticBody3D:
	return almacen.get_node("Estructura/cajaregistradora/StaticBody3D")


func _papeles(almacen: Node3D) -> Array[ObjetoAgarrable]:
	var papeles: Array[ObjetoAgarrable] = []
	for nodo: Node in almacen.find_children("*", "RigidBody3D", true, false):
		var objeto := nodo as ObjetoAgarrable
		if objeto != null and objeto.datos is Ticket:
			papeles.append(objeto)
	return papeles


func _emitir_papel(almacen: Node3D) -> void:
	_caja(almacen).ticket_impreso.emit(Ticket.new([Catalogo.de(Producto.Id.MAROLINI)]))


class CajaContadora:
	extends CajaRegistradora
	var pedidos: Array[ObjetoDelAlmacen] = []

	func pedir_anotar(objeto: ObjetoDelAlmacen) -> void:
		pedidos.append(objeto)


# AC-PLY-073, AC-CTR-021
func test_el_lector_anota_la_unidad_con_el_programa_cerrado_y_conserva_la_mano() -> void:
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	var unidad := _unidad(almacen)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(unidad.datos, unidad)).is_true()
	var padre := unidad.get_parent()
	var lector: Node3D = almacen.get_node("Estructura/Lector")
	for _renglon in GeneradorDeTickets.RENGLONES:
		_accion(jugador, lector, ReglasDelJugador.ACCION_USAR)
	assert_array(_caja(almacen).generador().renglones()).contains_exactly(
		[
			(unidad.datos as UnidadDeProducto).producto,
			(unidad.datos as UnidadDeProducto).producto,
			(unidad.datos as UnidadDeProducto).producto
		]
	)
	assert_object(agarre.manos().sostenido()).is_same(unidad.datos)
	assert_object(unidad.get_parent()).is_same(padre)
	assert_bool(unidad.freeze).is_true()
	assert_bool(_vista(almacen).visible).is_false()
	_accion(jugador, _puesto(almacen), ReglasDelJugador.ACCION_USAR)
	assert_str(_vista(almacen).filas[0].text).is_equal(
		(unidad.datos as UnidadDeProducto).producto.nombre
	)


func test_los_seis_objetos_se_rechazan_y_siguen_en_la_mano() -> void:  # AC-PLY-073, AC-CTR-022
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var papel: ObjetoAgarrable = PAPEL.instantiate()
	papel.datos = Ticket.new()
	almacen.add_child(papel)
	var objetos: Array[Node3D] = [
		almacen.get("_cajas_de_productos")[0],
		almacen.get_node("Objetos/Mopa"),
		almacen.get_node("Objetos/Balde"),
		almacen.get_node("Objetos/JabonAmarillo"),
		almacen.get_node("Objetos/BolsaDeBasura1"),
		papel
	]
	var rechazos: Array[int] = []
	_caja(almacen).lectura_rechazada.connect(func(motivo: int) -> void: rechazos.append(motivo))
	for objeto in objetos:
		var dato: ObjetoDelAlmacen = objeto.get("datos")
		assert_bool(agarre.pedir_agarrar(dato, objeto)).is_true()
		var padre := objeto.get_parent()
		_accion(jugador, almacen.get_node("Estructura/Lector"), ReglasDelJugador.ACCION_USAR)
		assert_object(agarre.manos().sostenido()).is_same(dato)
		assert_object(objeto.get_parent()).is_same(padre)
		assert_array(_caja(almacen).generador().renglones()).is_empty()
		agarre.entregar()
	assert_array(rechazos).contains_exactly(
		[
			GeneradorDeTickets.Resultado.NO_ES_PRODUCTO,
			GeneradorDeTickets.Resultado.NO_ES_PRODUCTO,
			GeneradorDeTickets.Resultado.NO_ES_PRODUCTO,
			GeneradorDeTickets.Resultado.NO_ES_PRODUCTO,
			GeneradorDeTickets.Resultado.NO_ES_PRODUCTO,
			GeneradorDeTickets.Resultado.NO_ES_PRODUCTO
		]
	)


func test_las_manos_vacias_y_los_otros_gestos_no_leen() -> void:  # AC-PLY-073
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	var caja: CajaContadora = auto_free(CajaContadora.new())
	var lector: Node3D = almacen.get_node("Estructura/Lector")
	lector.set("caja", caja)
	for accion: StringName in [
		ReglasDelJugador.ACCION_USAR,
		ReglasDeLosObjetos.ACCION_AGARRAR,
		ReglasDeLosObjetos.ACCION_EXAMINAR
	]:
		_accion(jugador, lector, accion)
	assert_array(caja.pedidos).is_empty()
	assert_array(_caja(almacen).generador().renglones()).is_empty()
	assert_bool(_vista(almacen).visible).is_false()
	assert_bool((jugador.get("examen") as Examen).esta_examinando()).is_false()


func _sitios(almacen: Node3D, objetivo: PhysicsBody3D, centro: Vector3) -> Array[Vector3]:
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var espacio := almacen.get_world_3d().direct_space_state
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	var sitios: Array[Vector3] = []
	for distancia: float in [0.6, 0.8, 1.0, 1.2, 1.5, 2.0]:
		for paso in 16:
			var angulo := TAU * paso / 16.0
			var punto := centro + Vector3(cos(angulo), 0, sin(angulo)) * distancia
			var piso := PhysicsRayQueryParameters3D.create(
				punto + Vector3.UP, punto + Vector3.DOWN * 3.0, jugador.collision_mask
			)
			piso.exclude = [jugador.get_rid()]
			var golpe := espacio.intersect_ray(piso)
			if golpe.is_empty() or golpe.normal.y < 0.95:
				continue
			var apoyo := golpe.collider as StaticBody3D
			if (
				apoyo == null
				or not (
					apoyo.name == "SueloSolido"
					or str(apoyo.get_path()).ends_with("/almacen/StaticBody3D")
				)
			):
				continue
			var posicion: Vector3 = golpe.position + Vector3.UP * 0.02
			var volumen := PhysicsShapeQueryParameters3D.new()
			volumen.shape = forma.shape
			volumen.transform = Transform3D(Basis.IDENTITY, posicion) * forma.transform
			volumen.collision_mask = jugador.collision_mask
			volumen.exclude = [jugador.get_rid()]
			if not espacio.intersect_shape(volumen).is_empty():
				continue
			var ojo := posicion + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
			var rayo := PhysicsRayQueryParameters3D.create(ojo, centro, 3)
			rayo.exclude = [jugador.get_rid()]
			var impacto := espacio.intersect_ray(rayo)
			if (
				impacto.get("collider") == objetivo
				and ojo.distance_to(impacto.position) <= ReglasDelJugador.ALCANCE_DE_LA_MIRA
			):
				sitios.append(posicion)
	return sitios


func _enfocar(almacen: Node3D, objetivo: PhysicsBody3D, centro: Vector3) -> bool:
	var sitios := _sitios(almacen, objetivo, centro)
	(
		assert_array(sitios)
		. override_failure_message("Sin piso transitable para " + objetivo.name)
		. is_not_empty()
	)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	for posicion in sitios:
		jugador.global_position = posicion
		jugador.reset_physics_interpolation()
		camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
		camara.look_at(centro)
		for _cuadro in 3:
			await get_tree().physics_frame
		jugador.call("_leer_la_mira")
		if jugador.get("_enfocado") == objetivo:
			return true
	return false


func test_escaneo_con_foco_real_carga_la_caja_y_permite_imprimir() -> void:  # AC-CTR-021
	var almacen := await _abrir()
	var unidad := _unidad(almacen)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(unidad.datos, unidad)).is_true()
	var lector: StaticBody3D = almacen.get_node("Estructura/Lector")
	assert_bool(await _enfocar(almacen, lector, lector.global_position)).is_true()
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_RIGHT
	evento.pressed = true
	get_viewport().push_input(evento)
	evento = evento.duplicate()
	evento.pressed = false
	get_viewport().push_input(evento)
	assert_bool(_vista(almacen).visible).is_false()
	assert_array(_caja(almacen).generador().renglones()).contains_exactly(
		[(unidad.datos as UnidadDeProducto).producto]
	)
	var puesto := _puesto(almacen)
	assert_bool(await _enfocar(almacen, puesto, puesto.global_position)).is_true()
	evento.pressed = true
	get_viewport().push_input(evento)
	evento = evento.duplicate()
	evento.pressed = false
	get_viewport().push_input(evento)
	assert_bool(_vista(almacen).visible).is_true()
	_vista(almacen).imprimir.pressed.emit()
	assert_array(_papeles(almacen)).has_size(1)
	assert_object(agarre.manos().sostenido()).is_same(unidad.datos)


# AC-CTR-021, AC-CTR-022, AC-CTR-024
func test_los_eventos_reales_piden_escaneo_error_impresion_y_botones() -> void:
	var almacen := await _abrir()
	var reproductor: ReproductorDeSonidos = almacen.get_node(
		"Servicios/AudioDelAlmacen/Reproductor"
	)
	var sonidos: Array[int] = []
	reproductor.sonido_pedido.connect(func(evento: int) -> void: sonidos.append(evento))
	var jugador: Node3D = almacen.get_node("Jugador")
	var lector: Node3D = almacen.get_node("Estructura/Lector")
	_accion(jugador, lector, ReglasDelJugador.ACCION_USAR)
	_caja(almacen).pedir_imprimir()
	assert_array(sonidos).is_empty()
	var unidad := _unidad(almacen)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(unidad.datos, unidad)).is_true()
	sonidos.clear()
	for _renglon in GeneradorDeTickets.RENGLONES:
		_accion(jugador, lector, ReglasDelJugador.ACCION_USAR)
	_accion(jugador, lector, ReglasDelJugador.ACCION_USAR)
	_caja(almacen).pedir_anotar(ObjetoDelAlmacen.new())
	_caja(almacen).pedir_imprimir()
	_vista(almacen).borrar.pressed.emit()
	_vista(almacen).imprimir.pressed.emit()
	assert_array(sonidos).contains_exactly(
		[
			EntradaSonora.Evento.LECTOR_ESCANEADO,
			EntradaSonora.Evento.LECTOR_ESCANEADO,
			EntradaSonora.Evento.LECTOR_ESCANEADO,
			EntradaSonora.Evento.LECTOR_RECHAZADO,
			EntradaSonora.Evento.LECTOR_RECHAZADO,
			EntradaSonora.Evento.TICKET_IMPRESO,
			EntradaSonora.Evento.BOTON_DE_LA_COMPUTADORA,
			EntradaSonora.Evento.BOTON_DE_LA_COMPUTADORA
		]
	)
	sonidos.clear()
	# El aviso de cobro pertenece al recorrido anterior, conservado desde la jornada 2.
	almacen.call("_al_abrir_la_jornada", 2)
	var atenciones: Ventanilla = almacen.get("_atenciones")
	atenciones.pedir_atender()
	assert_object(atenciones.atencion()).is_not_null()
	if atenciones.atencion() == null:
		return
	var panel: PanelDeLaVentanilla = almacen.get_node("Interfaz/PanelDeLaVentanilla")
	var aviso: Label = panel.get("_aviso")
	aviso.text = "Sin repintar"
	sonidos.clear()
	var faltantes: Array[Producto] = []
	atenciones.cobro_rechazado.emit(faltantes)
	assert_str(aviso.text).is_equal(atenciones.atencion().aviso())
	assert_array(sonidos).is_empty()
	var tabla := TablaDeSonidos.desde_disco()
	for evento: EntradaSonora.Evento in [
		EntradaSonora.Evento.LECTOR_ESCANEADO,
		EntradaSonora.Evento.LECTOR_RECHAZADO,
		EntradaSonora.Evento.TICKET_IMPRESO
	]:
		var fila := tabla.de(evento)
		assert_object(fila).is_not_null()
		if fila == null:
			return
		assert_bool(fila.posicional).is_true()
		assert_str(fila.emisor).is_equal("Caja")
		assert_str(fila.bus).is_equal(EntradaSonora.BUS_DE_EFECTOS)


func test_la_tres_vacia_y_la_uno_recupera_la_lectura() -> void:  # AC-CTR-026, AC-CTR-029
	var almacen := await _abrir()
	var lector: StaticBody3D = almacen.get_node("Estructura/Lector")
	var malla: MeshInstance3D = lector.get_node("Malla")
	almacen.call("_al_abrir_la_jornada", 2)
	_caja(almacen).pedir_anotar(UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI)))
	assert_int(_caja(almacen).generador().renglones().size()).is_equal(1)
	almacen.call("_al_abrir_la_jornada", 3)
	assert_bool(_caja(almacen).generador().es_manual()).is_true()
	assert_array(_caja(almacen).generador().renglones()).is_empty()
	await get_tree().physics_frame
	var centro := malla.to_global(malla.mesh.get_aabb().get_center())
	assert_bool(await _enfocar(almacen, lector, centro)).is_true()
	almacen.call("_al_abrir_la_jornada", 5)
	assert_bool(_caja(almacen).generador().es_manual()).is_true()
	almacen.call("_al_abrir_la_jornada", 1)
	assert_bool(_caja(almacen).generador().es_manual()).is_false()
	var jugador: Node3D = almacen.get_node("Jugador")
	var unidad := _unidad(almacen)
	assert_bool((almacen.get("_agarre") as Agarre).pedir_agarrar(unidad.datos, unidad)).is_true()
	_accion(jugador, lector, ReglasDelJugador.ACCION_USAR)
	assert_int(_caja(almacen).generador().renglones().size()).is_equal(1)


func test_el_hueco_con_unidad_caja_y_mano_vacia_no_avisa_ni_anota() -> void:  # AC-CTR-029
	var almacen := await _abrir()
	almacen.call("_al_abrir_la_jornada", 3)
	var jugador: Node3D = almacen.get_node("Jugador")
	var lector: Node3D = almacen.get_node("Estructura/Lector")
	var agarre: Agarre = almacen.get("_agarre")
	var eventos: Array[String] = []
	_caja(almacen).producto_leido.connect(func() -> void: eventos.append("lectura"))
	_caja(almacen).lectura_rechazada.connect(func(_motivo: int) -> void: eventos.append("rechazo"))
	_caja(almacen).renglones_cambiados.connect(func() -> void: eventos.append("cambio"))
	var sonidos: Array[int] = []
	var reproductor: ReproductorDeSonidos = almacen.get_node(
		"Servicios/AudioDelAlmacen/Reproductor"
	)
	reproductor.sonido_pedido.connect(func(sonido: int) -> void: sonidos.append(sonido))
	var objetos: Array[Node3D] = [null, _unidad(almacen), almacen.get("_cajas_de_productos")[0]]
	for objeto in objetos:
		var dato: ObjetoDelAlmacen = null if objeto == null else objeto.get("datos")
		if objeto != null:
			assert_bool(agarre.pedir_agarrar(dato, objeto)).is_true()
		var padre: Node = null if objeto == null else objeto.get_parent()
		eventos.clear()
		sonidos.clear()
		_accion(jugador, lector, ReglasDelJugador.ACCION_USAR)
		assert_array(_caja(almacen).generador().renglones()).is_empty()
		assert_array(eventos).is_empty()
		assert_array(sonidos).is_empty()
		if objeto == null:
			assert_object(agarre.manos().sostenido()).is_null()
		else:
			assert_object(agarre.manos().sostenido()).is_same(dato)
			assert_object(objeto.get_parent()).is_same(padre)
			agarre.entregar()


func test_la_partida_retomada_en_cuatro_es_manual_y_una_nueva_es_automatica() -> void:  # AC-CTR-026
	var datos := {PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA): 4}
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde(datos))
	add_child(almacen)
	almacen.get_node("Jugador").set_physics_process(false)
	for _cuadro in 4:
		await get_tree().physics_frame
	assert_int((almacen.get("_partida") as Partida).jornada()).is_equal(4)
	assert_bool(_caja(almacen).generador().es_manual()).is_true()
	var nueva: Node3D = auto_free(ALMACEN.instantiate())
	nueva.set("_partida", Partida.nueva())
	add_child(nueva)
	nueva.get_node("Jugador").set_physics_process(false)
	for _cuadro in 4:
		await get_tree().physics_frame
	assert_int((nueva.get("_partida") as Partida).jornada()).is_equal(1)
	assert_bool(_caja(nueva).generador().es_manual()).is_false()


func test_el_popup_pausa_y_reanuda_programa_y_mano() -> void:  # AC-CTR-030, AC-PLY-074
	var almacen := await _abrir()
	almacen.call("_al_abrir_la_jornada", 3)
	var jugador: Node3D = almacen.get_node("Jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var unidad := _unidad(almacen)
	assert_bool(agarre.pedir_agarrar(unidad.datos, unidad)).is_true()
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	_caja(almacen).pedir_elegir(2, marolini)
	_puesto(almacen).call("abrir")
	var selector := _vista(almacen).selectores[2]
	selector.show_popup()
	assert_bool(selector.get_popup().visible).is_true()
	var evento := InputEventKey.new()
	evento.keycode = KEY_ESCAPE
	evento.pressed = true
	selector.get_popup().window_input.emit(evento)
	for _cuadro in 4:
		await get_tree().process_frame
	assert_bool(get_tree().paused).is_true()
	assert_bool((almacen.get_node("Interfaz/MenuDePausa") as CanvasLayer).visible).is_true()
	assert_bool(selector.get_popup().visible).is_false()
	assert_bool(_vista(almacen).visible).is_true()
	assert_object(agarre.manos().sostenido()).is_same(unidad.datos)
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	pausa.reanudar()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_vista(almacen).visible).is_true()
	assert_object(_caja(almacen).generador().en_el_renglon(2)).is_same(marolini)
	assert_int(selector.selected).is_equal(_opcion_de(marolini))
	assert_bool((jugador.get("_control") as ControlDelJugador).esta_suspendido()).is_true()
	selector.show_popup()
	var derecho := InputEventMouseButton.new()
	derecho.button_index = MOUSE_BUTTON_RIGHT
	derecho.pressed = true
	selector.get_popup().window_input.emit(derecho)
	for _cuadro in 2:
		await get_tree().process_frame
	assert_bool(_vista(almacen).visible).is_false()
	assert_bool(selector.get_popup().visible).is_false()
	assert_bool((jugador.get("_control") as ControlDelJugador).esta_suspendido()).is_false()
	assert_object(agarre.manos().sostenido()).is_same(unidad.datos)


func _opcion_de(producto: Producto) -> int:
	var catalogo := Catalogo.todos()
	for indice in catalogo.size():
		if catalogo[indice].id == producto.id:
			return indice + 1
	return -1
