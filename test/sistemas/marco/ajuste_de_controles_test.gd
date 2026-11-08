## Las asignaciones de controles llegan al `InputMap`: cada acción responde a su entrada nueva y
## deja de responder a la que la ranura dejó.
##
## El `InputMap` es de todo el proceso: cada caso lo deja como en `project.godot` al terminar.
extends GdUnitTestSuite

const TECLA := AsignacionDeControles.TipoDeEntrada.TECLA
const BOTON := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_MOUSE
const JOYSTICK := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK

var _ajuste: AjusteDePreferencias


func before_test() -> void:
	_ajuste = auto_free(AjusteDePreferencias.new())
	add_child(_ajuste)


func after_test() -> void:
	_ajuste.aplicar(Preferencias.new())
	get_tree().paused = false


func _con(cambios: Array) -> Preferencias:
	var asignacion := AsignacionDeControles.new()
	for cambio: Array in cambios:
		asignacion.asignar(cambio[0], cambio[1], cambio[2], cambio[3])
	var preferencias := Preferencias.new()
	preferencias.poner_controles(asignacion)
	return preferencias


func _tecla(codigo: int) -> InputEventKey:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo as Key
	evento.pressed = true
	return evento


func _clic(boton: int) -> InputEventMouseButton:
	var evento := InputEventMouseButton.new()
	evento.button_index = boton as MouseButton
	evento.pressed = true
	return evento


func _boton_del_joystick(indice: int) -> InputEventJoypadButton:
	var evento := InputEventJoypadButton.new()
	evento.button_index = indice as JoyButton
	evento.pressed = true
	return evento


func _responde(evento: InputEvent, accion: StringName) -> bool:
	return InputMap.event_is_action(evento, accion)


func _eventos_de_teclas_y_clics(accion: StringName) -> int:
	var cuantos := 0
	for evento: InputEvent in InputMap.action_get_events(accion):
		if AjusteDePreferencias.es_de_la_asignacion(
			accion, AjusteDePreferencias.entrada_de(evento)
		):
			cuantos += 1
	return cuantos


func test_el_motor_arranca_con_el_esquema_de_fabrica() -> void:  # AC-CFG-016
	var fabrica := AsignacionDeControles.new()
	for accion: StringName in AsignacionDeControles.ACCIONES:
		var esperadas := 0
		for entrada: Dictionary in fabrica.entradas():
			if (
				entrada["accion"] != accion
				or Vector2i(entrada["tipo"], entrada["codigo"]) == AsignacionDeControles.VACIA
			):
				continue
			esperadas += 1
			var tiene := false
			for evento: InputEvent in InputMap.action_get_events(accion):
				var propia := AjusteDePreferencias.entrada_de(evento)
				if propia == Vector2i(entrada["tipo"], entrada["codigo"]):
					tiene = true
			(
				assert_bool(tiene)
				. override_failure_message("%s no tiene %s" % [accion, entrada])
				. is_true()
			)
		assert_int(_eventos_de_teclas_y_clics(accion)).is_equal(esperadas)


func test_agarrar_en_f_responde_a_f_y_no_al_clic_izquierdo() -> void:  # AC-CFG-020
	_ajuste.aplicar(_con([[AsignacionDeControles.AGARRAR, 0, TECLA, KEY_F]]))
	assert_bool(_responde(_tecla(KEY_F), AsignacionDeControles.AGARRAR)).is_true()
	assert_bool(_responde(_clic(MOUSE_BUTTON_LEFT), AsignacionDeControles.AGARRAR)).is_false()


func test_examinar_en_el_clic_central_responde_al_clic_central() -> void:  # AC-CFG-020
	_ajuste.aplicar(_con([[AsignacionDeControles.EXAMINAR, 0, BOTON, MOUSE_BUTTON_MIDDLE]]))
	assert_bool(_responde(_clic(MOUSE_BUTTON_MIDDLE), AsignacionDeControles.EXAMINAR)).is_true()
	assert_bool(_responde(_tecla(KEY_E), AsignacionDeControles.EXAMINAR)).is_false()


func test_un_intercambio_se_ve_en_las_dos_acciones() -> void:  # AC-CFG-020
	_ajuste.aplicar(_con([[AsignacionDeControles.EXAMINAR, 0, TECLA, KEY_SPACE]]))
	assert_bool(_responde(_tecla(KEY_SPACE), AsignacionDeControles.EXAMINAR)).is_true()
	assert_bool(_responde(_tecla(KEY_E), AsignacionDeControles.AGACHARSE)).is_true()
	assert_bool(_responde(_tecla(KEY_SPACE), AsignacionDeControles.AGACHARSE)).is_false()


