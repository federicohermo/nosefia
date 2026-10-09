extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const UNIDAD := preload("res://src/escenas/objetos/objeto_agarrable.tscn")
const PAPEL := preload("res://src/escenas/objetos/ticket.tscn")

var _almacenes: Array[Node3D] = []


func after_test() -> void:
	get_tree().paused = false
	for almacen in _almacenes:
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
	assert_object(_puesto(almacen).get("agarre")).is_same(almacen.get_node("Jugador").get("agarre"))
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


func test_el_derecho_abre_y_cierra_con_los_ocho_estados_de_la_mano() -> void:  # AC-PLY-072
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var papel: ObjetoAgarrable = PAPEL.instantiate()
	papel.datos = Ticket.new()
	almacen.add_child(papel)
	var objetos: Array[Node3D] = [
		null,
		_unidad(almacen),
		almacen.get("_cajas_de_productos")[0],
		almacen.get_node("Objetos/Mopa"),
		almacen.get_node("Objetos/Balde"),
		almacen.get_node("Objetos/JabonAmarillo"),
		almacen.get_node("Objetos/BolsaDeBasura1"),
		papel
	]
	for objeto in objetos:
		var dato: ObjetoDelAlmacen = null if objeto == null else objeto.get("datos")
		if objeto != null:
			assert_bool(agarre.pedir_agarrar(dato, objeto)).is_true()
		var padre: Node = null if objeto == null else objeto.get_parent()
		_accion(jugador, _puesto(almacen), ReglasDelJugador.ACCION_USAR)
		assert_bool(_vista(almacen).visible).is_true()
		assert_bool((jugador.get("_control") as ControlDelJugador).esta_suspendido()).is_true()
		for accion: StringName in [
			ReglasDeLosObjetos.ACCION_AGARRAR, ReglasDeLosObjetos.ACCION_EXAMINAR
		]:
			_accion(jugador, _puesto(almacen), accion)
			assert_bool((jugador.get("examen") as Examen).esta_examinando()).is_false()
		await _derecho()
		assert_bool(_vista(almacen).visible).is_false()
		assert_bool((jugador.get("_control") as ControlDelJugador).esta_suspendido()).is_false()
		if objeto == null:
			assert_object(agarre.manos().sostenido()).is_null()
		else:
			assert_object(agarre.manos().sostenido()).is_same(dato)
			assert_object(objeto.get_parent()).is_same(padre)
			agarre.entregar()


