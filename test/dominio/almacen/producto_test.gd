## Qué es un producto del almacén: su identidad, el nombre que lee el jugador, su precio y el
## umbral a partir del cual la góndola se considera desabastecida.
##
## Los cuatro valores de este archivo son **del test, no del catálogo**: acá no se importa
## `Catalogo` a propósito. Si el balance moviera el precio del Actroncito, este archivo no se
## entera — leerlo del catálogo pondría al balance a decidir si un test pasa.
extends GdUnitTestSuite


func test_un_producto_recuerda_los_cuatro_valores_con_los_que_se_construyo() -> void:
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 4)
	assert_int(actroncito.id).is_equal(Producto.Id.ACTRONCITO)
	assert_str(actroncito.nombre).is_equal("Actroncito")
	assert_int(actroncito.precio).is_equal(2500)
	assert_int(actroncito.umbral).is_equal(4)
