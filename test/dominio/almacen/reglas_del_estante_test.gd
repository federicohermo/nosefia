## Los valores fijos de reponer, y la relación que los vuelve jugables.
##
## No afirma el número: afirma **contra qué tiene que ser** ese número. Un
## `UNIDADES_INICIALES_EN_DEPOSITO` por debajo del umbral más alto del catálogo deja una noche en
## la que reponer no se puede terminar, y el síntoma no nombra a esta constante: el jugador
## coloca todo lo que hay y la tarea sigue sin contar.
extends GdUnitTestSuite


func test_el_deposito_arranca_con_mas_de_lo_que_el_estante_pide() -> void:  # 008-AC9
	# Estricto y no `>=` a propósito: con exactamente el umbral, vender una sola unidad por la
	# ventanilla —que es del 013— deja la reposición imposible esa noche.
	var mayor := 0
	for producto in Catalogo.todos():
		mayor = maxi(mayor, producto.umbral)
	(
		assert_int(ReglasDelEstante.UNIDADES_INICIALES_EN_DEPOSITO)
		. override_failure_message(
			(
				"el depósito arranca con %d y el umbral más alto del catálogo es %d"
				% [ReglasDelEstante.UNIDADES_INICIALES_EN_DEPOSITO, mayor]
			)
		)
		. is_greater(mayor)
	)


func test_las_unidades_iniciales_son_una_cantidad_y_no_un_centinela() -> void:  # 008-AC9
	assert_int(ReglasDelEstante.UNIDADES_INICIALES_EN_DEPOSITO).is_greater(0)
