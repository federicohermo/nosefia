## Agacharse en la escena del jugador: la acción del proyecto, la cámara que baja y la mira que
## sale desde la altura nueva. La regla de la postura se prueba en `control_del_jugador_test.gd`.
extends GdUnitTestSuite

const JUGADOR := preload("res://src/escenas/jugador.tscn")

## Hacia delante de la mira, a una distancia que entra en el alcance.
const DISTANCIA_AL_OBJETO := 1.5


func after_test() -> void:
	Input.action_release(ReglasDelJugador.ACCION_AGACHARSE)


func test_agachado_la_camara_baja_y_al_soltar_vuelve() -> void:  # AC-PLY-125
	var jugador := _jugador()
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	Input.action_press(ReglasDelJugador.ACCION_AGACHARSE)
	jugador.call("_acomodar_la_vista")
	assert_float(camara.position.y).is_equal_approx(ReglasDelJugador.ALTURA_AGACHADO, 1e-5)
	Input.action_release(ReglasDelJugador.ACCION_AGACHARSE)
	jugador.call("_acomodar_la_vista")
	assert_float(camara.position.y).is_equal_approx(ReglasDelJugador.ALTURA_DE_LA_CAMARA, 1e-5)


func test_la_mira_enfoca_desde_la_altura_agachado() -> void:  # AC-PLY-125
	var jugador := _jugador()
	var objeto := _objeto_a_la_altura(ReglasDelJugador.ALTURA_AGACHADO)
	# La premisa: de pie, el objeto queda fuera del desvío de la mira.
	await _actualizar(jugador)
	assert_object(jugador.get("_enfocado")).is_null()
	Input.action_press(ReglasDelJugador.ACCION_AGACHARSE)
	jugador.call("_acomodar_la_vista")
	await _actualizar(jugador)
	assert_object(jugador.get("_enfocado")).is_same(objeto)


func test_suspendido_apretar_la_accion_no_baja_la_camara() -> void:  # AC-PLY-124
	var jugador := _jugador()
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	jugador.suspender()
	Input.action_press(ReglasDelJugador.ACCION_AGACHARSE)
	jugador.call("_acomodar_la_vista")
	assert_float(camara.position.y).is_equal_approx(ReglasDelJugador.ALTURA_DE_LA_CAMARA, 1e-5)
	jugador.reanudar()
	jugador.call("_acomodar_la_vista")
	assert_float(camara.position.y).is_equal_approx(ReglasDelJugador.ALTURA_AGACHADO, 1e-5)


func test_la_accion_de_agacharse_es_espacio_y_ninguna_otra_lo_tiene() -> void:  # AC-PLY-126
	var accion := ReglasDelJugador.ACCION_AGACHARSE
	assert_bool(InputMap.has_action(accion)).is_true()
	assert_bool(_tiene_espacio(accion)).is_true()
	for otra: StringName in InputMap.get_actions():
		if otra == accion or String(otra).begins_with("ui_"):
			continue
		(
			assert_bool(_tiene_espacio(otra))
			. override_failure_message("la acción `%s` también usa Espacio" % otra)
			. is_false()
		)


func test_espacio_no_acepta_el_boton_con_foco_y_enter_si() -> void:  # AC-PLY-127
	assert_bool(_tiene_espacio(&"ui_accept")).is_false()
	var teclas: Array[Key] = []
	for evento: InputEvent in InputMap.action_get_events(&"ui_accept"):
		if evento is InputEventKey:
			teclas.append(
				maxi((evento as InputEventKey).keycode, (evento as InputEventKey).physical_keycode)
			)
	assert_array(teclas).contains([KEY_ENTER, KEY_KP_ENTER])


func _tiene_espacio(accion: StringName) -> bool:
	for evento: InputEvent in InputMap.action_get_events(accion):
		var tecla := evento as InputEventKey
		if tecla != null and (tecla.keycode == KEY_SPACE or tecla.physical_keycode == KEY_SPACE):
			return true
	return false


func _jugador() -> CharacterBody3D:
	var jugador: CharacterBody3D = auto_free(JUGADOR.instantiate())
	add_child(jugador)
	jugador.set_physics_process(false)
	return jugador


## Un interactuable chico, fijo, delante del jugador y a la altura `y` sobre el piso.
func _objeto_a_la_altura(y: float) -> StaticBody3D:
	var cuerpo: StaticBody3D = auto_free(StaticBody3D.new())
	cuerpo.add_to_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(0.4, 0.4, 0.4)
	forma.shape = caja
	cuerpo.add_child(forma)
	add_child(cuerpo)
	cuerpo.global_position = Vector3(0.0, y, -DISTANCIA_AL_OBJETO)
	return cuerpo


func _actualizar(jugador: CharacterBody3D) -> void:
	for cuadro in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
