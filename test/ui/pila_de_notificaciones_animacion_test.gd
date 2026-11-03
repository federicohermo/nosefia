extends GdUnitTestSuite

const ESCENA := "res://src/ui/pila_de_notificaciones.tscn"
const ANCHO := 1920

var _viewport: SubViewport


func before_test() -> void:
	_viewport = auto_free(SubViewport.new())
	_viewport.size = Vector2i(ANCHO, 1080)
	add_child(_viewport)


func after_test() -> void:
	get_tree().paused = false


func _pila(con_proceso := false) -> PilaDeNotificaciones:
	var pila: PilaDeNotificaciones = load(ESCENA).instantiate()
	_viewport.add_child(pila)
	pila.set_process(con_proceso)
	return pila


func _carteles(pila: PilaDeNotificaciones) -> Array[Node]:
	return pila.get_node("Marco/Pila").get_children()


func _fantasmas(pila: PilaDeNotificaciones) -> Array[Node]:
	return pila.get_node("Marco").get_children().filter(
		func(nodo: Node) -> bool: return nodo.name != &"Pila"
	)


func _cuadros() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _izquierda(cartel: Control) -> float:
	return cartel.get_global_rect().position.x


func test_un_cartel_nuevo_entra_desde_fuera_del_margen_derecho_con_ease_out() -> void:
	var pila := _pila()
	pila.avisar_pista()
	await _cuadros()
	var cartel: Control = _carteles(pila)[0]
	var inicio := _izquierda(cartel)
	assert_float(inicio).is_greater_equal(float(ANCHO) - 0.1)
	pila._process(PilaDeNotificaciones.DURACION_DE_ENTRADA / 2.0)
	await _cuadros()
	var a_mitad := _izquierda(cartel)
	pila._process(PilaDeNotificaciones.DURACION_DE_ENTRADA)
	await _cuadros()
	var reposo := _izquierda(cartel)
	assert_float(cartel.get_global_rect().end.x).is_less_equal(float(ANCHO))
	assert_float(a_mitad).is_less(inicio)
	assert_float(a_mitad).is_greater(reposo)
	assert_float(inicio - a_mitad).is_greater((inicio - reposo) / 2.0)


func test_un_cartel_vencido_sale_a_la_derecha_con_ease_in_y_despues_se_libera() -> void:
	var pila := _pila()
	pila.avisar_pista()
	pila._process(1.0)
	await _cuadros()
	var cartel: Control = _carteles(pila)[0]
	var reposo := _izquierda(cartel)
	pila._process(Notificaciones.DURACION - 1.0)
	assert_array(_carteles(pila)).is_empty()
	assert_array(_fantasmas(pila)).has_size(1)
	assert_object(_fantasmas(pila)[0]).is_same(cartel)
	assert_float(_izquierda(cartel)).is_equal_approx(reposo, 0.5)
	pila._process(PilaDeNotificaciones.DURACION_DE_SALIDA / 2.0)
	var a_mitad := _izquierda(cartel)
	assert_float(a_mitad).is_greater(reposo)
	assert_float(a_mitad - reposo).is_less((float(ANCHO) - reposo) / 2.0)
	pila._process(PilaDeNotificaciones.DURACION_DE_SALIDA)
	assert_bool(is_instance_valid(cartel)).is_false()
	assert_array(_fantasmas(pila)).is_empty()


func test_un_cartel_que_vence_a_mitad_de_entrada_sale_desde_donde_esta() -> void:
	var pila := _pila()
	pila.avisar_pista()
	await _cuadros()
	pila._process(PilaDeNotificaciones.DURACION_DE_ENTRADA / 4.0)
	await _cuadros()
	var cartel: Control = _carteles(pila)[0]
	var antes := _izquierda(cartel)
	assert_float(antes).is_less(float(ANCHO))
	pila.vaciar()
	assert_float(_izquierda(cartel)).is_equal_approx(antes, 0.5)
	pila._process(PilaDeNotificaciones.DURACION_DE_SALIDA / 2.0)
	assert_float(_izquierda(cartel)).is_greater(antes)


func test_los_carteles_que_siguen_no_se_recrean_ni_saltan() -> void:
	var pila := _pila()
	pila.avisar_pista()
	pila._process(1.0)
	await _cuadros()
	var pista: Control = _carteles(pila)[0]
	var arriba := pista.get_global_rect().position.y
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	await _cuadros()
	assert_object(_carteles(pila)[1]).is_same(pista)
	assert_float(pista.get_global_rect().position.y).is_equal_approx(arriba, 0.5)
	pila._process(1.0)
	await _cuadros()
	assert_object(_carteles(pila)[1]).is_same(pista)
	assert_float(pista.get_global_rect().position.y).is_greater(arriba + 1.0)


func test_dos_avisos_del_mismo_cuadro_entran_sin_pisarse() -> void:
	var pila := _pila()
	pila.avisar_pista()
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	await _cuadros()
	pila._process(PilaDeNotificaciones.DURACION_DE_ENTRADA / 2.0)
	await _cuadros()
	var carteles := _carteles(pila)
	assert_int(carteles.size()).is_equal(2)
	(
		assert_bool(
			(carteles[0] as Control).get_global_rect().intersects(
				(carteles[1] as Control).get_global_rect()
			)
		)
		. is_false()
	)
	pila._process(1.0)
	await _cuadros()
	for cartel: Control in carteles:
		assert_float(cartel.get_global_rect().end.x).is_less_equal(float(ANCHO))


func test_la_animacion_no_cambia_la_duracion_del_aviso() -> void:
	var pila := _pila()
	pila.avisar_pista()
	pila._process(0.1)
	pila._process(Notificaciones.DURACION - 0.2)
	assert_array(_carteles(pila)).has_size(1)
	pila._process(0.1)
	assert_array(_carteles(pila)).is_empty()


func test_con_la_pausa_abierta_la_animacion_se_congela() -> void:
	var pila := _pila(true)
	pila.avisar_pista()
	await _cuadros()
	get_tree().paused = true
	await _cuadros()
	var cartel: Control = _carteles(pila)[0]
	var congelado := _izquierda(cartel)
	assert_bool(pila.can_process()).is_false()
	await get_tree().create_timer(PilaDeNotificaciones.DURACION_DE_ENTRADA + 0.2).timeout
	assert_float(_izquierda(cartel)).is_equal(congelado)
	get_tree().paused = false
	await get_tree().create_timer(PilaDeNotificaciones.DURACION_DE_ENTRADA + 0.3).timeout
	assert_float(_izquierda(cartel)).is_less(congelado)
