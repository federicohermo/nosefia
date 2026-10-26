## El gesto real entrega, conserva los rechazos y restaura lo persistente al abrir otra noche.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const BolsaEnLaMano := preload("res://test/escenas/bolsa_en_la_mano.gd")
const CUERPO := (
	"Estructura/deposito_contenedor_grande_soporte/"
	+ "deposito_contenedor_grande_cuerpo/StaticBody3D"
)
const BASE := "Estructura/deposito_contenedor_grande_soporte/"
const TAPA := BASE + "deposito_contenedor_bisagra_izquierda/CuerpoDeLaTapa"

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
	_almacen.set(
		"_partida", Partida.desde({"jornada": AnomaliasDeLaJornada.JORNADA_SIN_AZUL, "medios": 0})
	)
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
	if ReglasDeLaBasura.ids_de_las_bolsas().has(datos.id):
		var numero := ReglasDeLaBasura.ids_de_las_bolsas().find(datos.id)
		if almacen.get("_recolector").tarea().tiene_bolsa(numero):
			assert_object(BolsaEnLaMano.sacar(almacen, numero)).is_same(objeto)
	if agarre.cuerpo_sostenido() != objeto:
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
	objetos.append(almacen.get_node("Objetos/BolsaDeBasura1"))
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
		_comprobar_tirado(objeto, contenedor, jugador, agarre)
	assert_int(recolector.tarea().depositadas()).is_equal(1)
	assert_array(contenedor.call("tirados")).has_size(objetos.size())


func _comprobar_tirado(
	objeto: ObjetoAgarrable, contenedor: Node3D, jugador: Node3D, agarre: Agarre
) -> void:
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(objeto.visible).is_false()
	assert_bool(objeto.freeze).is_true()
	assert_int(objeto.collision_layer).is_zero()
	assert_int(objeto.collision_mask).is_zero()
	assert_object(objeto.get_parent()).is_same(contenedor)
	var candidato: CampoDeInteraccion.Candidato = jugador.call("_medir_candidato", objeto)
	assert_bool(candidato.visible).is_false()


func test_cuerpo_rechaza_durante_giro_y_tapa_no_tira() -> void:  # AC-CLN-037 AC-CLN-035
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var tapa: Node3D = almacen.get_node(TAPA)
	var cuerpo: Node3D = almacen.get_node(CUERPO)
	var bolsa: ObjetoAgarrable = almacen.get_node("Objetos/BolsaDeBasura1")
	var caja: RigidBody3D = almacen.get_node("Objetos/CajaDeActroncito")
	_clic(jugador, cuerpo, MOUSE_BUTTON_LEFT)
	assert_object(agarre.manos().sostenido()).is_null()
	_agarrar(almacen, caja)
	var padre := caja.get_parent()
	_clic(jugador, cuerpo, MOUSE_BUTTON_LEFT)
	assert_object(agarre.manos().sostenido()).is_same(caja.get("datos"))
	assert_object(caja.get_parent()).is_same(padre)
	agarre.soltar(false)
	_agarrar(almacen, bolsa)
	for destino: Node3D in [cuerpo, tapa]:
		_clic(jugador, destino, MOUSE_BUTTON_RIGHT)
		assert_bool(tapa.call("recibe_objetos")).is_true()
		assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	_clic(jugador, tapa, MOUSE_BUTTON_LEFT)
	assert_bool(tapa.call("recibe_objetos")).is_false()
	_clic(jugador, cuerpo, MOUSE_BUTTON_LEFT)
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	tapa.call("_physics_process", 0.2)
	_clic(jugador, cuerpo, MOUSE_BUTTON_LEFT)
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	_clic(jugador, tapa, MOUSE_BUTTON_LEFT)
	tapa.call("_physics_process", 1.0)
	assert_bool(tapa.call("recibe_objetos")).is_true()
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
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
	almacen.call("_al_abrir_la_jornada", AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(is_instance_id_valid(instancia)).is_false()
	assert_array(contenedor.call("tirados")).is_empty()
	assert_object(almacen.get("_agarre").manos().sostenido()).is_null()


func test_la_bolsa_tirada_no_esta_en_el_mundo_la_noche_siguiente() -> void:  # AC-CLN-038
	var almacen := await _abrir()
	var bolsa: ObjetoAgarrable = almacen.get_node("Objetos/BolsaDeBasura1")
	_agarrar(almacen, bolsa)
	_clic(almacen.get("_jugador"), almacen.get_node(CUERPO), MOUSE_BUTTON_LEFT)
	almacen.call("_al_abrir_la_jornada", AnomaliasDeLaJornada.JORNADA_SIN_AZUL + 1)
	assert_bool(bolsa.visible).is_false()
	assert_bool(bolsa.freeze).is_true()
	assert_bool(bolsa.get_node("Forma").disabled).is_true()
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_zero()


func test_los_utiles_no_entran_con_la_tapa_abierta_ni_cerrada() -> void:  # AC-CLN-076
	var almacen := await _abrir()
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var contenedor: Node3D = almacen.get_node(CUERPO)
	var tapa: Node3D = almacen.get_node(TAPA)
	var piso: PisoDelLocal = almacen.get("_limpiador").piso()
	piso.balde().llenar()
	piso.balde().tenir(ReglasDeLaLimpieza.Agua.AZUL)
	piso.mopa().mojar_en(piso.balde())
	var utiles: Array[ObjetoAgarrable] = []
	for nombre: String in ["Mopa", "Balde", "JabonAzul", "JabonRosa", "JabonAmarillo"]:
		utiles.append(almacen.get_node("Objetos/" + nombre))
	for cerrada: bool in [false, true]:
		if cerrada:
			_clic(jugador, tapa, MOUSE_BUTTON_LEFT)
			tapa.call("_physics_process", 1.0)
		assert_bool(tapa.call("recibe_objetos")).is_equal(not cerrada)
		for util in utiles:
			_agarrar(almacen, util)
			_clic(jugador, contenedor, MOUSE_BUTTON_LEFT)
			assert_object(agarre.manos().sostenido()).is_same(util.datos)
			assert_bool(util.visible).is_true()
			agarre.soltar(false)
			util.volver_a_su_lugar()
	assert_array(contenedor.call("tirados")).is_empty()
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_zero()


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
	reloj.call("avanzar", Reglas.DURACION_DEL_TURNO + 1.0)
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
