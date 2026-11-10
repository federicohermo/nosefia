## Correr en la escena del jugador: la acción del proyecto y la traducción de la acción apretada a
## la velocidad del cuerpo. La regla de cuánto se corre se prueba en `control_del_jugador_test.gd`.
extends GdUnitTestSuite

const JUGADOR := preload("res://src/escenas/jugador.tscn")


func after_test() -> void:
	Input.action_release(ReglasDelJugador.ACCION_CORRER)
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)


func test_la_accion_de_correr_es_shift_y_l3_y_ninguna_otra_los_tiene() -> void:  # AC-PLY-197
	var accion := ReglasDelJugador.ACCION_CORRER
	assert_bool(InputMap.has_action(accion)).is_true()
	assert_bool(_tiene_tecla(accion, KEY_SHIFT)).is_true()
	assert_bool(_tiene_boton(accion, JOY_BUTTON_LEFT_STICK)).is_true()
	for otra: StringName in InputMap.get_actions():
		if otra == accion or String(otra).begins_with("ui_"):
			continue
		(
			assert_bool(_tiene_tecla(otra, KEY_SHIFT) or _tiene_boton(otra, JOY_BUTTON_LEFT_STICK))
			. override_failure_message("la acción `%s` también usa Shift o L3" % otra)
			. is_false()
		)


func test_apretar_correr_acelera_el_cuerpo_y_soltarla_lo_devuelve() -> void:  # AC-PLY-192
	var jugador := _jugador()
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	jugador.call("_physics_process", 1.0 / 60.0)
	assert_float(_rapidez(jugador)).is_equal_approx(ReglasDelJugador.VELOCIDAD_DE_CAMINATA, 1e-3)
	Input.action_press(ReglasDelJugador.ACCION_CORRER)
	jugador.call("_physics_process", 1.0 / 60.0)
	assert_float(_rapidez(jugador)).is_equal_approx(
		ReglasDelJugador.VELOCIDAD_DE_CAMINATA * ReglasDelJugador.MULTIPLICADOR_DE_CORRER, 1e-3
	)
	Input.action_release(ReglasDelJugador.ACCION_CORRER)
	jugador.call("_physics_process", 1.0 / 60.0)
	assert_float(_rapidez(jugador)).is_equal_approx(ReglasDelJugador.VELOCIDAD_DE_CAMINATA, 1e-3)


func _rapidez(jugador: CharacterBody3D) -> float:
	return Vector2(jugador.velocity.x, jugador.velocity.z).length()


func _tiene_tecla(accion: StringName, buscada: Key) -> bool:
	for evento: InputEvent in InputMap.action_get_events(accion):
		var tecla := evento as InputEventKey
		if tecla != null and (tecla.keycode == buscada or tecla.physical_keycode == buscada):
			return true
	return false


func _tiene_boton(accion: StringName, buscado: JoyButton) -> bool:
	for evento: InputEvent in InputMap.action_get_events(accion):
		var boton := evento as InputEventJoypadButton
		if boton != null and boton.button_index == buscado:
			return true
	return false


func _jugador() -> CharacterBody3D:
	var jugador: CharacterBody3D = auto_free(JUGADOR.instantiate())
	add_child(jugador)
	jugador.set_physics_process(false)
	return jugador
