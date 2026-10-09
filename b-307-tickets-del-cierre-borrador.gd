## Los tickets conservan su identidad y cada destino anota sólo su consecuencia.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const CIERRE := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const Habitaciones := preload("res://src/escenas/puestos/habitaciones_del_almacen.gd")

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
	add_child(_almacen)
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


func _centro(partes: Array[AABB]) -> Vector3:
	var lector: Habitaciones = _almacen.get("_habitaciones")
	return lector.to_global(partes[0].get_center())


func _afuera() -> Vector3:
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var punto := _centro(lector.local) + Vector3.UP * lector.local[0].size.y
	assert_int(lector.de(punto)).is_equal(CIERRE.Habitacion.AFUERA)
	return punto


func _foto() -> Array[CIERRE.Estado]:
	return _almacen.call("_estados_del_cierre")


func _inodoro(papel: ObjetoAgarrable) -> void:
	var agarre: Agarre = _almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
	var objetivo: Node3D = _almacen.get_node("Estructura/inodoro/StaticBody3D")
	assert_str(String(objetivo.call("destino_del_uso"))).is_equal(
		String(ReglasDeLaLimpieza.ID_DEL_INODORO)
	)
	_almacen.get("_jugador").uso_pedido.emit(objetivo)
	assert_object(agarre.cuerpo_sostenido()).is_null()
	assert_bool(papel.is_queued_for_deletion()).is_true()


func _cerrar(impecable: bool) -> void:
	var partida: Partida = _almacen.get("_partida")
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	if impecable:
		for tarea: Tarea in partida.obligatorias():
			reloj.completar(tarea)
		for tarea: Tarea in partida.obligatorias():
			assert_bool(tarea.completada()).is_true()
	reloj.call("_process", Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL)
	assert_bool(reloj.corriendo()).is_false()


func test_un_ticket_y_dos_en_otra_noche_suman_un_medio_cada_vez() -> void:  # AC-CLN-047
	_abrir()
	var partida: Partida = _almacen.get("_partida")
	for cantidad: int in [1, 2]:
		for _indice: int in cantidad:
			var papel := _imprimir()
			assert_object(papel).is_not_null()
			_inodoro(papel)
			await get_tree().process_frame
			assert_bool(is_instance_valid(papel)).is_false()
		assert_array(_almacen.get("_puesto_de_la_caja").tickets_en_el_mundo()).is_empty()
		_cerrar(true)
		assert_int(partida.medios()).is_equal(cantidad)
		if cantidad == 1:
			_almacen.call("_seguir")


func test_balde_y_mopa_en_el_inodoro_no_anotan_papel() -> void:  # AC-CLN-047
	_abrir()
	var limpiador: Limpiador = _almacen.get("_limpiador")
	limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	assert_bool(limpiador.piso().balde().tiene_agua()).is_true()
	limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_INODORO)
	assert_bool(limpiador.piso().balde().tiene_agua()).is_false()
	limpiador.usar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, ReglasDeLaLimpieza.ID_DEL_INODORO)
	assert_int(limpiador.piso().mopa().agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)
	_cerrar(true)
	assert_int((_almacen.get("_partida") as Partida).medios()).is_zero()


func test_interiores_no_desordenan_y_varios_papeles_afuera_cuentan_uno() -> void:  # AC-CLN-048
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var uno := _imprimir()
	var otro := _imprimir()
	assert_object(uno).is_not_null()
	assert_object(otro).is_not_null()
	uno.freeze = true
	for partes: Array[AABB] in [lector.local, lector.deposito, lector.bano]:
		uno.global_position = _centro(partes)
		otro.global_position = _centro(partes)
		assert_bool(CIERRE.hay_desorden(_foto())).is_false()
		assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_false()
	uno.global_position = _afuera()
	otro.global_position = _afuera() + Vector3.RIGHT * 0.1
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_true()
	uno.global_position = _centro(lector.local)
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_true()
	otro.global_position = _centro(lector.deposito)
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_false()
	uno.global_position = _afuera()
	otro.global_position = _afuera()
	_cerrar(true)
	assert_int((_almacen.get("_partida") as Partida).medios()).is_equal(1)


func test_la_mano_excluye_su_cuerpo_y_el_examen_real_cuenta_su_posicion() -> void:  # AC-CLN-048
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var agarre: Agarre = _almacen.get("_agarre")
	var examen: Examen = _almacen.get("_jugador").examen
	var uno := _imprimir()
	var otro := _imprimir()
	assert_object(uno).is_not_null()
	assert_object(otro).is_not_null()
	otro.datos = uno.datos
	assert_bool(agarre.pedir_agarrar(uno.datos, uno)).is_true()
	assert_object(agarre.cuerpo_sostenido()).is_same(uno)
	otro.global_position = _afuera()
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_true()
	otro.global_position = _centro(lector.local)
	uno.global_position = _afuera()
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_false()
	assert_bool(examen.iniciar()).is_true()
	uno.global_position = _afuera()
	assert_object(agarre.cuerpo_sostenido()).is_same(uno)
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_true()
	examen.terminar()
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_false()
	_cerrar(true)
	assert_int((_almacen.get("_partida") as Partida).medios()).is_zero()


func test_el_contenedor_conserva_el_ticket_pero_lo_excluye_del_cierre() -> void:  # AC-CLN-048
	_abrir()
	var papel := _imprimir()
	assert_object(papel).is_not_null()
	var agarre: Agarre = _almacen.get("_agarre")
	var contenedor: Node3D = _almacen.get("_contenedor")
	assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
	assert_bool(contenedor.get("tapa").recibe_objetos()).is_true()
	contenedor.call("interactuar")
	assert_bool(is_instance_valid(papel)).is_true()
	assert_bool(papel.visible).is_false()
	assert_array(contenedor.call("tirados")).contains_exactly([papel])
	assert_array(_almacen.get("_puesto_de_la_caja").tickets_en_el_mundo()).contains_exactly([papel])
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_false()
	_cerrar(true)
	assert_int((_almacen.get("_partida") as Partida).medios()).is_zero()
	_almacen.call("_seguir")
	assert_array(contenedor.call("tirados")).is_empty()
	assert_array(_almacen.get("_puesto_de_la_caja").tickets_en_el_mundo()).is_empty()
	await get_tree().process_frame
	assert_bool(is_instance_valid(papel)).is_false()


func test_tres_motivos_con_grave_son_siete_y_la_noche_nueva_conserva_deuda() -> void:  # AC-CLN-049
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var partida: Partida = _almacen.get("_partida")
	var papel := _imprimir()
	assert_object(papel).is_not_null()
	_inodoro(papel)
	await get_tree().process_frame
	assert_bool(is_instance_valid(papel)).is_false()
	var caja: Node3D = _almacen.get("_cajas_de_productos")[0]
	caja.global_position = _centro(lector.local)
	_almacen.get("_reposicion_manual").call("retirar", Producto.Id.ACTRONCITO)
	var unidad: Node3D = _almacen.get("_agarre").soltar(true)
	assert_object(unidad).is_not_null()
	unidad.global_position = _afuera()
	_cerrar(false)
	assert_int(partida.medios()).is_equal(7)
	assert_bool(partida.terminada()).is_false()
	assert_int(Partida.desde(Guardado.new().cargar()).medios()).is_equal(7)
	_almacen.call("_seguir")
	assert_bool(CIERRE.hay_desorden(_foto())).is_false()
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_false()
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
	_almacen.call("_seguir")
	_cerrar(true)
	assert_int(partida.medios()).is_zero()
