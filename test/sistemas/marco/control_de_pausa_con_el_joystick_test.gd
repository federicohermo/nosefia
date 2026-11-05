## START pausa como Esc, y CÍRCULO vuelve atrás sin pausar nunca.
extends GdUnitTestSuite

var _pausas: int = 0
var _cierres: int = 0


func before_test() -> void:
	_pausas = 0
	_cierres = 0


func after_test() -> void:
	get_tree().paused = false


func _control() -> ControlDePausa:
	var control: ControlDePausa = auto_free(ControlDePausa.new())
	control.pausado.connect(func() -> void: _pausas += 1)
	control.cierre_de_configuraciones_pedido.connect(func() -> void: _cierres += 1)
	add_child(control)
	return control


func _boton(indice: int) -> InputEventJoypadButton:
	var evento := InputEventJoypadButton.new()
	evento.button_index = indice as JoyButton
	evento.pressed = true
	return evento


## Lo que el motor entrega al apretar un botón: el evento crudo, que la acción reconoce.
func _la_cancelacion_reconoce(evento: InputEvent) -> bool:
	return InputMap.event_is_action(evento, &"ui_cancel")


## Una interfaz de prueba: abierta hasta que se la cierra.
class InterfazDePrueba:
	var abierta := true
	var cierres: int = 0

	func esta_abierta() -> bool:
		return abierta

	func cerrar_con_esc() -> void:
		abierta = false
		cierres += 1


func test_start_es_la_accion_de_cancelar_y_circulo_no() -> void:  # AC-SAV-046
	assert_bool(_la_cancelacion_reconoce(_boton(JOY_BUTTON_START))).is_true()
	assert_bool(_la_cancelacion_reconoce(_boton(JOY_BUTTON_B))).is_false()


func test_start_pausa_y_otro_start_reanuda() -> void:  # AC-SAV-046
	var control := _control()
	var start := InputEventAction.new()
	start.action = &"ui_cancel"
	start.pressed = true
	control._input(start)
	assert_bool(get_tree().paused).is_true()
	control._input(start)
	assert_bool(get_tree().paused).is_false()


func test_circulo_en_pausa_reanuda() -> void:  # AC-SAV-046
	var control := _control()
	control.pausar()
	control._input(_boton(JOY_BUTTON_B))
	assert_bool(get_tree().paused).is_false()


func test_circulo_cierra_la_interfaz_abierta_y_no_pausa() -> void:  # AC-SAV-046
	var control := _control()
	var interfaz := InterfazDePrueba.new()
	control.registrar_interfaz(interfaz.esta_abierta, interfaz.cerrar_con_esc)
	control._input(_boton(JOY_BUTTON_B))
	assert_int(interfaz.cierres).is_equal(1)
	assert_bool(get_tree().paused).is_false()
	assert_int(_pausas).is_zero()
	control._input(_boton(JOY_BUTTON_B))
	assert_bool(get_tree().paused).is_false()
	assert_int(_pausas).is_zero()


func test_circulo_sin_nada_abierto_no_pausa_y_no_se_come_el_evento() -> void:  # AC-SAV-046
	var control := _control()
	control._input(_boton(JOY_BUTTON_B))
	assert_bool(get_tree().paused).is_false()
	assert_int(_pausas).is_zero()
	assert_bool(control.get_viewport().is_input_handled()).is_false()


func test_circulo_cierra_configuraciones_abierta_desde_la_pausa() -> void:  # AC-SAV-046
	var configuraciones: CanvasLayer = auto_free(CanvasLayer.new())
	configuraciones.visible = true
	var control := _control()
	control.configuraciones = configuraciones
	control.pausar()
	control._input(_boton(JOY_BUTTON_B))
	assert_int(_cierres).is_equal(1)
	assert_bool(get_tree().paused).is_true()


func test_otro_boton_y_circulo_soltado_no_hacen_nada() -> void:  # AC-SAV-046
	var control := _control()
	control.pausar()
	var soltado := _boton(JOY_BUTTON_B)
	soltado.pressed = false
	control._input(soltado)
	control._input(_boton(JOY_BUTTON_Y))
	assert_bool(get_tree().paused).is_true()
