## Las asignaciones de controles llegan al `InputMap`: cada acción responde a su entrada nueva y
## deja de responder a la que la ranura dejó.
##
## El `InputMap` es de todo el proceso: cada caso lo deja como en `project.godot` al terminar.
extends GdUnitTestSuite

const A := AsignacionDeControles
const TECLA := AsignacionDeControles.TipoDeEntrada.TECLA
const BOTON := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_MOUSE

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


func _responde(evento: InputEvent, accion: StringName) -> bool:
	return InputMap.event_is_action(evento, accion)


func _eventos_de_teclas_y_clics(accion: StringName) -> int:
	var cuantos := 0
	for evento: InputEvent in InputMap.action_get_events(accion):
		if AjusteDePreferencias.entrada_de(evento) != AjusteDePreferencias.SIN_ENTRADA:
			cuantos += 1
	return cuantos


func test_el_motor_arranca_con_el_esquema_de_fabrica() -> void:  # AC-CFG-016
	var fabrica := AsignacionDeControles.new()
	for accion: StringName in A.ACCIONES:
		var esperadas := 0
		for entrada: Dictionary in fabrica.entradas():
			if entrada["accion"] != accion:
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
	_ajuste.aplicar(_con([[A.AGARRAR, 0, TECLA, KEY_F]]))
	assert_bool(_responde(_tecla(KEY_F), A.AGARRAR)).is_true()
	assert_bool(_responde(_clic(MOUSE_BUTTON_LEFT), A.AGARRAR)).is_false()


func test_examinar_en_el_clic_central_responde_al_clic_central() -> void:  # AC-CFG-020
	_ajuste.aplicar(_con([[A.EXAMINAR, 0, BOTON, MOUSE_BUTTON_MIDDLE]]))
	assert_bool(_responde(_clic(MOUSE_BUTTON_MIDDLE), A.EXAMINAR)).is_true()
	assert_bool(_responde(_tecla(KEY_E), A.EXAMINAR)).is_false()


func test_un_intercambio_se_ve_en_las_dos_acciones() -> void:  # AC-CFG-020
	_ajuste.aplicar(_con([[A.EXAMINAR, 0, TECLA, KEY_SPACE]]))
	assert_bool(_responde(_tecla(KEY_SPACE), A.EXAMINAR)).is_true()
	assert_bool(_responde(_tecla(KEY_E), A.AGACHARSE)).is_true()
	assert_bool(_responde(_tecla(KEY_SPACE), A.AGACHARSE)).is_false()


func test_cada_direccion_responde_a_sus_dos_ranuras() -> void:  # AC-CFG-020
	_ajuste.aplicar(_con([[A.ADELANTE, A.RANURA_DE_FLECHAS, TECLA, KEY_H]]))
	assert_bool(_responde(_tecla(KEY_W), A.ADELANTE)).is_true()
	assert_bool(_responde(_tecla(KEY_H), A.ADELANTE)).is_true()
	assert_bool(_responde(_tecla(KEY_UP), A.ADELANTE)).is_false()
	assert_bool(_responde(_tecla(KEY_DOWN), A.ATRAS)).is_true()


func test_volver_al_esquema_de_fabrica_devuelve_las_teclas_de_hoy() -> void:  # AC-CFG-020
	_ajuste.aplicar(_con([[A.AGARRAR, 0, TECLA, KEY_F]]))
	_ajuste.aplicar(Preferencias.new())
	assert_bool(_responde(_clic(MOUSE_BUTTON_LEFT), A.AGARRAR)).is_true()
	assert_bool(_responde(_tecla(KEY_F), A.AGARRAR)).is_false()


func test_pausa_en_p_conserva_el_joystick_de_la_accion() -> void:  # AC-CFG-020
	var botones_antes := _cuantos_botones_de_joystick(A.PAUSA)
	_ajuste.aplicar(_con([[A.PAUSA, 0, TECLA, KEY_P]]))
	assert_bool(_responde(_tecla(KEY_P), A.PAUSA)).is_true()
	assert_bool(_responde(_tecla(KEY_ESCAPE), A.PAUSA)).is_false()
	assert_int(_cuantos_botones_de_joystick(A.PAUSA)).is_equal(botones_antes)


func _cuantos_botones_de_joystick(accion: StringName) -> int:
	var cuantos := 0
	for evento: InputEvent in InputMap.action_get_events(accion):
		if evento is InputEventJoypadButton:
			cuantos += 1
	return cuantos


func test_la_tecla_de_pausa_nueva_pausa_y_reanuda_y_esc_ya_no() -> void:  # AC-CFG-020
	_ajuste.aplicar(_con([[A.PAUSA, 0, TECLA, KEY_P]]))
	var control: ControlDePausa = auto_free(ControlDePausa.new())
	add_child(control)
	control._input(_tecla(KEY_ESCAPE))
	assert_bool(get_tree().paused).is_false()
	control._input(_tecla(KEY_P))
	assert_bool(get_tree().paused).is_true()
	control._input(_tecla(KEY_P))
	assert_bool(get_tree().paused).is_false()


func test_con_pausa_en_p_perder_el_cursor_sigue_pausando() -> void:  # AC-CFG-021
	_ajuste.aplicar(_con([[A.PAUSA, 0, TECLA, KEY_P]]))
	var control: ControlDePausa = auto_free(ControlDePausa.new())
	add_child(control)
	control.set("_cursor_antes", true)
	control.call("_mirar_el_cursor")
	assert_bool(get_tree().paused).is_true()


func test_interactuar_en_g_responde_a_g_y_no_al_clic_derecho() -> void:  # AC-CFG-024
	_ajuste.aplicar(_con([[A.INTERACTUAR, 0, TECLA, KEY_G]]))
	assert_bool(_responde(_tecla(KEY_G), A.INTERACTUAR)).is_true()
	assert_bool(_responde(_clic(MOUSE_BUTTON_RIGHT), A.INTERACTUAR)).is_false()


func test_el_esquema_que_se_guarda_vuelve_a_aplicarse_en_otro_arranque() -> void:  # AC-CFG-022
	var preferencias := _con([[A.EXAMINAR, 0, TECLA, KEY_F]])
	assert_bool(_ajuste.cambiar(preferencias)).is_true()
	_ajuste.aplicar(Preferencias.new())
	assert_bool(_responde(_tecla(KEY_F), A.EXAMINAR)).is_false()
	var otro_arranque: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(otro_arranque)
	otro_arranque.cargar_y_aplicar()
	assert_bool(_responde(_tecla(KEY_F), A.EXAMINAR)).is_true()
	assert_bool(_responde(_tecla(KEY_E), A.EXAMINAR)).is_false()
