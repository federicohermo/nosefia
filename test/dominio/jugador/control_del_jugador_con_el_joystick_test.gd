## El joystick derecho gira la vista: la regla vive en el control y recibe la inclinación y los
## segundos del paso, sin levantar una escena.
extends GdUnitTestSuite

const ControlDelJugador := preload("res://src/dominio/jugador/control_del_jugador.gd")
const Mirada := preload("res://src/dominio/jugador/mirada.gd")
const ReglasDelJugador := preload("res://src/dominio/jugador/reglas_del_jugador.gd")

const SENSIBILIDAD := 0.01
const A_LA_DERECHA := Vector2(1.0, 0.0)
const HACIA_ARRIBA := Vector2(0.0, -1.0)
const HACIA_ABAJO := Vector2(0.0, 1.0)


func _control() -> ControlDelJugador:
	var mirada := Mirada.new(
		SENSIBILIDAD, ReglasDelJugador.PITCH_MINIMO, ReglasDelJugador.PITCH_MAXIMO
	)
	return ControlDelJugador.new(mirada, ReglasDelJugador.VELOCIDAD_DE_CAMINATA)


func test_a_fondo_a_la_derecha_la_vista_gira_a_la_velocidad_a_fondo() -> void:  # AC-PLY-172
	var control := _control()
	control.girar_con_el_joystick(A_LA_DERECHA, 0.5)
	assert_float(control.yaw()).is_equal_approx(-ReglasDelJugador.GIRO_DEL_JOYSTICK * 0.5, 1e-5)
	assert_float(control.pitch()).is_equal(0.0)


func test_a_la_mitad_de_la_inclinacion_gira_la_mitad() -> void:  # AC-PLY-172
	var control := _control()
	control.girar_con_el_joystick(A_LA_DERECHA * 0.5, 0.5)
	assert_float(control.yaw()).is_equal_approx(-ReglasDelJugador.GIRO_DEL_JOYSTICK * 0.25, 1e-5)


func test_a_inclinacion_cero_no_gira() -> void:  # AC-PLY-172
	var control := _control()
	control.girar_con_el_joystick(Vector2.ZERO, 1.0)
	assert_float(control.yaw()).is_equal(0.0)
	assert_float(control.pitch()).is_equal(0.0)


func test_a_fondo_hacia_arriba_o_abajo_el_pitch_se_clava() -> void:  # AC-PLY-173
	var control := _control()
	control.girar_con_el_joystick(HACIA_ARRIBA, 2.0)
	assert_float(control.pitch()).is_equal(ReglasDelJugador.PITCH_MAXIMO)
	control.girar_con_el_joystick(HACIA_ARRIBA, 1.0 / 60.0)
	assert_float(control.pitch()).is_equal(ReglasDelJugador.PITCH_MAXIMO)
	control.girar_con_el_joystick(HACIA_ABAJO, 4.0)
	assert_float(control.pitch()).is_equal(ReglasDelJugador.PITCH_MINIMO)


func test_el_mouse_y_el_joystick_en_el_mismo_paso_se_suman() -> void:  # AC-PLY-174
	var control := _control()
	control.girar(Vector2(100.0, 0.0))
	var del_mouse := control.yaw()
	control.girar_con_el_joystick(A_LA_DERECHA, 0.5)
	assert_float(control.yaw()).is_equal_approx(
		del_mouse - ReglasDelJugador.GIRO_DEL_JOYSTICK * 0.5, 1e-5
	)


func test_el_giro_del_joystick_no_atrasa_el_dibujo() -> void:  # AC-PLY-172
	var control := _control()
	control.girar_con_el_joystick(A_LA_DERECHA, 0.1)
	assert_bool(control.giro_atrasado()).is_false()
	assert_float(control.yaw_dibujado()).is_equal_approx(control.yaw(), 1e-5)


func test_suspendido_el_joystick_no_gira() -> void:  # AC-PLY-175
	var control := _control()
	control.suspender()
	control.girar_con_el_joystick(A_LA_DERECHA, 1.0)
	control.girar_con_el_joystick(HACIA_ARRIBA, 1.0)
	assert_float(control.yaw()).is_equal(0.0)
	assert_float(control.pitch()).is_equal(0.0)
	control.reanudar()
	control.girar_con_el_joystick(A_LA_DERECHA, 0.5)
	assert_float(control.yaw()).is_not_equal(0.0)
