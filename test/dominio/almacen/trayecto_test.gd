## La aritmética del trayecto: viajes, segundos y si un punto entra en la zona.
##
## **Ningún caso levanta una escena**: si alguno la necesitara, la regla estaría en el lugar
## equivocado. Los números son inventados salvo por uno que no se ve en la llamada:
## `segundos_minimos()` le pide las manos a `ReglasDeLosObjetos`, así que el `24.0` de abajo se
## mueve si el balance sube esa constante. Está dicho acá porque el caso no lo deja ver.
extends GdUnitTestSuite


func test_con_una_mano_cada_bolsa_es_un_viaje() -> void:  # 015-AC1
	assert_int(Trayecto.viajes(3, 1)).is_equal(3)


func test_con_tantas_manos_como_bolsas_alcanza_un_viaje() -> void:  # 015-AC1
	assert_int(Trayecto.viajes(3, 3)).is_equal(1)


func test_los_viajes_redondean_para_arriba() -> void:  # 015-AC1
	# Con cuatro bolsas y tres manos son dos viajes, no uno y pico: la bolsa que sobra hay que ir
	# a buscarla igual.
	assert_int(Trayecto.viajes(4, 3)).is_equal(2)


func test_sin_manos_o_sin_bolsas_no_hay_viajes() -> void:  # 015-AC1
	# No es un caso del juego: es el que evita que un balance mal escrito divida por cero y se
	# lleve puesta la corrida entera.
	assert_int(Trayecto.viajes(3, 0)).is_equal(0)
	assert_int(Trayecto.viajes(0, 1)).is_equal(0)


func test_los_segundos_minimos_son_la_ida_y_la_vuelta_de_cada_viaje() -> void:  # 015-AC1
	# 12 m a 3 m/s son 4 s de ida, 8 de ida y vuelta, por tres viajes: 24.
	assert_float(Trayecto.segundos_minimos(12.0, 3.0, 3)).is_equal(24.0)


func test_sin_velocidad_no_se_divide_por_cero() -> void:  # 015-AC1
	assert_float(Trayecto.segundos_minimos(12.0, 0.0, 3)).is_equal(0.0)


func test_el_borde_de_la_zona_entra() -> void:  # 015-AC1
	# Es un `<=`: con un `<`, la bolsa apoyada justo en el límite no contaría y el jugador no
	# tendría cómo distinguir eso de haberla dejado mal.
	assert_bool(Trayecto.dentro_del_descarte(1.5, 1.5)).is_true()
	assert_bool(Trayecto.dentro_del_descarte(1.4999, 1.5)).is_true()
	assert_bool(Trayecto.dentro_del_descarte(1.5001, 1.5)).is_false()


func test_el_trayecto_estimado_del_011_cubre_al_menos_esta_tarea_sola() -> void:  # 015-AC3
	# **Es el AC que este spec le debe al 011**: aquel número se declaró contando con esta tarea y
	# no tenía con qué cruzarse, porque la mecánica no existía. Es un `>=` y no una igualdad —
	# `segundos_minimos()` mide la línea recta y el camino real es más largo—, así que lo que caza
	# es un presupuesto de trayecto que ni siquiera alcanza para el piso de una sola obligatoria.
	var piso := Trayecto.segundos_minimos(
		ReglasDeLaBasura.DISTANCIA_MINIMA_AL_DESCARTE,
		ReglasDelJugador.VELOCIDAD_DE_CAMINATA,
		ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA
	)
	(
		assert_float(Reglas.SEGUNDOS_DE_TRAYECTO_ESTIMADOS)
		. override_failure_message(
			(
				"el trayecto estimado son %.1f s y sacar la basura ya pide %.1f s"
				% [Reglas.SEGUNDOS_DE_TRAYECTO_ESTIMADOS, piso]
			)
		)
		. is_greater_equal(piso)
	)
