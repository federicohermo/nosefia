## Cómo se mueve la vista entre las dos alturas: sin salto, en una fracción de segundo, y desde
## donde esté.
extends GdUnitTestSuite

const CUADRO := 1.0 / 60.0


func test_un_cuadro_no_alcanza_para_bajar() -> void:  # AC-PLY-128
	var altura := TransicionDeLaVista.siguiente(
		ReglasDelJugador.ALTURA_DE_LA_CAMARA, ReglasDelJugador.ALTURA_AGACHADO, CUADRO
	)
	assert_float(altura).is_less(ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	assert_float(altura).is_greater(ReglasDelJugador.ALTURA_AGACHADO)


func test_un_cuadro_no_alcanza_para_subir() -> void:  # AC-PLY-128
	var altura := TransicionDeLaVista.siguiente(
		ReglasDelJugador.ALTURA_AGACHADO, ReglasDelJugador.ALTURA_DE_LA_CAMARA, CUADRO
	)
	assert_float(altura).is_greater(ReglasDelJugador.ALTURA_AGACHADO)
	assert_float(altura).is_less(ReglasDelJugador.ALTURA_DE_LA_CAMARA)


func test_la_bajada_y_la_subida_llegan_en_lo_que_dura_el_agache() -> void:  # AC-PLY-128
	var altura := ReglasDelJugador.ALTURA_DE_LA_CAMARA
	for cuadro in roundi(ReglasDelJugador.DURACION_DEL_AGACHE / CUADRO) + 1:
		altura = TransicionDeLaVista.siguiente(altura, ReglasDelJugador.ALTURA_AGACHADO, CUADRO)
	assert_float(altura).is_equal_approx(ReglasDelJugador.ALTURA_AGACHADO, 1e-5)
	for cuadro in roundi(ReglasDelJugador.DURACION_DEL_AGACHE / CUADRO) + 1:
		altura = TransicionDeLaVista.siguiente(altura, ReglasDelJugador.ALTURA_DE_LA_CAMARA, CUADRO)
	assert_float(altura).is_equal_approx(ReglasDelJugador.ALTURA_DE_LA_CAMARA, 1e-5)


func test_nunca_se_pasa_de_la_altura_destino() -> void:  # AC-PLY-128
	(
		assert_float(
			TransicionDeLaVista.siguiente(
				ReglasDelJugador.ALTURA_DE_LA_CAMARA, ReglasDelJugador.ALTURA_AGACHADO, 10.0
			)
		)
		. is_equal(ReglasDelJugador.ALTURA_AGACHADO)
	)
	(
		assert_float(
			TransicionDeLaVista.siguiente(
				ReglasDelJugador.ALTURA_AGACHADO, ReglasDelJugador.ALTURA_DE_LA_CAMARA, 10.0
			)
		)
		. is_equal(ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	)


func test_soltar_a_mitad_de_la_bajada_sube_desde_donde_esta() -> void:  # AC-PLY-129
	var mitad := TransicionDeLaVista.siguiente(
		ReglasDelJugador.ALTURA_DE_LA_CAMARA,
		ReglasDelJugador.ALTURA_AGACHADO,
		ReglasDelJugador.DURACION_DEL_AGACHE / 2.0
	)
	var sube := TransicionDeLaVista.siguiente(mitad, ReglasDelJugador.ALTURA_DE_LA_CAMARA, CUADRO)
	assert_float(sube).is_greater(mitad)
	assert_float(sube - mitad).is_less(
		ReglasDelJugador.ALTURA_DE_LA_CAMARA - ReglasDelJugador.ALTURA_AGACHADO
	)


func test_la_misma_duracion_da_la_misma_altura_con_cualquier_cuadro() -> void:  # AC-PLY-128
	var en_dos := ReglasDelJugador.ALTURA_DE_LA_CAMARA
	for cuadro in 2:
		en_dos = TransicionDeLaVista.siguiente(en_dos, ReglasDelJugador.ALTURA_AGACHADO, CUADRO)
	var en_uno := TransicionDeLaVista.siguiente(
		ReglasDelJugador.ALTURA_DE_LA_CAMARA, ReglasDelJugador.ALTURA_AGACHADO, CUADRO * 2.0
	)
	assert_float(en_dos).is_equal_approx(en_uno, 1e-5)


func test_la_duracion_es_una_fraccion_de_segundo() -> void:  # AC-PLY-128
	# Una duración nula es el salto de antes; una larga se lee como que el jugador se arrastra.
	assert_float(ReglasDelJugador.DURACION_DEL_AGACHE).is_greater(0.0)
	assert_float(ReglasDelJugador.DURACION_DEL_AGACHE).is_less(0.5)
