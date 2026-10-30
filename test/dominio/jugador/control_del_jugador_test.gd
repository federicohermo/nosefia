## El estado del control, y el interruptor que lo suspende entero.
##
## Suspender es un modo, no un frenado por cuadro: cuando llega un comprador, la cámara y la
## locomoción quedan clavadas durante toda la atención. Estos casos afirman las cuatro cosas que
## «suspendido» quiere decir a la vez, que es lo que permite que la ventanilla y la computadora
## digan «el jugador no controla» sin enterarse de que adentro hay un yaw, un vector y un rayo.
extends GdUnitTestSuite

const ControlDelJugador := preload("res://src/dominio/jugador/control_del_jugador.gd")
const Foco := preload("res://src/dominio/jugador/foco.gd")
const Mirada := preload("res://src/dominio/jugador/mirada.gd")
const ReglasDelJugador := preload("res://src/dominio/jugador/reglas_del_jugador.gd")

## La sensibilidad de prueba es `0.01` y no la del juego, por lo mismo que en `mirada_test.gd`:
## da números redondos y ajustar el tacto no pone en rojo un test que no habla del tacto.
const SENSIBILIDAD := 0.01

const UN_OBJETO := 26558334344


func _control() -> ControlDelJugador:
	var mirada := Mirada.new(
		SENSIBILIDAD, ReglasDelJugador.PITCH_MINIMO, ReglasDelJugador.PITCH_MAXIMO
	)
	return ControlDelJugador.new(mirada, ReglasDelJugador.VELOCIDAD_DE_CAMINATA)


func test_suspendido_no_gira_la_camara() -> void:  # AC-PLY-007
	var control := _control()
	control.girar(Vector2(100.0, 100.0))
	var yaw_antes := control.yaw()
	var pitch_antes := control.pitch()
	control.suspender()
	assert_bool(control.esta_suspendido()).is_true()
	control.girar(Vector2(500.0, 500.0))
	assert_float(control.yaw()).is_equal(yaw_antes)
	assert_float(control.pitch()).is_equal(pitch_antes)


func test_suspendido_devuelve_velocidad_cero_aunque_la_entrada_no_sea_nula() -> void:  # AC-PLY-007
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


func test_suspendido_la_mira_no_enfoca() -> void:  # AC-PLY-007
	var control := _control()
	control.suspender()
	assert_bool(control.observar(UN_OBJETO, 2.0, true)).is_false()
	assert_int(control.objetivo()).is_equal(Foco.SIN_OBJETIVO)


func test_suspendido_no_pide_el_cursor_y_al_reanudar_lo_vuelve_a_pedir() -> void:  # AC-PLY-007
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


func test_con_un_mouse_rapido_el_dibujo_es_la_mirada() -> void:
	var control := _control()
	control.girar(Vector2(10.0, 5.0))
	assert_float(control.yaw_dibujado()).is_equal(control.yaw())
	assert_float(control.pitch_dibujado()).is_equal(control.pitch())
	assert_bool(control.giro_atrasado()).is_false()


func test_con_un_mouse_lento_el_dibujo_alcanza_a_la_mirada_en_la_ventana() -> void:
	# Hacia adónde se camina no espera al dibujo: sólo la cámara se atrasa.
	var control := _lento()
	var yaw := control.yaw()
	var pitch := control.pitch()
	control.girar(Vector2(10.0, 5.0))
	assert_float(control.yaw()).is_equal_approx(yaw - 0.1, 1e-6)
	assert_float(control.yaw_dibujado()).is_equal_approx(yaw, 1e-6)
	assert_float(control.pitch_dibujado()).is_equal_approx(pitch, 1e-6)
	assert_bool(control.giro_atrasado()).is_true()
	control.avanzar_el_dibujo(SuavizadoDelGiro.VENTANA / 2.0)
	assert_float(control.yaw_dibujado()).is_equal_approx(yaw - 0.05, 1e-6)
	assert_float(control.pitch_dibujado()).is_equal_approx(pitch - 0.025, 1e-6)
	control.avanzar_el_dibujo(SuavizadoDelGiro.VENTANA)
	assert_float(control.yaw_dibujado()).is_equal_approx(control.yaw(), 1e-6)
	assert_float(control.pitch_dibujado()).is_equal_approx(control.pitch(), 1e-6)
	assert_bool(control.giro_atrasado()).is_false()


func test_contra_el_tope_del_pitch_el_dibujo_no_rebota() -> void:
	# Lo que la mirada no aplicó no se dibuja. Si no, empujar contra el tope bajaba la cámara y
	# la volvía a subir.
	var control := _lento()
	control.girar(Vector2(0.0, -1000.0))
	control.avanzar_el_dibujo(SuavizadoDelGiro.VENTANA)
	control.girar(Vector2(0.0, -50.0))
	assert_float(control.pitch_dibujado()).is_equal_approx(ReglasDelJugador.PITCH_MAXIMO, 1e-6)


