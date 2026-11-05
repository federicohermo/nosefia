## Cada suceso del almacén desbloquea su logro, lo avisa y lo escribe al disco. Cuándo se gana cada
## uno lo prueba `logros_test`; acá, que el almacén lo cablee.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const L := Logros.Logro
const M := Reglas.MEDIOS_POR_APERCIBIMIENTO
const ULTIMA_DE_LA_PRUEBA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA - 1

var _almacen: Node3D


func after_test() -> void:
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null


func _abrir(partida: Partida = null) -> void:
	_almacen = ALMACEN.instantiate()
	if partida != null:
		_almacen.set("_partida", partida)
	_almacen.set("compradores_de_la_apertura", func(_n: int) -> Array[Comprador]: return [])
	add_child(_almacen)
	var jugador: Node3D = _almacen.get("_jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)
	_pila().set_process(false)


func _pila() -> PilaDeNotificaciones:
	return _almacen.get_node("Interfaz/PilaDeNotificaciones")


func _en_el_disco() -> Logros:
	return ArchivoDeLogros.new().cargar()


func _logros() -> Logros:
	return _almacen.get("_logros")


func _visibles() -> Array[Notificaciones.Tipo]:
	return _pila().get("_estado").visibles()


func _avisos_de_logro() -> int:
	return _visibles().count(Notificaciones.Tipo.LOGRO)


func _unidad() -> ObjetoAgarrable:
	_almacen.get("_reposicion_manual").call("retirar", Producto.Id.ACTRONCITO)
	var agarre: Agarre = _almacen.get("_agarre")
	return agarre.cuerpo_sostenido() as ObjetoAgarrable


func _ticket() -> ObjetoAgarrable:
	var puesto: Node3D = _almacen.get("_puesto_de_la_caja")
	var anteriores: Array[Node3D] = puesto.call("tickets_en_el_mundo")
	var productos: Array[Producto] = [Catalogo.de(Producto.Id.MAROLINI)]
	(_almacen.get("_caja") as CajaRegistradora).ticket_impreso.emit(Ticket.new(productos))
	for papel: Node3D in puesto.call("tickets_en_el_mundo"):
		if not anteriores.has(papel):
			return papel as ObjetoAgarrable
	return null


func _cerrar() -> void:
	RelojDePrueba.avanzar_turno(_almacen.get("_reloj"), Reglas.DURACION_DEL_TURNO)


func test_un_ticket_al_inodoro_gana_rebelde_una_sola_vez() -> void:  # AC-ACH-003, AC-ACH-002
	_abrir()
	var caja: CajaRegistradora = _almacen.get("_caja")
	assert_bool(_logros().desbloqueado(L.REBELDE)).is_false()
	caja.ticket_desechado.emit()
	assert_bool(_logros().desbloqueado(L.REBELDE)).is_true()
	assert_bool(_en_el_disco().desbloqueado(L.REBELDE)).is_true()
	assert_int(_avisos_de_logro()).is_equal(1)
	caja.ticket_desechado.emit()
	assert_int(_avisos_de_logro()).is_equal(1)
	assert_bool(_logros().desbloqueado(L.A_LA_BASURA)).is_false()


func test_un_ticket_al_contenedor_no_gana_y_una_unidad_gana_a_la_basura() -> void:  # AC-ACH-003
	_abrir()
	var recolector: RecolectorDeBasura = _almacen.get("_recolector")
	recolector.objeto_tirado.emit(_ticket())
	assert_bool(_logros().desbloqueado(L.A_LA_BASURA)).is_false()
	assert_bool(_logros().desbloqueado(L.REBELDE)).is_false()
	recolector.objeto_tirado.emit(_unidad())
	assert_bool(_logros().desbloqueado(L.A_LA_BASURA)).is_true()
	assert_bool(_en_el_disco().desbloqueado(L.A_LA_BASURA)).is_true()


func test_la_planilla_en_el_tope_gana_estamos_al_pedo_y_no_avisa_dos_veces() -> void:  # AC-ACH-005
	_abrir()
	var computadora: ComputadoraDeEscritorio = _almacen.get("_computadora")
	var producto := computadora.registro().productos()[0]
	for _i in RegistroDeVentas.TOPE_POR_FILA - 1:
		computadora.pedir_sumar(producto)
	assert_bool(_logros().desbloqueado(L.ESTAMOS_AL_PEDO)).is_false()
	computadora.pedir_sumar(producto)
	assert_bool(_logros().desbloqueado(L.ESTAMOS_AL_PEDO)).is_true()
	assert_int(_avisos_de_logro()).is_equal(1)
	computadora.pedir_restar(producto)
	computadora.pedir_sumar(producto)
	assert_int(_avisos_de_logro()).is_equal(1)


func test_lo_soltado_que_queda_afuera_gana_y_se_marcho_al_instante() -> void:  # AC-ACH-004
	_abrir()
	var afuera: RigidBody3D = _almacen.get("_cajas_de_productos")[Producto.Id.MARRANOS]
	afuera.global_position = Vector3.ONE * 100.0
	afuera.freeze = true
	assert_int(_almacen.get("_habitaciones").de(afuera.global_position)).is_equal(
		ReglasDelCierre.Habitacion.AFUERA
	)
	_almacen.call("_vigilar_si_queda_afuera", afuera)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_almacen.get("_reloj").corriendo()).is_true()
	assert_bool(_logros().desbloqueado(L.Y_SE_MARCHO)).is_true()
	assert_bool(_en_el_disco().desbloqueado(L.Y_SE_MARCHO)).is_true()


