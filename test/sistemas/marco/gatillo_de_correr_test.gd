## El gatillo derecho llega al `InputMap`: Correr responde a él pasada la mitad de su recorrido, y
## deja de responder cuando la ranura pasa a un botón.
##
## El `InputMap` es de todo el proceso: cada caso lo deja como en `project.godot` al terminar.
extends GdUnitTestSuite

const JOYSTICK := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK
const GATILLO := AsignacionDeControles.TipoDeEntrada.GATILLO_DEL_JOYSTICK

var _ajuste: AjusteDePreferencias


func before_test() -> void:
	_ajuste = auto_free(AjusteDePreferencias.new())
	add_child(_ajuste)


func after_test() -> void:
	_apretar_el_gatillo(0.0)
	_ajuste.aplicar(Preferencias.new())


func _apretar_el_gatillo(recorrido: float) -> void:
	var evento := InputEventJoypadMotion.new()
	evento.axis = JOY_AXIS_TRIGGER_RIGHT
	evento.axis_value = recorrido
	Input.parse_input_event(evento)
	Input.flush_buffered_events()


func test_correr_responde_al_gatillo_pasada_la_mitad_y_no_antes() -> void:  # AC-CFG-047
	_ajuste.aplicar(Preferencias.new())
	_apretar_el_gatillo(0.4)
	assert_bool(Input.is_action_pressed(ReglasDelJugador.ACCION_CORRER)).is_false()
	_apretar_el_gatillo(0.6)
	assert_bool(Input.is_action_pressed(ReglasDelJugador.ACCION_CORRER)).is_true()
	_apretar_el_gatillo(0.4)
	assert_bool(Input.is_action_pressed(ReglasDelJugador.ACCION_CORRER)).is_false()


func test_con_correr_en_un_boton_el_gatillo_ya_no_corre() -> void:  # AC-CFG-047
	var asignacion := AsignacionDeControles.new()
	asignacion.asignar(
		AsignacionDeControles.CORRER,
		AsignacionDeControles.RANURA_DEL_JOYSTICK,
		JOYSTICK,
		JOY_BUTTON_Y
	)
	var preferencias := Preferencias.new()
	preferencias.poner_controles(asignacion)
	_ajuste.aplicar(preferencias)
	_apretar_el_gatillo(1.0)
	assert_bool(Input.is_action_pressed(ReglasDelJugador.ACCION_CORRER)).is_false()
	var boton := InputEventJoypadButton.new()
	boton.button_index = JOY_BUTTON_Y
	assert_bool(InputMap.event_is_action(boton, ReglasDelJugador.ACCION_CORRER)).is_true()


func test_el_gatillo_del_mapa_es_el_de_la_asignacion_de_fabrica() -> void:  # AC-CFG-047
	_ajuste.aplicar(Preferencias.new())
	var entradas: Array[Vector2i] = []
	for evento: InputEvent in InputMap.action_get_events(ReglasDelJugador.ACCION_CORRER):
		entradas.append(AjusteDePreferencias.entrada_de(evento))
	assert_array(entradas).contains([Vector2i(GATILLO, JOY_AXIS_TRIGGER_RIGHT)])
	(
		assert_bool(
			AjusteDePreferencias.es_de_la_asignacion(
				AsignacionDeControles.EXAMINAR, Vector2i(GATILLO, JOY_AXIS_TRIGGER_RIGHT)
			)
		)
		. is_false()
	)