func test_girar_en_redondo_no_dibuja_la_vuelta_larga() -> void:
	# El yaw da la vuelta en PI. Sin eso, cruzarlo dibujaba un giro de casi una vuelta entera.
	var control := _lento()
	control.girar(Vector2(wrapf(control.yaw() + PI - 0.05, -PI, PI) / SENSIBILIDAD, 0.0))
	control.avanzar_el_dibujo(SuavizadoDelGiro.VENTANA)
	control.girar(Vector2(10.0, 0.0))
	control.avanzar_el_dibujo(SuavizadoDelGiro.VENTANA / 2.0)
	assert_float(absf(wrapf(control.yaw_dibujado() - control.yaw(), -PI, PI))).is_less(0.06)


func test_suspendido_el_dibujo_no_se_mueve() -> void:
	var control := _lento()
	var yaw := control.yaw()
	control.suspender()
	control.girar(Vector2(100.0, 100.0))
	control.avanzar_el_dibujo(SuavizadoDelGiro.VENTANA / 2.0)
	assert_float(control.yaw_dibujado()).is_equal(yaw)


func test_orientar_deja_el_dibujo_en_la_mirada_nueva() -> void:  # AC-PLY-044
	# Con un giro pendiente de dibujar, la cámara arrancaría la noche girando desde donde quedó.
	var control := _lento()
	control.girar(Vector2(10.0, 5.0))
	control.orientar(1.0)
	assert_float(control.yaw()).is_equal_approx(1.0, 1e-6)
	assert_float(control.pitch()).is_equal(0.0)
	assert_float(control.yaw_dibujado()).is_equal_approx(1.0, 1e-6)
	assert_float(control.pitch_dibujado()).is_equal(0.0)
	assert_bool(control.giro_atrasado()).is_false()


## Un control que ya vio un mouse de 125 Hz a 144 cuadros, con el dibujo al día.
func _lento() -> ControlDelJugador:
	var control := _control()
	var cuadro := 1.0 / 144.0
	var tiempo := 0.0
	var proximo := 0.0
	for indice in 300:
		while proximo <= tiempo:
			control.girar(Vector2(0.1, 0.0))
			proximo += 1.0 / 125.0
		control.avanzar_el_dibujo(cuadro)
		tiempo += cuadro
	control.avanzar_el_dibujo(SuavizadoDelGiro.VENTANA)
	return control


func test_agachado_la_vista_baja_a_la_altura_agachado() -> void:  # AC-PLY-120
	var control := _control()
	assert_float(_asentar(control, false)).is_equal(ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	assert_float(_asentar(control, true)).is_equal(ReglasDelJugador.ALTURA_AGACHADO)


func test_soltar_la_accion_levanta_la_vista_y_no_es_un_interruptor() -> void:  # AC-PLY-121
	var control := _control()
	_asentar(control, true)
	assert_float(_asentar(control, false)).is_equal(ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	assert_float(_asentar(control, false)).is_equal(ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	assert_float(_asentar(control, true)).is_equal(ReglasDelJugador.ALTURA_AGACHADO)


func test_la_vista_baja_de_a_poco_y_no_de_un_salto() -> void:  # AC-PLY-128
	var control := _control()
	var altura := control.altura_de_la_vista(true, CUADRO)
	assert_float(altura).is_less(ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	assert_float(altura).is_greater(ReglasDelJugador.ALTURA_AGACHADO)
	assert_float(control.altura_de_la_vista(true, CUADRO)).is_less(altura)


func test_soltar_a_mitad_de_la_bajada_sube_desde_donde_esta() -> void:  # AC-PLY-129
	var control := _control()
	var mitad := control.altura_de_la_vista(true, ReglasDelJugador.DURACION_DEL_AGACHE / 2.0)
	var sube := control.altura_de_la_vista(false, CUADRO)
	assert_float(sube).is_greater(mitad)
	assert_float(sube).is_less(ReglasDelJugador.ALTURA_DE_LA_CAMARA)


func test_agachado_se_camina_a_la_velocidad_de_pie() -> void:  # AC-PLY-123
	var control := _control()
	var de_pie := control.velocidad(Vector2(0.0, 1.0)).length()
	control.altura_de_la_vista(true)
	assert_float(control.velocidad(Vector2(0.0, 1.0)).length()).is_equal_approx(de_pie, 1e-5)
	assert_float(control.velocidad(Vector2(1.0, 1.0)).length()).is_equal_approx(
		ReglasDelJugador.VELOCIDAD_DE_CAMINATA, 1e-4
	)


func test_suspendido_la_postura_no_cambia_y_al_reanudar_sigue_a_la_accion() -> void:  # AC-PLY-124
	var control := _control()
	_asentar(control, true)
	control.suspender()
	assert_float(_asentar(control, false)).is_equal(ReglasDelJugador.ALTURA_AGACHADO)
	control.reanudar()
	assert_float(_asentar(control, false)).is_equal(ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	control.suspender()
	assert_float(_asentar(control, true)).is_equal(ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	control.reanudar()
	assert_float(_asentar(control, true)).is_equal(ReglasDelJugador.ALTURA_AGACHADO)


## La altura con la acción como esté, dejando pasar más que lo que dura el agache.
func _asentar(control: ControlDelJugador, agachando: bool) -> float:
	return control.altura_de_la_vista(agachando, ReglasDelJugador.DURACION_DEL_AGACHE * 2.0)
