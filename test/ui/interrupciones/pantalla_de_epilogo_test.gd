## La pantalla del epílogo: dibuja la placa que decide el recorrido, y «SIGUIENTE» se acciona con el
## mouse, el teclado y el joystick sin saltear una placa.
##
## Los gestos entran por el viewport, como los del motor.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/pantalla_de_epilogo.tscn"
const FUNDIDO := RecorridoDelEpilogo.SEGUNDOS_DEL_FUNDIDO

var _cerrados: int = 0


func before_test() -> void:
	_cerrados = 0


func _placas(cantidad: int) -> Array[EpilogosDeLosFinales.Placa]:
	var textos: Array = []
	for indice in range(cantidad):
		textos.append("placa %d" % indice)
	return EpilogosDeLosFinales.con_texto(EpilogosDeLosFinales.FONDO_DEL_FINAL_2, textos)


func _pantalla(placas: Array[EpilogosDeLosFinales.Placa]) -> PantallaDeEpilogo:
	var pantalla: PantallaDeEpilogo = auto_free(load(ESCENA).instantiate())
	pantalla.terminado.connect(func() -> void: _cerrados += 1)
	add_child(pantalla)
	pantalla.mostrar(placas)
	return pantalla


## Con la placa 0 ya a la vista y sin fundido en marcha.
func _leyendo(cantidad: int = 3) -> PantallaDeEpilogo:
	var pantalla := _pantalla(_placas(cantidad))
	pantalla.avanzar(2.0 * FUNDIDO)
	return pantalla


func _teclado() -> Array[InputEvent]:
	var eventos: Array[InputEvent] = []
	for pulsado: bool in [true, false]:
		var tecla := InputEventKey.new()
		tecla.keycode = KEY_ENTER
		tecla.physical_keycode = KEY_ENTER
		tecla.pressed = pulsado
		eventos.append(tecla)
	return eventos


func _joystick() -> Array[InputEvent]:
	var eventos: Array[InputEvent] = []
	for pulsado: bool in [true, false]:
		var boton := InputEventJoypadButton.new()
		boton.button_index = JOY_BUTTON_A
		boton.pressed = pulsado
		eventos.append(boton)
	return eventos


func _mouse(boton: Button) -> Array[InputEvent]:
	var eventos: Array[InputEvent] = []
	var centro := boton.get_global_transform_with_canvas() * (boton.size / 2.0)
	for pulsado: bool in [true, false]:
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.position = centro
		clic.global_position = centro
		clic.pressed = pulsado
		eventos.append(clic)
	return eventos


func _accionar(eventos: Array[InputEvent]) -> void:
	for evento in eventos:
		get_viewport().push_input(evento)


func test_arranca_oculta_y_sin_placa() -> void:  # AC-SHF-134
	var pantalla: PantallaDeEpilogo = auto_free(load(ESCENA).instantiate())
	add_child(pantalla)
	assert_bool(pantalla.visible).is_false()


func test_muestra_la_placa_con_su_texto_y_un_boton_siguiente() -> void:  # AC-SHF-134
	var placas := _placas(2)
	var pantalla := _pantalla(placas)
	assert_object(pantalla.placa_a_la_vista()).is_null()
	pantalla.avanzar(FUNDIDO)
	assert_object(pantalla.placa_a_la_vista()).is_same(placas[0])
	assert_float(pantalla.negro()).is_equal_approx(1.0, 1e-6)
	pantalla.avanzar(FUNDIDO)
	assert_float(pantalla.negro()).is_equal(0.0)
	assert_str(pantalla.boton().text).is_equal(PantallaDeEpilogo.TEXTO_DEL_BOTON)
	var textos: Array[Label] = []
	for etiqueta: Label in pantalla.find_children("*", "Label", true, false):
		textos.append(etiqueta)
	(
		assert_array(textos.map(func(etiqueta: Label) -> String: return etiqueta.text))
		. contains([placas[0].texto])
	)