func test_izquierdo_y_examen_vacios_no_abren_y_otras_pantallas_bloquean() -> void:  # AC-PLY-072
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	for accion: StringName in [
		ReglasDeLosObjetos.ACCION_AGARRAR, ReglasDeLosObjetos.ACCION_EXAMINAR
	]:
		_accion(jugador, _puesto(almacen), accion)
		assert_bool(_vista(almacen).visible).is_false()
	for ruta: String in ["Estructura/base compu/StaticBody3D", "Estructura/Ventanilla"]:
		var pantalla: Node3D = almacen.get_node(ruta)
		pantalla.call("abrir")
		_accion(jugador, _puesto(almacen), ReglasDelJugador.ACCION_USAR)
		assert_bool(_vista(almacen).visible).is_false()
		pantalla.call("cerrar")
	var hoja: Node3D = almacen.get_node("Estructura/NotasDelAlmacen").get("notas")[0]
	_accion(jugador, hoja, ReglasDelJugador.ACCION_USAR)
	_accion(jugador, _puesto(almacen), ReglasDelJugador.ACCION_USAR)
	assert_bool(_vista(almacen).visible).is_false()
	await _derecho()
	var unidad := _unidad(almacen)
	assert_bool((almacen.get("_agarre") as Agarre).pedir_agarrar(unidad.datos, unidad)).is_true()
	_accion(jugador, unidad, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_bool((jugador.get("examen") as Examen).esta_examinando()).is_true()
	_accion(jugador, _puesto(almacen), ReglasDelJugador.ACCION_USAR)
	assert_bool(_vista(almacen).visible).is_false()


func test_el_reloj_corre_la_pausa_real_va_encima_y_el_turno_cierra() -> void:  # AC-PLY-074
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var tiempos: Array[float] = []
	reloj.tiempo_consumido.connect(func(tiempo: float) -> void: tiempos.append(tiempo))
	_accion(jugador, _puesto(almacen), ReglasDelJugador.ACCION_USAR)
	for _cuadro in 6:
		await get_tree().process_frame
	assert_bool(reloj.corriendo()).is_true()
	assert_int(tiempos.size()).is_greater(1)
	assert_float(tiempos.back()).is_less(tiempos.front())
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	var evento := InputEventAction.new()
	evento.action = &"ui_cancel"
	evento.pressed = true
	pausa.call("_input", evento)
	var menu: CanvasLayer = almacen.get_node("Interfaz/MenuDePausa")
	assert_bool(get_tree().paused).is_true()
	assert_bool(menu.visible).is_true()
	assert_bool(_vista(almacen).visible).is_true()
	assert_int(menu.layer).is_greater(_vista(almacen).layer)
	var antes := tiempos.size()
	for _cuadro in 4:
		await get_tree().process_frame
	assert_int(tiempos.size()).is_equal(antes)
	pausa.call("_input", evento)
	assert_bool(get_tree().paused).is_false()
	assert_bool(_vista(almacen).visible).is_true()
	reloj.turno_cerrado.emit(0)
	assert_bool(_vista(almacen).visible).is_false()
	assert_bool((almacen.get_node("Interfaz/PantallaDeCierre") as CanvasLayer).visible).is_true()
	assert_bool((jugador.get("_control") as ControlDelJugador).esta_suspendido()).is_true()


# AC-CTR-023, AC-CTR-024
func test_los_botones_imprimen_copia_y_borrar_repinta_tres_vacios() -> void:
	var almacen := await _abrir()
	_puesto(almacen).call("abrir")
	_vista(almacen).imprimir.pressed.emit()
	assert_array(_papeles(almacen)).is_empty()
	var productos: Array[Producto] = [
		Catalogo.de(Producto.Id.MAROLINI), Catalogo.de(Producto.Id.CORACOLA)
	]
	for producto in productos:
		_caja(almacen).pedir_anotar(UnidadDeProducto.new(producto))
	_vista(almacen).imprimir.pressed.emit()
	var papeles := _papeles(almacen)
	assert_int(papeles.size()).is_equal(1)
	if papeles.is_empty():
		return
	_puesto(almacen).call("abrir")
	_vista(almacen).borrar.pressed.emit()
	assert_array((papeles[0].datos as Ticket).renglones()).contains_exactly(productos)
	assert_array(_caja(almacen).generador().renglones()).is_empty()
	for fila in _vista(almacen).filas:
		assert_str(fila.text).is_empty()
	_vista(almacen).imprimir.pressed.emit()
	assert_int(_papeles(almacen).size()).is_equal(1)


func test_imprimir_otra_vez_suelta_el_anterior_y_permite_recoger_el_nuevo() -> void:  # AC-PLY-076
	var almacen := await _abrir()
	_emitir_papel(almacen)
	var papeles := _papeles(almacen)
	assert_int(papeles.size()).is_equal(1)
	if papeles.is_empty():
		return
	var primero := papeles[0]
	await get_tree().create_timer(1.0).timeout
	assert_bool(primero.freeze).is_true()
	_emitir_papel(almacen)
	papeles = _papeles(almacen)
	assert_int(papeles.size()).is_equal(2)
	if papeles.size() != 2:
		return
	assert_bool(primero.freeze).is_false()
	var segundo := papeles[1]
	assert_bool(segundo.freeze).is_true()
	await get_tree().create_timer(1.0).timeout
	_accion(almacen.get_node("Jugador"), segundo, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object((almacen.get("_agarre") as Agarre).manos().sostenido()).is_same(segundo.datos)


# AC-PLY-075, AC-PLY-076
func test_imprimir_otro_con_el_anterior_en_mano_no_lo_descongela() -> void:
	var almacen := await _abrir()
	_emitir_papel(almacen)
	var papeles := _papeles(almacen)
	assert_int(papeles.size()).is_equal(1)
	if papeles.is_empty():
		return
	var primero := papeles[0]
	var jugador: Node3D = almacen.get_node("Jugador")
	_accion(jugador, primero, ReglasDeLosObjetos.ACCION_AGARRAR)
	var agarre: Agarre = almacen.get("_agarre")
	assert_object(agarre.manos().sostenido()).is_same(primero.datos)
	# Se agarró mientras salía: la animación no lo sigue moviendo en la mano.
	var en_la_mano := primero.position
	await get_tree().create_timer(1.0).timeout
	assert_vector(primero.position).is_equal(en_la_mano)
	var padre := primero.get_parent()
	_emitir_papel(almacen)
	assert_bool(primero.freeze).is_true()
	assert_object(primero.get_parent()).is_same(padre)
	assert_int(_papeles(almacen).size()).is_equal(2)
	_accion(jugador, primero, ReglasDeLosObjetos.ACCION_EXAMINAR)
	var examen: Examen = jugador.get("examen")
	assert_bool(examen.esta_examinando()).is_true()
	assert_str(primero.datos.texto_visible(true)).is_equal("Ticket")
	assert_int(primero.datos.sonoridad).is_equal(EntradaSonora.Sonoridad.PAPEL)
	examen.terminar()
	_accion(jugador, primero, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(primero.freeze).is_false()
	assert_object(primero.get_parent()).is_same(almacen)


# AC-CTR-025, AC-PLY-077
func test_otra_jornada_quita_papeles_del_piso_y_del_examen_y_vacia_el_programa() -> void:
	var almacen := await _abrir()
	_caja(almacen).pedir_anotar(UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI)))
	_emitir_papel(almacen)
	var papeles := _papeles(almacen)
	assert_int(papeles.size()).is_equal(1)
	if papeles.is_empty():
		return
	var malla: MeshInstance3D = almacen.get_node("Estructura/cajaregistradora")
	var sitios := _sitios(
		almacen, _puesto(almacen), malla.to_global(malla.mesh.get_aabb().get_center())
	)
	assert_array(sitios).is_not_empty()
	if sitios.is_empty():
		return
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var rayo := PhysicsRayQueryParameters3D.create(
		sitios[0] + Vector3.UP, sitios[0] + Vector3.DOWN, 1
	)
	rayo.exclude = [jugador.get_rid(), papeles[0].get_rid()]
	var espacio := almacen.get_world_3d().direct_space_state
	var piso := espacio.intersect_ray(rayo)
	assert_bool(piso.is_empty()).is_false()
	if piso.is_empty():
		return
	var suelto := papeles[0]
	await get_tree().create_timer(1.0).timeout
	suelto.global_transform = Transform3D(Basis.IDENTITY, piso.position + Vector3.UP * 0.06)
	suelto.freeze = false
	suelto.sleeping = false
	for _cuadro in 60:
		await get_tree().physics_frame
	assert_bool(suelto.freeze).is_false()
	assert_object(suelto.get_parent()).is_same(almacen.get_node("Estructura"))
	_emitir_papel(almacen)
	papeles = _papeles(almacen)
	assert_int(papeles.size()).is_equal(2)
	if papeles.size() != 2:
		return
	_accion(jugador, papeles[1], ReglasDeLosObjetos.ACCION_AGARRAR)
	_accion(jugador, papeles[1], ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_bool((jugador.get("examen") as Examen).esta_examinando()).is_true()
	almacen.call("_al_abrir_la_jornada", 2)
	for _cuadro in 3:
		await get_tree().physics_frame
	assert_array(_papeles(almacen)).is_empty()
	assert_array(_caja(almacen).generador().renglones()).is_empty()
	assert_object((almacen.get("_agarre") as Agarre).manos().sostenido()).is_null()
	assert_bool((jugador.get("examen") as Examen).esta_examinando()).is_false()
	for papel in papeles:
		assert_bool(is_instance_valid(papel)).is_false()


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
			if apoyo == null:
				continue
			var dueno := apoyo.shape_owner_get_owner(apoyo.shape_find_owner(golpe.shape)) as Node
			if not (
				apoyo.name == "SueloSolido"
				or str(apoyo.get_path()).ends_with("/almacen/StaticBody3D")
				or dueno.name == "VolumenDelPisoDelBano"
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


# AC-PLY-072, AC-PLY-075, AC-PLY-076
func test_caja_lee_imprime_y_entrega_el_ticket_desde_el_mismo_puesto() -> void:
	var almacen := await _abrir()
	var puesto := _puesto(almacen)
	var malla: MeshInstance3D = almacen.get_node("Estructura/cajaregistradora")
	var unidad := _unidad(almacen)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(unidad.datos, unidad)).is_true()
	var lector: StaticBody3D = almacen.get_node("Estructura/Lector")
	var malla_del_lector: MeshInstance3D = lector.get_node("Malla")
	(
		assert_bool(
			await _enfocar(
				almacen,
				lector,
				malla_del_lector.to_global(malla_del_lector.mesh.get_aabb().get_center())
			)
		)
		. is_true()
	)
	await _derecho()
	assert_bool(_vista(almacen).visible).is_false()
	(
		assert_bool(
			await _enfocar(almacen, puesto, malla.to_global(malla.mesh.get_aabb().get_center()))
		)
		. is_true()
	)
	await _derecho()
	assert_bool(_vista(almacen).visible).is_true()
	assert_array(_caja(almacen).generador().renglones()).contains_exactly(
		[(unidad.datos as UnidadDeProducto).producto]
	)
	_vista(almacen).imprimir.pressed.emit()
	assert_bool(_vista(almacen).visible).is_false()
	var papeles := _papeles(almacen)
	assert_array(papeles).has_size(1)
	if papeles.is_empty():
		return
	var papel := papeles[0]
	await get_tree().create_timer(1.0).timeout
	var jugador: Node3D = almacen.get_node("Jugador")
	_accion(jugador, unidad, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(await _enfocar(almacen, papel, papel.global_position)).is_true()
	_accion(jugador, papel, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.manos().sostenido()).is_same(papel.datos)
	assert_array((papel.datos as Ticket).renglones()).contains_exactly(
		[(unidad.datos as UnidadDeProducto).producto]
	)


# AC-PLY-072, AC-CTR-026
func test_la_caja_manual_abre_sin_escanear_la_unidad_sostenida() -> void:
	var almacen := await _abrir()
	almacen.call("_al_abrir_la_jornada", 3)
	var unidad := _unidad(almacen)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(unidad.datos, unidad)).is_true()
	_accion(almacen.get_node("Jugador"), _puesto(almacen), ReglasDelJugador.ACCION_USAR)
	assert_bool(_vista(almacen).visible).is_true()
	assert_array(_caja(almacen).generador().renglones()).is_empty()
	assert_object(agarre.manos().sostenido()).is_same(unidad.datos)


func _abrir_bano() -> Node3D:
	var almacen := await _abrir()
	for numero: int in [1, 2]:
		var puerta: Node3D = almacen.get_node("Estructura/bano_puerta_%d/CuerpoDeLaHoja" % numero)
		puerta.call("usar")
	for _cuadro in 60:
		await get_tree().physics_frame
	for numero: int in [1, 2]:
		var puerta: Node3D = almacen.get_node("Estructura/bano_puerta_%d/CuerpoDeLaHoja" % numero)
		assert_bool((puerta.call("puerta") as Puerta).abierta()).is_true()
	return almacen


func _nuevo_ticket(almacen: Node3D) -> ObjetoAgarrable:
	_emitir_papel(almacen)
	var papel: ObjetoAgarrable = _puesto(almacen).get("_en_ranura")
	assert_object(papel).is_not_null()
	return papel


func _enfocar_artefacto(almacen: Node3D, nombre: String) -> PhysicsBody3D:
	var objetivo: PhysicsBody3D = almacen.get_node("Estructura/" + nombre + "/StaticBody3D")
	var mallas: Array[MeshInstance3D] = []
	mallas.assign(objetivo.get("mallas"))
	assert_array(mallas).is_not_empty()
	if mallas.is_empty():
		return null
	assert_bool(mallas[0].is_visible_in_tree()).is_true()
	var centro := mallas[0].to_global(mallas[0].mesh.get_aabb().get_center())
	var enfocado := await _enfocar(almacen, objetivo, centro)
	assert_bool(enfocado).override_failure_message(nombre).is_true()
	if not enfocado:
		return null
	assert_object((almacen.get_node("Jugador") as Node3D).get("_enfocado")).is_same(objetivo)
	return objetivo


func _derecho_sobre(jugador: Node3D, objetivo: PhysicsBody3D) -> void:
	assert_object(jugador.get("_enfocado")).is_same(objetivo)
	var evento := InputEventAction.new()
	evento.action = ReglasDelJugador.ACCION_USAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


# AC-CTR-031, AC-PLY-078, AC-PLY-014
func test_cada_inodoro_desecha_una_vez_su_ticket_con_foco_real() -> void:
	var almacen := await _abrir_bano()
	var jugador: Node3D = almacen.get_node("Jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var avisos: Array[int] = []
	_caja(almacen).ticket_desechado.connect(func() -> void: avisos.append(1))
	for nombre: String in ["inodoro", "bano_inodoro_2"]:
		var papel := _nuevo_ticket(almacen)
		if papel == null:
			return
		assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
		var objetivo := await _enfocar_artefacto(almacen, nombre)
		if objetivo == null:
			return
		var antes := avisos.size()
		_derecho_sobre(jugador, objetivo)
		assert_object(agarre.manos().sostenido()).is_null()
		_derecho_sobre(jugador, objetivo)
		for _cuadro in 3:
			await get_tree().process_frame
		assert_bool(is_instance_valid(papel)).is_false()
		assert_array(_puesto(almacen).get("_tickets")).is_empty()
		assert_int(avisos.size()).is_equal(antes + 1)
	assert_int(avisos.size()).is_equal(2)


func test_lavatorios_otros_objetos_y_papel_ajeno_no_se_desechan() -> void:  # AC-CTR-032
	var almacen := await _abrir_bano()
	var jugador: Node3D = almacen.get_node("Jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var avisos: Array[int] = []
	_caja(almacen).ticket_desechado.connect(func() -> void: avisos.append(1))
	var papel := _nuevo_ticket(almacen)
	if papel == null:
		return
	assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
	for nombre: String in ["vanitory", "bano_lavatorio_2"]:
		var objetivo := await _enfocar_artefacto(almacen, nombre)
		if objetivo == null:
			return
		_derecho_sobre(jugador, objetivo)
		assert_object(agarre.manos().sostenido()).is_same(papel.datos)
		assert_bool(is_instance_valid(papel)).is_true()
		agarre.entregar()
		assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
	var entregado := agarre.entregar()
	assert_object(entregado).is_same(papel)
	var ajeno: ObjetoAgarrable = PAPEL.instantiate()
	ajeno.datos = papel.datos
	almacen.add_child(ajeno)
	var objetos: Array[Node3D] = [
		null,
		_unidad(almacen),
		almacen.get("_cajas_de_productos")[0],
		almacen.get_node("Objetos/Mopa"),
		almacen.get_node("Objetos/Balde"),
		almacen.get_node("Objetos/JabonAmarillo"),
		almacen.get_node("Objetos/BolsaDeBasura1"),
		ajeno
	]
	for objeto in objetos:
		var dato: ObjetoDelAlmacen = null if objeto == null else objeto.get("datos")
		if objeto != null:
			await (
				assert_error(
					func() -> void: assert_bool(agarre.pedir_agarrar(dato, objeto)).is_true()
				)
				. is_success()
			)
		var objetivo := await _enfocar_artefacto(almacen, "inodoro")
		if objetivo == null:
			return
		_derecho_sobre(jugador, objetivo)
		if dato == null:
			assert_object(agarre.manos().sostenido()).is_null()
		else:
			assert_object(agarre.manos().sostenido()).is_same(dato)
		if objeto != null:
			assert_bool(is_instance_valid(objeto)).is_true()
			agarre.entregar()
	assert_array(avisos).is_empty()


# AC-CTR-032, AC-PLY-014
func test_balde_vacia_y_mopa_enjuaga_en_ambos_inodoros_sin_descarte() -> void:
	var almacen := await _abrir_bano()
	var jugador: Node3D = almacen.get_node("Jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var limpiador: Limpiador = almacen.get("_limpiador")
	var piso := limpiador.piso()
	var avisos: Array[int] = []
	_caja(almacen).ticket_desechado.connect(func() -> void: avisos.append(1))
	var balde: Node3D = almacen.get_node("Objetos/Balde")
	var mopa: Node3D = almacen.get_node("Objetos/Mopa")
	for nombre: String in ["inodoro", "bano_inodoro_2"]:
		limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
		assert_bool(piso.balde().tiene_agua()).is_true()
		assert_bool(agarre.pedir_agarrar(balde.get("datos"), balde)).is_true()
		var objetivo := await _enfocar_artefacto(almacen, nombre)
		if objetivo == null:
			return
		_derecho_sobre(jugador, objetivo)
		assert_bool(piso.balde().tiene_agua()).is_false()
		assert_object(agarre.manos().sostenido()).is_same(balde.get("datos"))
		agarre.entregar()
		limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
		limpiador.usar(&"jabon_amarillo", ReglasDeLaLimpieza.ID_DEL_BALDE)
		limpiador.usar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, ReglasDeLaLimpieza.ID_DEL_BALDE)
		assert_int(piso.mopa().agua()).is_equal(ReglasDeLaLimpieza.Agua.AMARILLO)
		assert_bool(agarre.pedir_agarrar(mopa.get("datos"), mopa)).is_true()
		objetivo = await _enfocar_artefacto(almacen, nombre)
		if objetivo == null:
			return
		_derecho_sobre(jugador, objetivo)
		assert_int(piso.mopa().agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)
		assert_object(agarre.manos().sostenido()).is_same(mopa.get("datos"))
		agarre.entregar()
	assert_array(avisos).is_empty()


func test_izquierdo_suelta_y_examen_suspende_sin_desechar() -> void:  # AC-PLY-078
	var almacen := await _abrir_bano()
	var jugador: Node3D = almacen.get_node("Jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var avisos: Array[int] = []
	_caja(almacen).ticket_desechado.connect(func() -> void: avisos.append(1))
	var papel := _nuevo_ticket(almacen)
	if papel == null:
		return
	assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
	var objetivo := await _enfocar_artefacto(almacen, "inodoro")
	if objetivo == null:
		return
	_accion(jugador, objetivo, ReglasDeLosObjetos.ACCION_AGARRAR)
	for _cuadro in 4:
		await get_tree().physics_frame
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(is_instance_valid(papel)).is_true()
	assert_array(avisos).is_empty()
	assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
	_accion(jugador, papel, ReglasDeLosObjetos.ACCION_EXAMINAR)
	var examen: Examen = jugador.get("examen")
	assert_bool(examen.esta_examinando()).is_true()
	_accion(jugador, objetivo, ReglasDelJugador.ACCION_USAR)
	assert_bool(is_instance_valid(papel)).is_true()
	assert_object(agarre.manos().sostenido()).is_same(papel.datos)
	assert_array(avisos).is_empty()
	examen.terminar()


func test_proxima_jornada_limpia_restantes_sin_repetir_ticket_desechado() -> void:  # AC-CTR-033
	var almacen := await _abrir_bano()
	var jugador: Node3D = almacen.get_node("Jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var avisos: Array[int] = []
	_caja(almacen).ticket_desechado.connect(func() -> void: avisos.append(1))
	var primero := _nuevo_ticket(almacen)
	if primero == null:
		return
	assert_bool(agarre.pedir_agarrar(primero.datos, primero)).is_true()
	var segundo := _nuevo_ticket(almacen)
	if segundo == null:
		return
	var objetivo := await _enfocar_artefacto(almacen, "inodoro")
	if objetivo == null:
		return
	_derecho_sobre(jugador, objetivo)
	for _cuadro in 3:
		await get_tree().process_frame
	assert_bool(is_instance_valid(primero)).is_false()
	assert_bool(is_instance_valid(segundo)).is_true()
	assert_int(avisos.size()).is_equal(1)
	assert_int((_puesto(almacen).get("_tickets") as Array).size()).is_equal(1)
	almacen.call("_al_abrir_la_jornada", 2)
	for _cuadro in 3:
		await get_tree().physics_frame
	assert_bool(is_instance_valid(segundo)).is_false()
	assert_array(_puesto(almacen).get("_tickets")).is_empty()
	assert_object(_puesto(almacen).get("_en_ranura")).is_null()
	assert_object(agarre.manos().sostenido()).is_null()
	assert_array(_caja(almacen).generador().renglones()).is_empty()
	assert_int(avisos.size()).is_equal(1)
