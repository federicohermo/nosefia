extends GdUnitTestSuite


func _raiz() -> Control:
	var raiz: VBoxContainer = auto_free(VBoxContainer.new())
	for _boton: int in 2:
		raiz.add_child(Button.new())
	add_child(raiz)
	return raiz


## Un gesto entra por el viewport y se suelta: el motor entrega siempre la pareja.
func _cruceta_hacia_abajo() -> void:
	var evento := InputEventJoypadButton.new()
	evento.button_index = JOY_BUTTON_DPAD_DOWN
	evento.pressed = true
	Input.parse_input_event(evento)
	Input.flush_buffered_events()
	var soltado := evento.duplicate() as InputEventJoypadButton
	soltado.pressed = false
	Input.parse_input_event(soltado)
	Input.flush_buffered_events()


func test_el_foco_que_da_al_abrir_queda_puesto_y_no_se_dibuja() -> void:  # AC-CFG-028
	var raiz := _raiz()
	var primero := FocoDeLaInterfaz.en_el_primero(raiz)
	assert_object(primero).is_same(raiz.get_child(0))
	assert_object(get_viewport().gui_get_focus_owner()).is_same(primero)
	assert_bool(primero.has_focus()).is_true()
	assert_bool(primero.has_focus(true)).is_false()


func test_navegar_con_la_cruceta_dibuja_el_foco() -> void:
	var raiz := _raiz()
	FocoDeLaInterfaz.en_el_primero(raiz)
	await await_idle_frame()
	_cruceta_hacia_abajo()
	await await_idle_frame()
	var foco := get_viewport().gui_get_focus_owner()
	assert_object(foco).is_not_null()
	assert_bool(foco != null and raiz.is_ancestor_of(foco) and foco.has_focus(true)).is_true()


func test_repintar_la_interfaz_no_vuelve_a_ocultar_el_foco_que_el_jugador_ya_ve() -> void:
	var raiz := _raiz()
	FocoDeLaInterfaz.en_el_primero(raiz)
	await await_idle_frame()
	_cruceta_hacia_abajo()
	await await_idle_frame()
	var foco := FocoDeLaInterfaz.en_el_primero(raiz)
	assert_object(foco).is_same(get_viewport().gui_get_focus_owner())
	assert_bool(foco != null and foco.has_focus(true)).is_true()
