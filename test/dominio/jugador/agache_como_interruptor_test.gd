## Agacharse es un interruptor: apretar una vez agacha, apretar otra vez para. Lo que no es la
## postura —la altura, la velocidad, la mira— se prueba en `control_del_jugador_test.gd`.
extends GdUnitTestSuite

const CUADRO := 1.0 / 60.0


func _control() -> ControlDelJugador:
	var mirada := Mirada.new(0.01, ReglasDelJugador.PITCH_MINIMO, ReglasDelJugador.PITCH_MAXIMO)
	return ControlDelJugador.new(mirada, ReglasDelJugador.VELOCIDAD_DE_CAMINATA)


func test_mantener_apretada_la_accion_no_alterna_cuadro_a_cuadro() -> void:  # AC-PLY-121
	var control := _control()
	var altura := 0.0
	for cuadro in 60:
		altura = control.altura_de_la_vista(true, CUADRO)
	assert_float(altura).is_equal(ReglasDelJugador.ALTURA_AGACHADO)
	for cuadro in 60:
		altura = control.altura_de_la_vista(false, CUADRO)
	assert_float(altura).is_equal(ReglasDelJugador.ALTURA_AGACHADO)


func test_agachado_sigue_agachado_al_soltar_la_accion_y_camina_lento() -> void:  # AC-PLY-130
	var control := _control()
	_asentar(control, true)
	_asentar(control, false)
	assert_float(control.velocidad(Vector2(0.0, 1.0)).length()).is_equal_approx(
		ReglasDelJugador.VELOCIDAD_AGACHADO, 1e-4
	)


func test_con_la_accion_apretada_al_suspender_reanudar_no_alterna() -> void:  # AC-PLY-124
	var control := _control()
	_asentar(control, true)
	control.suspender()
	_asentar(control, true)
	control.reanudar()
	assert_float(_asentar(control, true)).is_equal(ReglasDelJugador.ALTURA_AGACHADO)


func test_ponerse_de_pie_deja_la_vista_y_la_velocidad_de_pie() -> void:  # AC-PLY-198
	var control := _control()
	_asentar(control, true)
	_asentar(control, false)
	control.ponerse_de_pie()
	assert_float(_asentar(control, false)).is_equal(ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	assert_float(control.velocidad(Vector2(0.0, 1.0)).length()).is_equal_approx(
		ReglasDelJugador.VELOCIDAD_DE_CAMINATA, 1e-4
	)


func test_correr_agachado_sigue_siendo_correr_con_peso() -> void:  # AC-PLY-194
	var control := _control()
	_asentar(control, true)
	_asentar(control, false)
	assert_float(control.velocidad(Vector2(0.0, 1.0), true).length()).is_equal_approx(
		ReglasDelJugador.VELOCIDAD_AGACHADO * ReglasDelJugador.MULTIPLICADOR_DE_CORRER_CON_PESO,
		1e-4
	)


## La altura con la acción como esté, dejando pasar más que lo que dura el agache.
func _asentar(control: ControlDelJugador, apretada: bool) -> float:
	return control.altura_de_la_vista(apretada, ReglasDelJugador.DURACION_DEL_AGACHE * 2.0)