func test_cada_direccion_responde_a_sus_dos_ranuras() -> void:  # AC-CFG-020
	_ajuste.aplicar(
		_con(
			[
				[
					AsignacionDeControles.ADELANTE,
					AsignacionDeControles.RANURA_DE_FLECHAS,
					TECLA,
					KEY_H
				]
			]
		)
	)
	assert_bool(_responde(_tecla(KEY_W), AsignacionDeControles.ADELANTE)).is_true()
	assert_bool(_responde(_tecla(KEY_H), AsignacionDeControles.ADELANTE)).is_true()
	assert_bool(_responde(_tecla(KEY_UP), AsignacionDeControles.ADELANTE)).is_false()
	assert_bool(_responde(_tecla(KEY_DOWN), AsignacionDeControles.ATRAS)).is_true()


func test_volver_al_esquema_de_fabrica_devuelve_las_teclas_de_hoy() -> void:  # AC-CFG-020
	_ajuste.aplicar(_con([[AsignacionDeControles.AGARRAR, 0, TECLA, KEY_F]]))
	_ajuste.aplicar(Preferencias.new())
	assert_bool(_responde(_clic(MOUSE_BUTTON_LEFT), AsignacionDeControles.AGARRAR)).is_true()
	assert_bool(_responde(_tecla(KEY_F), AsignacionDeControles.AGARRAR)).is_false()


func test_pausa_en_p_conserva_el_joystick_de_la_accion() -> void:  # AC-CFG-020
	var botones_antes := _cuantos_botones_de_joystick(AsignacionDeControles.PAUSA)
	_ajuste.aplicar(_con([[AsignacionDeControles.PAUSA, 0, TECLA, KEY_P]]))
	assert_bool(_responde(_tecla(KEY_P), AsignacionDeControles.PAUSA)).is_true()
	assert_bool(_responde(_tecla(KEY_ESCAPE), AsignacionDeControles.PAUSA)).is_false()
	assert_int(_cuantos_botones_de_joystick(AsignacionDeControles.PAUSA)).is_equal(botones_antes)


func _cuantos_botones_de_joystick(accion: StringName) -> int:
	var cuantos := 0
	for evento: InputEvent in InputMap.action_get_events(accion):
		if evento is InputEventJoypadButton:
			cuantos += 1
	return cuantos


func test_la_tecla_de_pausa_nueva_pausa_y_reanuda_y_esc_ya_no() -> void:  # AC-CFG-020
	_ajuste.aplicar(_con([[AsignacionDeControles.PAUSA, 0, TECLA, KEY_P]]))
	var control: ControlDePausa = auto_free(ControlDePausa.new())
	add_child(control)
	control._input(_tecla(KEY_ESCAPE))
	assert_bool(get_tree().paused).is_false()
	control._input(_tecla(KEY_P))
	assert_bool(get_tree().paused).is_true()
	control._input(_tecla(KEY_P))
	assert_bool(get_tree().paused).is_false()


func test_con_pausa_en_p_perder_el_cursor_sigue_pausando() -> void:  # AC-CFG-021
	_ajuste.aplicar(_con([[AsignacionDeControles.PAUSA, 0, TECLA, KEY_P]]))
	var control: ControlDePausa = auto_free(ControlDePausa.new())
	add_child(control)
	control.set("_cursor_antes", true)
	control.call("_mirar_el_cursor")
	assert_bool(get_tree().paused).is_true()


func test_interactuar_en_g_responde_a_g_y_no_al_clic_derecho() -> void:  # AC-CFG-024
	_ajuste.aplicar(_con([[AsignacionDeControles.INTERACTUAR, 0, TECLA, KEY_G]]))
	assert_bool(_responde(_tecla(KEY_G), AsignacionDeControles.INTERACTUAR)).is_true()
	assert_bool(_responde(_clic(MOUSE_BUTTON_RIGHT), AsignacionDeControles.INTERACTUAR)).is_false()


