## Los valores fijos de reponer, y la relación que los vuelve jugables.
##
## No afirma el número: afirma **contra qué tiene que ser** ese número. Una caja que trae menos
## unidades de las que a un producto le faltan deja una noche en la que reponer no se puede
## terminar, y el síntoma no nombra a esta constante: el jugador vacía la caja, coloca todo lo
## que tenía y la tarea sigue sin contar.
extends GdUnitTestSuite


func test_los_intervalos_de_faltantes_son_un_sorteo_posible() -> void:  # AC-STK-034
	assert_int(ReglasDelEstante.TIPOS_QUE_FALTAN.x).is_greater(0)
	assert_int(ReglasDelEstante.TIPOS_QUE_FALTAN.y).is_greater_equal(
		ReglasDelEstante.TIPOS_QUE_FALTAN.x
	)
	assert_int(ReglasDelEstante.MENOS_QUE_FALTA).is_greater(0)
	assert_int(ReglasDelEstante.MENOS_QUE_FALTA).is_less_equal(ReglasDelEstante.UNIDADES_POR_CAJA)


func test_las_unidades_de_una_caja_son_una_cantidad_y_no_un_centinela() -> void:
	assert_int(ReglasDelEstante.UNIDADES_POR_CAJA).is_greater(0)
