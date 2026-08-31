## El estado del control, y el interruptor que lo suspende entero.
##
## Suspender es un modo, no un frenado por cuadro: cuando llega un comprador, la cámara y la
## locomoción quedan clavadas durante toda la atención. Estos casos afirman las cuatro cosas que
## «suspendido» quiere decir a la vez, que es lo que permite que la ventanilla y la computadora
## digan «el jugador no controla» sin enterarse de que adentro hay un yaw, un vector y un rayo.
extends GdUnitTestSuite

const ControlDelJugador := preload("res://src/dominio/control_del_jugador.gd")
const Foco := preload("res://src/dominio/foco.gd")
const Mirada := preload("res://src/dominio/mirada.gd")
const ReglasDelJugador := preload("res://src/dominio/reglas_del_jugador.gd")

## La sensibilidad de prueba es `0.01` y no la del juego, por lo mismo que en `mirada_test.gd`:
## da números redondos y ajustar el tacto no pone en rojo un test que no habla del tacto.
const SENSIBILIDAD := 0.01

const UN_OBJETO := 26558334344


func _control() -> ControlDelJugador:
	var mirada := Mirada.new(
		SENSIBILIDAD, ReglasDelJugador.PITCH_MINIMO, ReglasDelJugador.PITCH_MAXIMO
	)
	return ControlDelJugador.new(mirada, ReglasDelJugador.VELOCIDAD_DE_CAMINATA)


func test_suspendido_no_gira_la_camara() -> void:
	var control := _control()
	control.girar(Vector2(100.0, 100.0))
	var yaw_antes := control.yaw()
	var pitch_antes := control.pitch()
	control.suspender()
	assert_bool(control.esta_suspendido()).is_true()
	control.girar(Vector2(500.0, 500.0))
	assert_float(control.yaw()).is_equal(yaw_antes)
	assert_float(control.pitch()).is_equal(pitch_antes)


func test_suspendido_devuelve_velocidad_cero_aunque_la_entrada_no_sea_nula() -> void:
	var control := _control()
	control.suspender()
	assert_vector(control.velocidad(Vector2(0.0, 1.0))).is_equal(Vector3.ZERO)


func test_reanudar_devuelve_el_giro_y_la_caminata() -> void:
	# La suspensión no rompe el estado: lo congela. Si al reanudar el yaw hubiera que volver a
	# calibrarlo, cada atención dejaría la cámara en otro lado.
	var control := _control()
	control.suspender()
	control.girar(Vector2(500.0, 500.0))
	control.reanudar()
	assert_bool(control.esta_suspendido()).is_false()
	control.girar(Vector2(100.0, 0.0))
	assert_float(control.yaw()).is_equal_approx(-1.0, 1e-5)
	assert_float(control.velocidad(Vector2(0.0, 1.0)).length()).is_equal_approx(
		ReglasDelJugador.VELOCIDAD_DE_CAMINATA, 1e-4
	)


func test_suspender_suelta_el_objetivo_que_estaba_enfocado() -> void:
	# Sin esto la mira seguiría hablando durante la atención: `jugador.gd` emite
	# `objetivo_perdido` una vez y después se calla, que es lo que se quiere.
	var control := _control()
	control.observar(UN_OBJETO, 2.0, true)
	control.suspender()
	assert_int(control.objetivo()).is_equal(Foco.SIN_OBJETIVO)
	assert_bool(control.hay_interactuable()).is_false()


func test_suspendido_la_mira_no_enfoca() -> void:
	var control := _control()
	control.suspender()
	assert_bool(control.observar(UN_OBJETO, 2.0, true)).is_false()
	assert_int(control.objetivo()).is_equal(Foco.SIN_OBJETIVO)


func test_suspendido_no_pide_el_cursor_y_al_reanudar_lo_vuelve_a_pedir() -> void:
	# Es un `bool` y no un `Input.MOUSE_MODE_*` porque `dominio/` no nombra `Input`: acá se
	# decide SI, y en `src/escenas/jugador.gd` se traduce a QUÉ.
	var control := _control()
	control.suspender()
	assert_bool(control.quiere_el_cursor_tomado()).is_false()
	control.reanudar()
	assert_bool(control.quiere_el_cursor_tomado()).is_true()


func test_la_mira_sigue_avisando_cuando_no_esta_suspendido() -> void:
	# El testigo de que suspender apaga algo que de otro modo funciona: sin este caso, un
	# `observar()` que devolviera siempre `false` pasaría los dos de arriba.
	var control := _control()
	assert_bool(control.observar(UN_OBJETO, 2.0, true)).is_true()
	assert_int(control.objetivo()).is_equal(UN_OBJETO)