func test_el_negro_cubre_la_pantalla_a_la_mitad_de_cada_fundido() -> void:  # AC-SHF-138
	var pantalla := _pantalla(_placas(1))
	pantalla.avanzar(FUNDIDO / 2.0)
	assert_float(pantalla.negro()).is_equal_approx(0.5, 1e-6)
	pantalla.avanzar(FUNDIDO)
	assert_float(pantalla.negro()).is_equal_approx(0.5, 1e-6)


func test_la_sombra_de_lectura_cubre_los_dos_bordes_de_una_ventana_ancha() -> void:  # AC-SHF-134
	var pantalla := _pantalla(_placas(1))
	var ancho := 2560.0
	pantalla.ajustar_a(Vector2(ancho, 1080.0))
	var franja: TextureRect = pantalla.find_child("Lectura", true, false)
	var transformacion := franja.get_global_transform_with_canvas()
	var izquierda := (transformacion * Vector2.ZERO).x
	var derecha := (transformacion * franja.size).x
	assert_float(izquierda).is_less_equal(0.0)
	assert_float(derecha).is_greater_equal(ancho)


func test_siguiente_se_acciona_con_el_teclado() -> void:  # AC-SHF-140
	var placas := _placas(3)
	var pantalla := _pantalla(placas)
	pantalla.avanzar(2.0 * FUNDIDO)
	assert_bool(pantalla.boton().has_focus()).is_true()
	_accionar(_teclado())
	pantalla.avanzar(2.0 * FUNDIDO)
	assert_object(pantalla.placa_a_la_vista()).is_same(placas[1])


func test_siguiente_se_acciona_con_el_joystick() -> void:  # AC-SHF-140
	var placas := _placas(3)
	var pantalla := _pantalla(placas)
	pantalla.avanzar(2.0 * FUNDIDO)
	_accionar(_joystick())
	pantalla.avanzar(2.0 * FUNDIDO)
	assert_object(pantalla.placa_a_la_vista()).is_same(placas[1])


func test_siguiente_se_acciona_con_el_mouse() -> void:  # AC-SHF-140
	var placas := _placas(3)
	var pantalla := _pantalla(placas)
	pantalla.avanzar(2.0 * FUNDIDO)
	await get_tree().process_frame
	_accionar(_mouse(pantalla.boton()))
	pantalla.avanzar(2.0 * FUNDIDO)
	assert_object(pantalla.placa_a_la_vista()).is_same(placas[1])


func test_dos_gestos_seguidos_pasan_una_sola_placa() -> void:  # AC-SHF-140
	var pantalla := _leyendo()
	_accionar(_teclado())
	_accionar(_teclado())
	pantalla.avanzar(2.0 * FUNDIDO)
	assert_str(pantalla.placa_a_la_vista().texto).is_equal("placa 1")
	assert_int(_cerrados).is_zero()


func test_un_gesto_en_mitad_del_fundido_no_salta_la_placa() -> void:  # AC-SHF-140
	var pantalla := _leyendo()
	_accionar(_teclado())
	pantalla.avanzar(FUNDIDO * 0.5)
	_accionar(_teclado())
	pantalla.avanzar(FUNDIDO * 1.5)
	assert_str(pantalla.placa_a_la_vista().texto).is_equal("placa 1")


func test_cerrar_la_ultima_placa_avisa_una_sola_vez_y_se_libera() -> void:  # AC-SHF-138
	var pantalla := _leyendo(1)
	assert_int(_cerrados).is_zero()
	_accionar(_teclado())
	pantalla.avanzar(FUNDIDO)
	assert_int(_cerrados).is_equal(1)
	assert_float(pantalla.negro()).is_equal_approx(1.0, 1e-6)
	assert_object(pantalla.placa_a_la_vista()).is_null()
	pantalla.avanzar(FUNDIDO)
	assert_int(_cerrados).is_equal(1)
	assert_bool(pantalla.is_queued_for_deletion()).is_true()