func test_el_esquema_que_se_guarda_vuelve_a_aplicarse_en_otro_arranque() -> void:  # AC-CFG-022
	var preferencias := _con([[AsignacionDeControles.EXAMINAR, 0, TECLA, KEY_F]])
	assert_bool(_ajuste.cambiar(preferencias)).is_true()
	_ajuste.aplicar(Preferencias.new())
	assert_bool(_responde(_tecla(KEY_F), AsignacionDeControles.EXAMINAR)).is_false()
	var otro_arranque: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(otro_arranque)
	otro_arranque.cargar_y_aplicar()
	assert_bool(_responde(_tecla(KEY_F), AsignacionDeControles.EXAMINAR)).is_true()
	assert_bool(_responde(_tecla(KEY_E), AsignacionDeControles.EXAMINAR)).is_false()


func test_un_boton_de_joystick_asignado_responde_y_el_anterior_no() -> void:  # AC-CFG-026
	_ajuste.aplicar(_con([[AsignacionDeControles.EXAMINAR, 1, JOYSTICK, JOY_BUTTON_Y]]))
	assert_bool(_responde(_boton_del_joystick(JOY_BUTTON_Y), &"examinar")).is_true()
	assert_bool(_responde(_boton_del_joystick(JOY_BUTTON_X), &"examinar")).is_false()
	assert_bool(_responde(_tecla(KEY_E), &"examinar")).is_true()


func test_intercambiar_dos_botones_de_joystick_los_cruza_en_el_motor() -> void:  # AC-CFG-026
	_ajuste.aplicar(_con([[AsignacionDeControles.EXAMINAR, 1, JOYSTICK, JOY_BUTTON_LEFT_SHOULDER]]))
	assert_bool(_responde(_boton_del_joystick(JOY_BUTTON_LEFT_SHOULDER), &"examinar")).is_true()
	assert_bool(_responde(_boton_del_joystick(JOY_BUTTON_LEFT_SHOULDER), &"agacharse")).is_false()
	assert_bool(_responde(_boton_del_joystick(JOY_BUTTON_X), &"agacharse")).is_true()


func test_aplicar_las_asignaciones_no_toca_start_ni_los_ejes() -> void:  # AC-CFG-025
	_ajuste.aplicar(_con([[AsignacionDeControles.PAUSA, 0, TECLA, KEY_P]]))
	assert_bool(_responde(_boton_del_joystick(JOY_BUTTON_START), &"ui_cancel")).is_true()
	assert_bool(_responde(_tecla(KEY_P), &"ui_cancel")).is_true()
	assert_bool(_responde(_tecla(KEY_ESCAPE), &"ui_cancel")).is_false()
	var eje := InputEventJoypadMotion.new()
	eje.axis = JOY_AXIS_LEFT_Y
	eje.axis_value = -1.0
	assert_bool(_responde(eje, &"mover_adelante")).is_true()


func test_la_secundaria_responde_en_el_momento_y_vaciarla_la_apaga() -> void:  # AC-CFG-038, AC-CFG-020
	var asignacion := AsignacionDeControles.new()
	asignacion.asignar(AsignacionDeControles.EXAMINAR, AsignacionDeControles.RANURA_SECUNDARIA, TECLA, KEY_F)
	var preferencias := Preferencias.new()
	preferencias.poner_controles(asignacion)
	_ajuste.aplicar(preferencias)
	assert_bool(_responde(_tecla(KEY_F), AsignacionDeControles.EXAMINAR)).is_true()
	assert_bool(_responde(_tecla(KEY_E), AsignacionDeControles.EXAMINAR)).is_true()
	asignacion.vaciar(AsignacionDeControles.EXAMINAR, AsignacionDeControles.RANURA_SECUNDARIA)
	preferencias.poner_controles(asignacion)
	_ajuste.aplicar(preferencias)
	assert_bool(_responde(_tecla(KEY_F), AsignacionDeControles.EXAMINAR)).is_false()
	assert_bool(_responde(_tecla(KEY_E), AsignacionDeControles.EXAMINAR)).is_true()


func test_pausa_con_secundaria_pausa_con_las_dos() -> void:  # AC-CFG-038
	var asignacion := AsignacionDeControles.new()
	asignacion.asignar(AsignacionDeControles.PAUSA, AsignacionDeControles.RANURA_SECUNDARIA, TECLA, KEY_P)
	var preferencias := Preferencias.new()
	preferencias.poner_controles(asignacion)
	_ajuste.aplicar(preferencias)
	assert_bool(_responde(_tecla(KEY_P), AsignacionDeControles.PAUSA)).is_true()
	assert_bool(_responde(_tecla(KEY_ESCAPE), AsignacionDeControles.PAUSA)).is_true()
