## Agacharse en la escena del jugador: la acción del proyecto, la cámara que baja y la mira que
## sale desde la altura nueva. La regla de la postura se prueba en `control_del_jugador_test.gd`.
extends GdUnitTestSuite

const JUGADOR := preload("res://src/escenas/jugador.tscn")

## Hacia delante de la mira, a una distancia que entra en el alcance.
const DISTANCIA_AL_OBJETO := 1.5

const CUADRO := 1.0 / 60.0


func after_test() -> void:
	Input.action_release(ReglasDelJugador.ACCION_AGACHARSE)


func test_apretar_agacha_la_camara_y_apretar_otra_vez_la_para() -> void:  # AC-PLY-125
	var jugador := _jugador()
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	_apretar_y_soltar(jugador)
	assert_float(camara.position.y).is_equal_approx(ReglasDelJugador.ALTURA_AGACHADO, 1e-5)
	_apretar_y_soltar(jugador)
	assert_float(camara.position.y).is_equal_approx(ReglasDelJugador.ALTURA_DE_LA_CAMARA, 1e-5)


func test_una_jornada_nueva_arranca_de_pie() -> void:  # AC-PLY-198
	var jugador := _jugador()
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	_apretar_y_soltar(jugador)
	jugador.ubicar(Transform3D.IDENTITY)
	_asentar_la_vista(jugador)
	assert_float(camara.position.y).is_equal_approx(ReglasDelJugador.ALTURA_DE_LA_CAMARA, 1e-5)


func test_un_cuadro_baja_la_camara_un_tramo_y_no_de_un_salto() -> void:  # AC-PLY-128
	var jugador := _jugador()
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	Input.action_press(ReglasDelJugador.ACCION_AGACHARSE)
	jugador.call("_acomodar_la_vista", CUADRO)
	assert_float(camara.position.y).is_less(ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	assert_float(camara.position.y).is_greater(ReglasDelJugador.ALTURA_AGACHADO)


func test_la_mira_enfoca_desde_la_altura_agachado() -> void:  # AC-PLY-125
	var jugador := _jugador()
	var objeto := _objeto_a_la_altura(ReglasDelJugador.ALTURA_AGACHADO)
	# La premisa: de pie, el objeto queda fuera del desvío de la mira.
	await _actualizar(jugador)
	assert_object(jugador.get("_enfocado")).is_null()
	_apretar_y_soltar(jugador)
	await _actualizar(jugador)
	assert_object(jugador.get("_enfocado")).is_same(objeto)


func test_suspendido_apretar_la_accion_no_baja_la_camara() -> void:  # AC-PLY-124
	var jugador := _jugador()
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	jugador.suspender()
	Input.action_press(ReglasDelJugador.ACCION_AGACHARSE)
	_asentar_la_vista(jugador)
	assert_float(camara.position.y).is_equal_approx(ReglasDelJugador.ALTURA_DE_LA_CAMARA, 1e-5)
	Input.action_release(ReglasDelJugador.ACCION_AGACHARSE)
	_asentar_la_vista(jugador)
	jugador.reanudar()
	_apretar_y_soltar(jugador)
	assert_float(camara.position.y).is_equal_approx(ReglasDelJugador.ALTURA_AGACHADO, 1e-5)


func test_la_accion_de_agacharse_es_ctrl_y_ninguna_otra_lo_tiene() -> void:  # AC-PLY-126
	var accion := ReglasDelJugador.ACCION_AGACHARSE
	assert_bool(InputMap.has_action(accion)).is_true()
	assert_bool(_tiene_tecla(accion, KEY_CTRL)).is_true()
	for otra: StringName in InputMap.get_actions():
		if otra == accion or String(otra).begins_with("ui_"):
			continue
		(
			assert_bool(_tiene_tecla(otra, KEY_CTRL))
			. override_failure_message("la acción `%s` también usa Ctrl" % otra)
			. is_false()
		)


func test_espacio_no_acepta_el_boton_con_foco_y_enter_si() -> void:  # AC-PLY-127
	assert_bool(_tiene_tecla(&"ui_accept", KEY_SPACE)).is_false()
	var teclas: Array[Key] = []
	for evento: InputEvent in InputMap.action_get_events(&"ui_accept"):
		if evento is InputEventKey:
			teclas.append(
				maxi((evento as InputEventKey).keycode, (evento as InputEventKey).physical_keycode)
			)
	assert_array(teclas).contains([KEY_ENTER, KEY_KP_ENTER])


func _tiene_tecla(accion: StringName, buscada: Key) -> bool:
	for evento: InputEvent in InputMap.action_get_events(accion):
		var tecla := evento as InputEventKey
		if tecla != null and (tecla.keycode == buscada or tecla.physical_keycode == buscada):
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
	caja.size = Vector3(0.2, 0.2, 0.2)
	forma.shape = caja
	cuerpo.add_child(forma)
	add_child(cuerpo)
	cuerpo.global_position = Vector3(0.0, y, -DISTANCIA_AL_OBJETO)
	return cuerpo


## Un toque a la acción: apretada y soltada, con la vista asentada tras cada cambio.
func _apretar_y_soltar(jugador: CharacterBody3D) -> void:
	Input.action_press(ReglasDelJugador.ACCION_AGACHARSE)
	_asentar_la_vista(jugador)
	Input.action_release(ReglasDelJugador.ACCION_AGACHARSE)
	_asentar_la_vista(jugador)


## Deja pasar más que lo que dura el agache, para medir la postura ya asentada.
func _asentar_la_vista(jugador: CharacterBody3D) -> void:
	jugador.call("_acomodar_la_vista", ReglasDelJugador.DURACION_DEL_AGACHE * 2.0)


func _actualizar(jugador: CharacterBody3D) -> void:
	for cuadro in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
