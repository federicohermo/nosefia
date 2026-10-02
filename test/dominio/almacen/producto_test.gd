## Qué es un producto del almacén: su identidad, el nombre que lee el jugador y su precio.
##
## Los tres valores de este archivo son **del test, no del catálogo**: acá no se importa
## `Catalogo` a propósito. Si el balance moviera un precio, este archivo no se
## entera — leerlo del catálogo pondría al balance a decidir si un test pasa.
extends GdUnitTestSuite


func test_un_producto_recuerda_los_tres_valores_con_los_que_se_construyo() -> void:
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	assert_int(actroncito.id).is_equal(Producto.Id.ACTRONCITO)
	assert_str(actroncito.nombre).is_equal("Actroncito")
	assert_int(actroncito.precio).is_equal(2500)
