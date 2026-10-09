## El gesto real entrega, conserva los rechazos y restaura lo persistente al abrir otra noche.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const CUERPO := "Estructura/deposito_contenedor_soporte/deposito_contenedor_cuerpo/StaticBody3D"
const BASE := "Estructura/deposito_contenedor_soporte/"
const TAPA := BASE + "deposito_contenedor_bisagra_tapa/CuerpoDeLaTapa"

var _almacen: Node3D


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null


func _abrir() -> Node3D:
	_almacen = ALMACEN.instantiate()
	add_child(_almacen)
	var jugador: Node3D = _almacen.get("_jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return _almacen


func _clic(jugador: Node3D, destino: Node3D, boton: MouseButton) -> void:
	jugador.set("_enfocado", destino)
	var evento := InputEventMouseButton.new()
	evento.button_index = boton
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _agarrar(almacen: Node3D, objeto: RigidBody3D) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	var datos: ObjetoDelAlmacen = objeto.get("datos")
	assert_bool(agarre.pedir_agarrar(datos, objeto)).is_true()
	assert_object(agarre.manos().sostenido()).is_same(datos)


func _unidad(almacen: Node3D) -> ObjetoAgarrable:
	almacen.get("_reposicion_manual").call("retirar", Producto.Id.ACTRONCITO)
	var agarre: Agarre = almacen.get("_agarre")
	assert_object(agarre.manos().sostenido()).is_instanceof(UnidadDeProducto)
	assert_int(agarre.punto_de_producto.get_child_count()).is_equal(1)
	return agarre.punto_de_producto.get_child(0) as ObjetoAgarrable


func _ticket(almacen: Node3D) -> ObjetoAgarrable:
	var productos: Array[Producto] = [Catalogo.de(Producto.Id.ACTRONCITO)]
	var caja: CajaRegistradora = almacen.get("_caja")
	caja.ticket_impreso.emit(Ticket.new(productos))
	var papel: ObjetoAgarrable = almacen.get("_puesto_de_la_caja").get("_en_ranura")
	assert_object(papel).is_not_null()
	assert_object(papel.datos).is_instanceof(Ticket)
	return papel


func test_tirar_cada_aceptado_lo_oculta_y_solo_la_bolsa_cuenta() -> void:  # AC-CLN-036
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var contenedor: Node3D = almacen.get_node(CUERPO)
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	var objetos: Array[ObjetoAgarrable] = []
	for nombre: String in [
		"BolsaDeBasura1", "Mopa", "Balde", "JabonAzul", "JabonRosa", "JabonAmarillo"
	]:
		objetos.append(almacen.get_node("Objetos/" + nombre))
	var unidad := _unidad(almacen)
	# Ya vino a la mano: tirarla antes de recorrer los persistentes.
	_clic(jugador, contenedor, MOUSE_BUTTON_LEFT)
	assert_object(agarre.manos().sostenido()).is_null()
	objetos.append(unidad)
	var ticket := _ticket(almacen)
	objetos.append(ticket)
	for objeto in objetos:
		if objeto != unidad:
			_agarrar(almacen, objeto)
			_clic(jugador, contenedor, MOUSE_BUTTON_LEFT)
		assert_object(agarre.manos().sostenido()).is_null()
		assert_bool(objeto.visible).is_false()
		assert_bool(objeto.freeze).is_true()
		assert_int(objeto.collision_layer).is_zero()
		assert_int(objeto.collision_mask).is_zero()
		assert_object(objeto.get_parent()).is_same(contenedor)
		var candidato: CampoDeInteraccion.Candidato = jugador.call("_medir_candidato", objeto)
		assert_bool(candidato.visible).is_false()
	assert_int(recolector.tarea().depositadas()).is_equal(1)
	assert_array(contenedor.call("tirados")).has_size(objetos.size())


func test_ambos_destinos_conservan_caja_y_carga_durante_giro() -> void:  # AC-CLN-037 AC-CLN-035
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var tapa: Node3D = almacen.get_node(TAPA)
	var bolsa: ObjetoAgarrable = almacen.get_node("Objetos/BolsaDeBasura1")
	var caja: RigidBody3D = almacen.get_node("Objetos/CajaDeActroncito")
	for ruta: String in [CUERPO, TAPA]:
		var destino: Node3D = almacen.get_node(ruta)
		_clic(jugador, destino, MOUSE_BUTTON_LEFT)
		assert_object(agarre.manos().sostenido()).is_null()
		_agarrar(almacen, caja)
		var padre := caja.get_parent()
		_clic(jugador, destino, MOUSE_BUTTON_LEFT)
		assert_object(agarre.manos().sostenido()).is_same(caja.get("datos"))
		assert_object(caja.get_parent()).is_same(padre)
		agarre.soltar(false)
		_agarrar(almacen, bolsa)
		_clic(jugador, destino, MOUSE_BUTTON_RIGHT)
		assert_bool(tapa.call("recibe_objetos")).is_false()
		_clic(jugador, destino, MOUSE_BUTTON_LEFT)
		assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
		tapa.call("_physics_process", 0.2)
		_clic(jugador, destino, MOUSE_BUTTON_LEFT)
		assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
		_clic(jugador, destino, MOUSE_BUTTON_RIGHT)
		tapa.call("_physics_process", 1.0)
		assert_bool(tapa.call("recibe_objetos")).is_true()
		assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
		agarre.soltar(false)
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_zero()


func test_el_lector_es_copia_y_la_noche_lo_vacia_sin_leer_papel_liberado() -> void:  # AC-CLN-038
	var almacen := await _abrir()
	var contenedor: Node3D = almacen.get_node(CUERPO)
	var papel := _ticket(almacen)
	var instancia := papel.get_instance_id()
	_agarrar(almacen, papel)
	_clic(almacen.get("_jugador"), contenedor, MOUSE_BUTTON_LEFT)
	var copia: Array[Node3D] = contenedor.call("tirados")
	assert_array(copia).contains_exactly([papel])
	copia.clear()
	assert_array(contenedor.call("tirados")).has_size(1)
	almacen.call("_al_abrir_la_jornada", 2)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(is_instance_id_valid(instancia)).is_false()
	assert_array(contenedor.call("tirados")).is_empty()
	assert_object(almacen.get("_agarre").manos().sostenido()).is_null()


func test_los_persistentes_vuelven_y_el_util_simula_fisica_otra_vez() -> void:  # AC-CLN-038
	var almacen := await _abrir()
	var contenedor: Node3D = almacen.get_node(CUERPO)
	var objetos: Array[ObjetoAgarrable] = []
	var padres: Array[Node] = []
	var poses: Array[Transform3D] = []
	var capas: Array[int] = []
	var mascaras: Array[int] = []
	for nombre: String in ["Mopa", "Balde", "BolsaDeBasura1"]:
		var objeto: ObjetoAgarrable = almacen.get_node("Objetos/" + nombre)
		objetos.append(objeto)
		padres.append(objeto.get_parent())
		poses.append(objeto.lugar_de_origen())
		capas.append(objeto.collision_layer)
		mascaras.append(objeto.collision_mask)
	var piso: PisoDelLocal = almacen.get("_limpiador").piso()
	piso.balde().llenar()
	piso.balde().tenir(ReglasDeLaLimpieza.Agua.AZUL)
	piso.mopa().mojar_en(piso.balde())
	assert_bool(piso.mopa().esta_mojada()).is_true()
	for objeto in objetos:
		_agarrar(almacen, objeto)
		_clic(almacen.get("_jugador"), contenedor, MOUSE_BUTTON_LEFT)
	almacen.call("_al_abrir_la_jornada", 2)
	for indice in objetos.size():
		var objeto := objetos[indice]
		assert_object(objeto.get_parent()).is_same(padres[indice])
		assert_bool(objeto.global_transform.is_equal_approx(poses[indice])).is_true()
		assert_bool(objeto.visible).is_true()
		assert_bool(objeto.freeze).is_false()
		assert_int(objeto.collision_layer).is_equal(capas[indice])
		assert_int(objeto.collision_mask).is_equal(mascaras[indice])
	var nuevo: PisoDelLocal = almacen.get("_limpiador").piso()
	assert_bool(nuevo.mopa().esta_mojada()).is_false()
	assert_bool(nuevo.balde().tiene_agua()).is_false()
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_zero()
	var balde := objetos[1]
	balde.global_position += Vector3.UP * 0.5
	balde.sleeping = false
	var alto := balde.global_position.y
	for cuadro in 20:
		await get_tree().physics_frame
	assert_float(balde.global_position.y).is_less(alto - 0.1)
	for cuadro in 80:
		await get_tree().physics_frame
	assert_float(balde.global_position.y).is_greater(poses[1].origin.y - 0.1)
	_agarrar(almacen, balde)
	assert_object(almacen.get("_agarre").manos().sostenido()).is_same(balde.datos)


func test_examen_y_cierre_bloquean_ambos_clics() -> void:  # AC-CLN-039
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	var bolsa: ObjetoAgarrable = almacen.get_node("Objetos/BolsaDeBasura1")
	_agarrar(almacen, bolsa)
	var examen: Examen = jugador.get("examen")
	examen.alternar(bolsa.datos)
	assert_bool(examen.esta_examinando()).is_true()
	for ruta: String in [CUERPO, TAPA]:
		_clic(jugador, almacen.get_node(ruta), MOUSE_BUTTON_LEFT)
		_clic(jugador, almacen.get_node(ruta), MOUSE_BUTTON_RIGHT)
		assert_object(almacen.get("_agarre").manos().sostenido()).is_same(bolsa.datos)
		assert_bool(almacen.get_node(TAPA).call("recibe_objetos")).is_true()
	examen.terminar()
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.call("_process", Reglas.DURACION_DEL_TURNO + 1.0)
	for ruta: String in [CUERPO, TAPA]:
		_clic(jugador, almacen.get_node(ruta), MOUSE_BUTTON_LEFT)
		_clic(jugador, almacen.get_node(ruta), MOUSE_BUTTON_RIGHT)
		assert_object(almacen.get("_agarre").manos().sostenido()).is_same(bolsa.datos)
		assert_bool(almacen.get_node(TAPA).call("recibe_objetos")).is_true()
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_zero()


func test_la_pausa_no_entrega_eventos_y_reanudar_recupera_el_tiro() -> void:  # AC-CLN-039
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	var bolsa: ObjetoAgarrable = almacen.get_node("Objetos/BolsaDeBasura1")
	_agarrar(almacen, bolsa)
	jugador.set("_enfocado", almacen.get_node(CUERPO))
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	pausa.pausar()
	assert_bool(get_tree().paused).is_true()
	for boton: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var evento := InputEventMouseButton.new()
		evento.button_index = boton
		evento.pressed = true
		Input.parse_input_event(evento)
		Input.flush_buffered_events()
		var liberacion := InputEventMouseButton.new()
		liberacion.button_index = boton
		liberacion.pressed = false
		Input.parse_input_event(liberacion)
		Input.flush_buffered_events()
	assert_object(almacen.get("_agarre").manos().sostenido()).is_same(bolsa.datos)
	assert_bool(almacen.get_node(TAPA).call("recibe_objetos")).is_true()
	pausa.reanudar()
	_clic(jugador, almacen.get_node(CUERPO), MOUSE_BUTTON_LEFT)
	assert_object(almacen.get("_agarre").manos().sostenido()).is_null()
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_equal(1)
