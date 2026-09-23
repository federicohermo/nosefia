## La aritmética del trayecto: viajes y si un punto entra en la zona.
##
## **Ningún caso levanta una escena**: si alguno la necesitara, la regla estaría en el lugar
## equivocado.
extends GdUnitTestSuite


func test_con_una_mano_cada_bolsa_es_un_viaje() -> void:  # AC-CLN-007
	assert_int(Trayecto.viajes(3, 1)).is_equal(3)


func test_con_tantas_manos_como_bolsas_alcanza_un_viaje() -> void:
	assert_int(Trayecto.viajes(3, 3)).is_equal(1)


func test_los_viajes_redondean_para_arriba() -> void:
	# Con cuatro bolsas y tres manos son dos viajes, no uno y pico: la bolsa que sobra hay que ir
	# a buscarla igual.
	assert_int(Trayecto.viajes(4, 3)).is_equal(2)


func test_sin_manos_o_sin_bolsas_no_hay_viajes() -> void:
	# No es un caso del juego: es el que evita que un balance mal escrito divida por cero y se
	# lleve puesta la corrida entera.
	assert_int(Trayecto.viajes(3, 0)).is_equal(0)
	assert_int(Trayecto.viajes(0, 1)).is_equal(0)


func test_el_borde_de_la_zona_entra() -> void:  # AC-CLN-009
	# Es un `<=`: con un `<`, la bolsa apoyada justo en el límite no contaría y el jugador no
	# tendría cómo distinguir eso de haberla dejado mal.
	assert_bool(Trayecto.dentro_del_descarte(1.5, 1.5)).is_true()
	assert_bool(Trayecto.dentro_del_descarte(1.4999, 1.5)).is_true()
	assert_bool(Trayecto.dentro_del_descarte(1.5001, 1.5)).is_false()
