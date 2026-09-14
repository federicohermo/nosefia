## La computadora del escritorio: si está abierta y en qué app.
##
## **Ni un `Node` en toda la suite.** Abrir, cerrar y cambiar de app son decisiones del juego, no
## del motor: escritas en la pantalla nacerían sin test y ningún gate lo diría.
extends GdUnitTestSuite


func test_una_computadora_nueva_esta_cerrada() -> void:  # 009-AC1
	assert_bool(Computadora.new().abierta()).is_false()


func test_abrir_una_vez_devuelve_true_y_la_segunda_false() -> void:  # 009-AC1
	# El `false` no es un error: es de lo que se agarra la escena para no volver a suspender al
	# jugador ni a repintar la pantalla en cada clic.
	var computadora := Computadora.new()
	assert_bool(computadora.abrir()).is_true()
	assert_bool(computadora.abrir()).is_false()
	assert_bool(computadora.abierta()).is_true()


func test_cerrar_sin_haber_abierto_devuelve_false() -> void:  # 009-AC1
	var computadora := Computadora.new()
	assert_bool(computadora.cerrar()).is_false()
	computadora.abrir()
	assert_bool(computadora.cerrar()).is_true()
	assert_bool(computadora.cerrar()).is_false()


func test_cambiar_a_la_misma_app_devuelve_false() -> void:  # 009-AC1
	var computadora := Computadora.new()
	computadora.abrir()
	assert_bool(computadora.cambiar_a(computadora.app())).is_false()
	assert_bool(computadora.cambiar_a(Computadora.App.CHATS)).is_true()
	assert_int(computadora.app()).is_equal(Computadora.App.CHATS)


func test_cambiar_de_app_con_la_computadora_cerrada_devuelve_false() -> void:  # 009-AC1
	# Con la pantalla apagada no hay a qué cambiar, y dejar que cambie igual haría que reabrir
	# apareciera en una app que el jugador nunca eligió.
	var computadora := Computadora.new()
	var arranque := computadora.app()
	assert_bool(computadora.cambiar_a(Computadora.App.NOTAS)).is_false()
	assert_int(computadora.app()).is_equal(arranque)


func test_reabrir_vuelve_a_la_app_donde_se_habia_dejado() -> void:  # 009-AC1
	# Es lo que hace que ir a atender y volver no cueste dos clics de más — o sea, tiempo de
	# turno por una decisión de pantalla.
	var computadora := Computadora.new()
	computadora.abrir()
	computadora.cambiar_a(Computadora.App.NOTAS)
	computadora.cerrar()
	computadora.abrir()
	assert_int(computadora.app()).is_equal(Computadora.App.NOTAS)


func test_las_tres_apps_del_gdd_estan_declaradas() -> void:  # 009-AC1
	# Tres y no una cantidad cualquiera: la caja es tarea del jefe y los chats y las notas son
	# investigación. Es lo que pone las dos puntas de la tensión a un clic una de otra.
	assert_int(Computadora.App.size()).is_equal(3)
