## Los valores fijos de limpiar, y las dos relaciones que los vuelven jugables.
##
## **Ninguno de los dos casos afirma el número**: afirman contra qué tiene que estar. Un test que
## dijera «tres» se pondría en rojo al rebalancear sin que nada esté mal.
extends GdUnitTestSuite


func test_una_mancha_no_se_limpia_en_el_instante_en_que_el_jugador_llega() -> void:  # 014-AC1
	# El piso es 2: con una sola pasada limpiar volvería a ser un clic, y un clic no compite
	# contra investigar porque no hay nada que repartir.
	(
		assert_int(ReglasDeLaLimpieza.PASADAS_POR_MANCHA)
		. override_failure_message("con una sola pasada la mancha se limpia al llegar")
		. is_greater_equal(2)
	)


func test_desde_una_mancha_la_mira_no_llega_a_la_siguiente() -> void:  # 014-AC1
	# **Estrictamente mayor**, y ahí está el término que esta tarea aporta a la resta del turno:
	# si la distancia fuera menor o igual, desde una mancha se podría enfocar la siguiente y los
	# tres tramos de caminata dejarían de existir sin que nada lo dijera.
	(
		assert_float(ReglasDeLaLimpieza.DISTANCIA_MINIMA_ENTRE_MANCHAS)
		. override_failure_message(
			(
				"las manchas están a %.2f m y la mira alcanza %.2f m"
				% [
					ReglasDeLaLimpieza.DISTANCIA_MINIMA_ENTRE_MANCHAS,
					ReglasDelJugador.ALCANCE_DE_LA_MIRA
				]
			)
		)
		. is_greater(ReglasDelJugador.ALCANCE_DE_LA_MIRA)
	)


func test_el_trapeador_tiene_un_id_que_no_es_el_centinela_de_mano_vacia() -> void:  # 014-AC1
	# Con `SIN_ID` como `id` del trapeador, limpiar con las manos vacías funcionaría.
	assert_str(ReglasDeLaLimpieza.ID_DEL_TRAPEADOR).is_not_equal(ObjetoDelAlmacen.SIN_ID)
