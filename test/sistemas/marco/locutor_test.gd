extends GdUnitTestSuite

var _entradas: Array[String] = []
var _cierres: int = 0


func before_test() -> void:
	_entradas.clear()
	_cierres = 0


func test_abrir_publica_la_primera_y_cada_click_izquierdo_publica_una() -> void:
	var locutor := _locutor()
	assert_bool(locutor.abrir(_tres_entradas())).is_true()
	assert_array(_entradas).is_equal(["Primera"])
	assert_bool(locutor.puede_abandonar()).is_false()
	locutor.recibir(_click(MOUSE_BUTTON_LEFT, true))
	assert_array(_entradas).is_equal(["Primera", "Segunda"])
	locutor.recibir(_click(MOUSE_BUTTON_LEFT, true))
	assert_array(_entradas).is_equal(["Primera", "Segunda", "Tercera"])
	assert_bool(locutor.puede_abandonar()).is_false()
	locutor.recibir(_click(MOUSE_BUTTON_LEFT, true))
	assert_int(_cierres).is_equal(1)
	assert_bool(locutor.puede_abandonar()).is_true()
	locutor.recibir(_click(MOUSE_BUTTON_LEFT, true))
	assert_int(_cierres).is_equal(1)


func test_abrir_otro_dialogo_rechaza_sin_emitir_ni_reemplazar() -> void:
	var locutor := _locutor()
	locutor.abrir(_tres_entradas())
	assert_bool(locutor.abrir(Dialogo.recordatorio("Otra entrada."))).is_false()
	assert_array(_entradas).is_equal(["Primera"])
	locutor.recibir(_click(MOUSE_BUTTON_LEFT, true))
	assert_array(_entradas).is_equal(["Primera", "Segunda"])


func test_derecho_soltado_y_otro_evento_no_avanzan() -> void:
	var locutor := _locutor()
	locutor.abrir(_tres_entradas())
	locutor.recibir(_click(MOUSE_BUTTON_RIGHT, true))
	locutor.recibir(_click(MOUSE_BUTTON_LEFT, false))
	locutor.recibir(InputEventKey.new())
	assert_array(_entradas).is_equal(["Primera"])
	assert_int(_cierres).is_equal(0)


func test_el_click_sin_dialogo_no_emite() -> void:
	var locutor := _locutor()
	locutor.recibir(_click(MOUSE_BUTTON_LEFT, true))
	assert_array(_entradas).is_empty()
	assert_int(_cierres).is_equal(0)
	assert_bool(locutor.puede_abandonar()).is_true()


func test_no_se_puede_cerrar_una_conversacion_a_mitad() -> void:  # AC-CTR-014
	var locutor := _locutor()
	locutor.abrir(_tres_entradas())
	assert_bool(locutor.cerrar()).is_false()
	assert_int(_cierres).is_equal(0)
	locutor.recibir(_click(MOUSE_BUTTON_LEFT, true))
	assert_array(_entradas).is_equal(["Primera", "Segunda"])


func test_el_pensamiento_se_puede_cerrar_sin_avanzar() -> void:  # AC-INV-019
	var locutor := _locutor()
	locutor.abrir(Dialogo.recordatorio("Un pensamiento."))
	assert_bool(locutor.cerrar()).is_true()
	assert_int(_cierres).is_equal(1)
	assert_bool(locutor.cerrar()).is_false()
	assert_int(_cierres).is_equal(1)


func test_una_entrada_terminada_permite_abrir_la_siguiente() -> void:
	var locutor := _locutor()
	locutor.abrir(Dialogo.new(PackedStringArray(["Única"])))
	locutor.recibir(_click(MOUSE_BUTTON_LEFT, true))
	assert_bool(locutor.abrir(_tres_entradas())).is_true()
	assert_array(_entradas).is_equal(["Única", "Primera"])


func test_un_dialogo_vacio_o_nulo_no_abre_ni_retiene() -> void:
	var locutor := _locutor()
	assert_bool(locutor.abrir(Dialogo.new())).is_false()
	assert_bool(locutor.abrir(null)).is_false()
	assert_array(_entradas).is_empty()
	assert_int(_cierres).is_equal(0)
	assert_bool(locutor.puede_abandonar()).is_true()


func _locutor() -> Locutor:
	var locutor: Locutor = auto_free(Locutor.new())
	locutor.entrada_mostrada.connect(func(entrada: String) -> void: _entradas.append(entrada))
	locutor.dialogo_cerrado.connect(func() -> void: _cierres += 1)
	return locutor


func _click(boton: MouseButton, presionado: bool) -> InputEventMouseButton:
	var evento := InputEventMouseButton.new()
	evento.button_index = boton
	evento.pressed = presionado
	return evento


func _tres_entradas() -> Dialogo:
	return Dialogo.new(PackedStringArray(["Primera", "Segunda", "Tercera"]))
