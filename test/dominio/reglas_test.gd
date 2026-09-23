## Los valores fijos del juego, y lo que sí se puede verificar de un archivo de constantes:
## cuántos son, y las invariantes que cruzan dos de ellos. Un número suelto no se afirma acá: se
## afirma donde se usa.
extends GdUnitTestSuite


func test_los_tipos_de_tarea_son_las_cinco_obligatorias() -> void:
	assert_int(Tarea.Tipo.size()).is_equal(5)


func test_al_cuarto_apercibimiento_lo_echan() -> void:
	# Escrito acá y no adentro de `legajo.gd` para que el número viva una sola vez: sin esta
	# aserción, `despedido()` puede decir `>= 4` con todos los tests del legajo en verde.
	assert_int(Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO).is_equal(4)


func test_el_reloj_de_mesa_falla_adentro_de_la_partida() -> void:
	# Una jornada posterior a la última dejaría la regla escrita y muerta: el reloj no fallaría
	# nunca jugando, y los criterios seguirían en verde igual. Es una invariante entre
	# constantes, y por eso se afirma contra ellas y no contra el número.
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	var ultima := primera + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
	var falla := Reglas.JORNADA_EN_QUE_FALLA_EL_RELOJ
	var fuera := "el reloj falla en la jornada %d y la partida va de la %d a la %d"
	assert_int(falla).override_failure_message(fuera % [falla, primera, ultima]).is_between(
		primera, ultima
	)


func test_la_noche_arranca_a_una_hora_del_dia() -> void:
	# La hora de apertura es la que el reloj de mesa suma a lo transcurrido: fuera de las
	# veinticuatro, la lectura nacería con un `HH` que ningún reloj muestra.
	assert_int(Reglas.HORA_DE_APERTURA).is_between(0, 23)


func test_una_jornada_grave_pesa_el_doble_que_un_aviso() -> void:
	# Es de acá que sale que dos jornadas graves seguidas despidan y tres de aviso todavía no.
	assert_int(Reglas.APERCIBIMIENTOS_POR_AVISO).is_equal(1)
	assert_int(Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE).is_equal(2)
