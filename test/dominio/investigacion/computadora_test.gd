## La computadora del escritorio: si la terminal de ventas está abierta.
##
## **Ni un `Node` en toda la suite.** Abrir y cerrar son decisiones del juego, no
## del motor: escritas en la pantalla nacerían sin test y ningún gate lo diría.
extends GdUnitTestSuite


func test_una_computadora_nueva_esta_cerrada() -> void:
	assert_bool(Computadora.new().abierta()).is_false()


func test_abrir_una_vez_devuelve_true_y_la_segunda_false() -> void:
	# El `false` no es un error: es de lo que se agarra la escena para no volver a suspender al
	# jugador ni a repintar la pantalla en cada clic.
	var computadora := Computadora.new()
	assert_bool(computadora.abrir()).is_true()
	assert_bool(computadora.abrir()).is_false()
	assert_bool(computadora.abierta()).is_true()


func test_cerrar_sin_haber_abierto_devuelve_false() -> void:
	var computadora := Computadora.new()
	assert_bool(computadora.cerrar()).is_false()
	computadora.abrir()
	assert_bool(computadora.cerrar()).is_true()
	assert_bool(computadora.cerrar()).is_false()


func test_reabrir_vuelve_a_encender_la_terminal() -> void:
	var computadora := Computadora.new()
	computadora.abrir()
	computadora.cerrar()
	assert_bool(computadora.abierta()).is_false()
	assert_bool(computadora.abrir()).is_true()
	assert_bool(computadora.abierta()).is_true()


func test_la_conjunta_solo_alterna_con_la_computadora_abierta_y_ofrecida() -> void:  # AC-INV-149
	var computadora := Computadora.new()
	assert_bool(computadora.alternar_la_conjunta()).is_false()
	computadora.ofrecer_la_conjunta(true)
	assert_bool(computadora.alternar_la_conjunta()).is_false()
	computadora.abrir()
	assert_bool(computadora.conjunta()).is_false()
	assert_bool(computadora.alternar_la_conjunta()).is_true()
	assert_bool(computadora.conjunta()).is_true()
	assert_bool(computadora.alternar_la_conjunta()).is_true()
	assert_bool(computadora.conjunta()).is_false()


func test_una_jornada_que_no_la_ofrece_no_cambia_de_pantalla() -> void:  # AC-INV-149
	var computadora := Computadora.new()
	computadora.abrir()
	assert_bool(computadora.conjunta_ofrecida()).is_false()
	assert_bool(computadora.alternar_la_conjunta()).is_false()
	assert_bool(computadora.conjunta()).is_false()


func test_reabrir_o_cambiar_de_jornada_arranca_en_la_pantalla_normal() -> void:  # AC-INV-149
	var computadora := Computadora.new()
	computadora.ofrecer_la_conjunta(true)
	computadora.abrir()
	computadora.alternar_la_conjunta()
	computadora.cerrar()
	assert_bool(computadora.conjunta()).is_false()
	computadora.abrir()
	assert_bool(computadora.conjunta()).is_false()
	computadora.alternar_la_conjunta()
	computadora.ofrecer_la_conjunta(false)
	assert_bool(computadora.conjunta()).is_false()


func test_volver_a_la_normal_solo_cambia_si_estaba_en_la_conjunta() -> void:  # AC-INV-149
	var computadora := Computadora.new()
	computadora.ofrecer_la_conjunta(true)
	computadora.abrir()
	assert_bool(computadora.volver_a_la_normal()).is_false()
	computadora.alternar_la_conjunta()
	assert_bool(computadora.volver_a_la_normal()).is_true()
	assert_bool(computadora.conjunta()).is_false()
