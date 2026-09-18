## La asimetría entre meter la mano y sacarla, que es lo único que este archivo decide.
extends GdUnitTestSuite

const CUADRO := 1.0 / 60.0


func test_meter_la_mano_contra_el_cuerpo_es_instantaneo() -> void:
	# Suavizar el achique dejaría el producto adentro de la madera justo el rato que dura el
	# suavizado, que es el bug que el brazo existe para tapar.
	assert_float(RetornoDeLaMano.siguiente(0.76, 0.2, CUADRO)).is_equal_approx(0.2, 1e-6)


func test_el_achique_no_depende_de_cuanto_dure_el_cuadro() -> void:
	assert_float(RetornoDeLaMano.siguiente(0.76, 0.2, 1.0)).is_equal_approx(0.2, 1e-6)


func test_sacar_la_mano_no_llega_en_un_solo_cuadro() -> void:
	# Es el tirón que se ve al pasar por la esquina de un mueble: el brazo contesta el largo
	# entero de golpe y la mano lo seguía en un cuadro.
	var siguiente := RetornoDeLaMano.siguiente(0.2, 0.76, CUADRO)
	assert_float(siguiente).is_greater(0.2)
	assert_float(siguiente).is_less(0.76)


func test_sacar_la_mano_converge_al_largo_libre() -> void:
	var largo := 0.2
	for cuadro in 120:
		largo = RetornoDeLaMano.siguiente(largo, 0.76, CUADRO)
	assert_float(largo).is_equal_approx(0.76, 0.001)


func test_un_cuadro_mas_largo_avanza_mas() -> void:
	# Sin esto el retorno iría al doble de velocidad a 120 cuadros por segundo que a 60.
	var corto := RetornoDeLaMano.siguiente(0.2, 0.76, CUADRO)
	var largo := RetornoDeLaMano.siguiente(0.2, 0.76, CUADRO * 4.0)
	assert_float(largo).is_greater(corto)


func test_sin_nada_que_recorrer_el_largo_no_se_mueve() -> void:
	assert_float(RetornoDeLaMano.siguiente(0.76, 0.76, CUADRO)).is_equal_approx(0.76, 1e-6)


func test_el_tiempo_de_vuelta_es_corto_y_positivo() -> void:
	# Un valor grande se lee como que la mano se arrastra; uno nulo apaga el suavizado entero.
	assert_float(RetornoDeLaMano.TIEMPO_DE_VUELTA).is_greater(0.0)
	assert_float(RetornoDeLaMano.TIEMPO_DE_VUELTA).is_less(0.5)


func test_un_largo_nulo_no_es_una_respuesta_y_deja_la_mano_donde_esta() -> void:
	# Está medido: el brazo del motor contesta `0` hasta que barre por primera vez. Tomarlo al
	# pie dejaba la mano saliendo del hombro en el primer cuadro de cada jornada.
	assert_float(RetornoDeLaMano.siguiente(0.76, 0.0, CUADRO)).is_equal_approx(0.76, 1e-6)