func test_lo_entregado_a_un_comprador_no_gana_y_se_marcho() -> void:  # AC-ACH-004
	_abrir()
	var entregado: RigidBody3D = _almacen.get("_cajas_de_productos")[Producto.Id.MARRANOS]
	entregado.global_position = Vector3.ONE * 100.0
	entregado.freeze = true
	entregado.set_meta(&"recibido_por_comprador", true)
	_almacen.call("_vigilar_si_queda_afuera", entregado)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_logros().desbloqueado(L.Y_SE_MARCHO)).is_false()


func test_un_ticket_que_queda_afuera_no_gana_y_se_marcho() -> void:  # AC-ACH-004
	_abrir()
	var papel := _ticket()
	papel.global_position = Vector3.ONE * 100.0
	papel.freeze = true
	_almacen.call("_vigilar_si_queda_afuera", papel)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_logros().desbloqueado(L.Y_SE_MARCHO)).is_false()


func test_una_pista_aceptada_queda_descubierta_en_el_archivo() -> void:  # AC-ACH-011
	_abrir()
	var pista: Pista = CasoDeInvestigacion.de_la_partida().pistas[0]
	var investigador: Investigador = _almacen.get("_investigador")
	investigador.pista_nueva.emit(pista)
	assert_bool(_logros().pista_descubierta(pista.identidad)).is_true()
	assert_bool(_en_el_disco().pista_descubierta(pista.identidad)).is_true()


func test_el_contrato_sin_medios_gana_ejemplar_y_anota_el_final() -> void:  # AC-ACH-006, AC-ACH-011
	_abrir(Partida.desde({"jornada": ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA, "medios": 0}))
	for tarea: Tarea in (_almacen.get("_partida") as Partida).obligatorias():
		(_almacen.get("_reloj") as RelojDelTurno).completar(tarea)
	_cerrar()
	assert_bool(_logros().desbloqueado(L.EMPLEADO_EJEMPLAR)).is_true()
	assert_bool(_en_el_disco().final_alcanzado(Partida.Final.CONTRATO_CUMPLIDO)).is_true()
	assert_bool(_en_el_disco().final_alcanzado(Partida.Final.DESPEDIDO)).is_false()
	assert_int(_avisos_de_logro()).is_equal(1)


func test_un_despido_de_la_prueba_gana_pesima_primera_impresion() -> void:  # AC-ACH-007, AC-ACH-011
	var apercibimientos := Reglas.APERCIBIMIENTOS_QUE_PIERDEN_LA_PRUEBA
	_abrir(Partida.desde({"jornada": ULTIMA_DE_LA_PRUEBA, "medios": apercibimientos * M}))
	_cerrar()
	assert_int((_almacen.get("_partida") as Partida).final()).is_equal(Partida.Final.DESPEDIDO)
	assert_bool(_logros().desbloqueado(L.PESIMA_PRIMERA_IMPRESION)).is_true()
	assert_bool(_logros().desbloqueado(L.EMPLEADO_EJEMPLAR)).is_false()
	assert_bool(_en_el_disco().final_alcanzado(Partida.Final.DESPEDIDO)).is_true()


func test_la_cuarta_falla_de_una_misma_tarea_gana_el_talon_de_aquiles() -> void:  # AC-ACH-008
	var partida := Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA})
	for _noche in Logros.FALLAS_DEL_TALON - 1:
		partida.antecedentes().anotar_noche([Tarea.Tipo.CAJA], [] as Array[Partida.Llamado], 0)
	_abrir(partida)
	assert_bool(_logros().desbloqueado(L.MI_TALON_DE_AQUILES)).is_false()
	_cerrar()
	assert_bool(_logros().desbloqueado(L.MI_TALON_DE_AQUILES)).is_true()
	assert_bool(_logros().desbloqueado(L.PESIMA_PRIMERA_IMPRESION)).is_false()


func test_ningun_suceso_entregado_gana_obelisco_ni_elemental() -> void:  # AC-ACH-009
	_abrir()
	(_almacen.get("_caja") as CajaRegistradora).ticket_desechado.emit()
	(_almacen.get("_recolector") as RecolectorDeBasura).objeto_tirado.emit(_unidad())
	var computadora: ComputadoraDeEscritorio = _almacen.get("_computadora")
	var producto := computadora.registro().productos()[0]
	for _i in RegistroDeVentas.TOPE_POR_FILA:
		computadora.pedir_sumar(producto)
	_cerrar()
	assert_bool(_logros().desbloqueado(L.OBELISCO_DE_CARTON)).is_false()
	assert_bool(_logros().desbloqueado(L.ELEMENTAL)).is_false()
	assert_bool(_en_el_disco().desbloqueado(L.OBELISCO_DE_CARTON)).is_false()
	assert_bool(_en_el_disco().desbloqueado(L.ELEMENTAL)).is_false()


func test_un_logro_del_cierre_se_avisa_despues_de_vaciar_la_noche() -> void:  # AC-NTF-046
	var apercibimientos := Reglas.APERCIBIMIENTOS_QUE_PIERDEN_LA_PRUEBA
	_abrir(Partida.desde({"jornada": ULTIMA_DE_LA_PRUEBA, "medios": apercibimientos * M}))
	_pila().avisar_pista()
	_cerrar()
	assert_array(_visibles()).is_equal([Notificaciones.Tipo.LOGRO])
