## Los tickets conservan su identidad y cada destino anota sólo su consecuencia.
extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Habitaciones := preload("res://src/escenas/puestos/habitaciones_del_almacen.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

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


func _abrir() -> void:
	_almacen = ALMACEN.instantiate()
	_almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	add_child(_almacen)
	# Conserva los cinco cierres del caso y aísla el ticket del reparto físico de compradores.
	_almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2)
	assert_bool((_almacen.get("_atenciones") as Ventanilla).tarea().fisica()).is_false()
	var jugador: Node3D = _almacen.get("_jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)


func _imprimir() -> ObjetoAgarrable:
	var anteriores: Array[Node] = _almacen.find_children("*", "RigidBody3D", true, false)
	var productos: Array[Producto] = [Catalogo.de(Producto.Id.MAROLINI)]
	(_almacen.get("_caja") as CajaRegistradora).ticket_impreso.emit(Ticket.new(productos))
	for nodo: Node in _almacen.find_children("*", "RigidBody3D", true, false):
		if not anteriores.has(nodo) and nodo is ObjetoAgarrable:
			var papel := nodo as ObjetoAgarrable
			if papel.datos is Ticket:
				return papel
	return null


func _tickets_de_la_foto() -> Array[ReglasDelCierre.Estado]:
	var tickets: Array[ReglasDelCierre.Estado] = []
	for estado: ReglasDelCierre.Estado in _almacen.call("_estados_del_cierre"):
		if estado.producto == Ticket.ID:
			tickets.append(estado)
	return tickets


func _centro(partes: Array[AABB]) -> Vector3:
	var lector: Habitaciones = _almacen.get("_habitaciones")
	return lector.to_global(partes[0].get_center())


func _afuera() -> Vector3:
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var punto := _centro(lector.local) + Vector3.UP * lector.local[0].size.y
	return punto


func _inodoro(papel: ObjetoAgarrable) -> void:
	var agarre: Agarre = _almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
	var objetivo: Node3D = _almacen.get_node("Estructura/inodoro/StaticBody3D")
	_almacen.get("_jugador").uso_pedido.emit(objetivo)
	assert_object(agarre.cuerpo_sostenido()).is_null()


func _cerrar(impecable: bool) -> void:
	var partida: Partida = _almacen.get("_partida")
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	if impecable:
		for tarea: Tarea in partida.obligatorias():
			reloj.completar(tarea)
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)


func _seguir() -> void:
	var pantalla: PantallaDeDevolucion = _almacen.get("_pantalla")
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	AvanceDeDevolucion.pasar_la_reflexion(pantalla)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	assert_bool(await AvanceDeDevolucion.esperar_la_noche_siguiente(_almacen)).is_true()
	AvanceDeDevolucion.leer_las_instrucciones(_almacen)
	_almacen.get_node("Interfaz/PersianaDeLaNoche").terminar()


func test_un_ticket_y_dos_en_otra_noche_suman_un_medio_cada_vez() -> void:  # AC-CLN-047
	_abrir()
	var partida: Partida = _almacen.get("_partida")
	for cantidad: int in [1, 2]:
		for _indice: int in cantidad:
			var papel := _imprimir()
			assert_object(papel).is_not_null()
			_inodoro(papel)
			await get_tree().process_frame
		_cerrar(true)
		assert_int(partida.medios()).is_equal(cantidad)
		if cantidad == 1:
			await _seguir()


func test_balde_y_mopa_en_el_inodoro_no_anotan_papel() -> void:  # AC-CLN-047
	_abrir()
	var limpiador: Limpiador = _almacen.get("_limpiador")
	limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_INODORO)
	limpiador.usar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, ReglasDeLaLimpieza.ID_DEL_INODORO)
	_cerrar(true)
	assert_int((_almacen.get("_partida") as Partida).medios()).is_zero()


