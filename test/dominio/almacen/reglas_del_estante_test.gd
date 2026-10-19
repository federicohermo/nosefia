## Los valores fijos de reponer, y la relación que los vuelve jugables.
##
## No afirma el número: afirma **contra qué tiene que ser** ese número. Una caja que trae menos
## unidades de las que a un producto le faltan deja una noche en la que reponer no se puede
## terminar, y el síntoma no nombra a esta constante: el jugador vacía la caja, coloca todo lo
## que tenía y la tarea sigue sin contar.
extends GdUnitTestSuite


func test_el_intervalo_inclusivo_de_la_ficha_se_conserva() -> void:  # AC-STK-034
	assert_vector(ReglasDelEstante.TIPOS_QUE_FALTAN).is_equal(Vector2i(4, 7))


func test_las_unidades_de_una_caja_son_una_cantidad_y_no_un_centinela() -> void:
	assert_int(ReglasDelEstante.UNIDADES_POR_CAJA).is_greater(0)
