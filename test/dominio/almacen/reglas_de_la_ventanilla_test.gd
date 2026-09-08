## Los valores fijos de atender, y la relación que los vuelve jugables.
extends GdUnitTestSuite


func test_la_jornada_pide_atender_a_mas_de_un_comprador() -> void:  # 013-AC8
	# Con uno solo, atender sería un viaje a la ventanilla y la tarea no tendría con qué
	# interrumpir la investigación dos veces, que es lo que la vuelve parte de la resta.
	assert_int(ReglasDeLaVentanilla.COMPRADORES_POR_JORNADA).is_greater(1)


func test_ningun_comprador_de_la_jornada_queda_sin_atender_por_falta_de_lista() -> void:
	# 013-AC8
	# El balance manda sobre la lista y no al revés: agregar una fila al padrón no cambia
	# cuántos vienen, y subir la constante por encima del padrón se pone en rojo acá.
	(
		assert_int(ReglasDeLaVentanilla.COMPRADORES_POR_JORNADA)
		. override_failure_message("el balance pide más compradores de los que hay en el padrón")
		. is_less_equal(Compradores.padron().size())
	)


func test_por_la_ventanilla_no_pasan_mas_de_dos_compradores_por_jornada() -> void:  # 013-AC8
	# El techo lo pone el GDD —«no más de dos compradores por día»— y hasta acá vivía sólo en un
	# comentario: el piso estaba afirmado y el techo no, así que subir la constante a tres pasaba
	# los seis nodos en verde y le regalaba a atender una interrupción que el balance no pidió.
	(
		assert_int(ReglasDeLaVentanilla.COMPRADORES_POR_JORNADA)
		. override_failure_message("el GDD no admite más de dos compradores por jornada")
		. is_less_equal(2)
	)