func test_tickets_adentro_afuera_y_recuperados_no_suman_motivo_de_afuera() -> void:  # AC-CLN-048
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var partida: Partida = _almacen.get("_partida")
	for partes: Array[AABB] in [lector.local, lector.deposito, lector.bano]:
		var papel := _imprimir()
		assert_object(papel).is_not_null()
		papel.global_position = _centro(partes)
		_cerrar(true)
		assert_int(partida.medios()).is_zero()
		await _seguir()
	var uno := _imprimir()
	var otro := _imprimir()
	assert_object(uno).is_not_null()
	assert_object(otro).is_not_null()
	uno.global_position = _afuera()
	otro.global_position = _afuera() + Vector3.RIGHT * 0.1
	var afuera := _tickets_de_la_foto().filter(
		func(estado: ReglasDelCierre.Estado) -> bool:
			return estado.habitacion == ReglasDelCierre.Habitacion.AFUERA
	)
	assert_array(afuera).has_size(2)
	_cerrar(true)
	assert_int(partida.medios()).is_zero()
	await _seguir()
	var recuperado := _imprimir()
	assert_object(recuperado).is_not_null()
	recuperado.global_position = _afuera()
	recuperado.global_position = _centro(lector.local)
	_cerrar(true)
	assert_int(partida.medios()).is_zero()


func test_sostener_y_examinar_tickets_conserva_la_mano_y_no_anota_afuera() -> void:  # AC-CLN-048
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var agarre: Agarre = _almacen.get("_agarre")
	var examen: Examen = _almacen.get("_jugador").examen
	var partida: Partida = _almacen.get("_partida")
	for escenario: int in 4:
		var uno := _imprimir()
		var otro := _imprimir()
		assert_object(uno).is_not_null()
		assert_object(otro).is_not_null()
		otro.datos = uno.datos
		assert_bool(agarre.pedir_agarrar(uno.datos, uno)).is_true()
		uno.global_position = _afuera()
		otro.global_position = _afuera() if escenario == 1 else _centro(lector.local)
		if escenario >= 2:
			assert_bool(examen.iniciar()).is_true()
			uno.global_position = _afuera()
			if escenario == 3:
				examen.terminar()
		var en_mano := _tickets_de_la_foto().filter(
			func(estado: ReglasDelCierre.Estado) -> bool: return estado.en_mano
		)
		assert_array(en_mano).has_size([1, 1, 0, 1][escenario])
		_cerrar(true)
		assert_int(partida.medios()).is_zero()
		if escenario < 3:
			await _seguir()


func test_tirar_el_ticket_al_contenedor_no_agrega_un_llamado() -> void:  # AC-CLN-048
	_abrir()
	var papel := _imprimir()
	assert_object(papel).is_not_null()
	var puesto: Node3D = _almacen.get("_puesto_de_la_caja")
	var copia: Array[Node3D] = puesto.call("tickets_en_el_mundo")
	copia.clear()
	assert_array(puesto.call("tickets_en_el_mundo")).contains_exactly([papel])
	var agarre: Agarre = _almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
	_almacen.get("_contenedor").interactuar()
	_cerrar(true)
	assert_int((_almacen.get("_partida") as Partida).medios()).is_zero()
	await _seguir()
	assert_array(puesto.call("tickets_en_el_mundo")).is_empty()


func test_tres_motivos_con_grave_son_siete_y_la_noche_nueva_conserva_deuda() -> void:  # AC-CLN-049
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var partida: Partida = _almacen.get("_partida")
	var papel := _imprimir()
	assert_object(papel).is_not_null()
	_inodoro(papel)
	await get_tree().process_frame
	var caja: Node3D = _almacen.get("_cajas_de_productos")[0]
	caja.global_position = _centro(lector.bano)
	_almacen.get("_reposicion_manual").call("retirar", Producto.Id.ACTRONCITO)
	var unidad: Node3D = _almacen.get("_agarre").soltar(true)
	assert_object(unidad).is_not_null()
	unidad.global_position = _afuera()
	_cerrar(false)
	assert_int(partida.medios()).is_equal(7)
	assert_bool(partida.terminada()).is_false()
	assert_int(Partida.desde(Guardado.new().cargar()).medios()).is_equal(7)
	await _seguir()
	_cerrar(true)
	assert_int(partida.medios()).is_equal(7)
	assert_bool(partida.terminada()).is_false()


# AC-CLN-047, AC-CLN-049
func test_eventos_en_placa_no_contaminan_la_noche_siguiente_ni_repiten_cierre() -> void:
	_abrir()
	var partida: Partida = _almacen.get("_partida")
	var caja: CajaRegistradora = _almacen.get("_caja")
	_cerrar(true)
	caja.ticket_desechado.emit()
	partida.cerrar_la_jornada(0)
	assert_int(partida.medios()).is_zero()
	await _seguir()
	_cerrar(true)
	assert_int(partida.medios()).is_zero()
