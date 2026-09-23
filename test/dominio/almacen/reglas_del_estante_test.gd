## Los valores fijos de reponer.
##
## El número de la caja lo fija la ficha de diseño, y por eso se afirma: la prueba de que la caja
## se vacía mide el comportamiento con cualquier valor, y sólo acá un cambio de número da rojo.
extends GdUnitTestSuite


func test_una_caja_del_deposito_trae_ocho() -> void:  # AC-STK-016
	assert_int(ReglasDelEstante.UNIDADES_POR_CAJA_DEL_DEPOSITO).is_equal(8)
