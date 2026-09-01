## Qué productos existen en el almacén y con qué valores.
##
## Los tres AC de acá son el único lugar del repo que se pone en rojo cuando el catálogo y el
## `enum Id` se desincronizan: agregar un producto al enum y olvidarse de su fila deja un
## `Catalogo.de(id)` que devuelve un producto a medio llenar y nada más lo caza.
extends GdUnitTestSuite


func test_hay_exactamente_un_producto_por_cada_valor_del_enum() -> void:
	# El AC que se pone en rojo el día que alguien agregue un producto al enum sin darle fila.
	assert_array(Catalogo.todos()).has_size(Producto.Id.size())


func test_cada_producto_del_catalogo_esta_completo() -> void:
	# Recorre el enum entero y no una muestra: una fila a medio llenar en el sexto producto
	# pasaría desapercibida si el test mirara sólo la yerba.
	for id in Producto.Id.values():
		var producto := Catalogo.de(id)
		assert_int(producto.id).is_equal(id)
		assert_str(producto.nombre).is_not_empty()
		assert_int(producto.precio).is_greater(0)
		assert_int(producto.umbral).is_greater_equal(1)


func test_dos_llamadas_al_catalogo_dan_objetos_distintos_con_el_mismo_id() -> void:
	# La decisión escrita como test: la identidad de un producto es su `id`, nunca la
	# instancia. Quien indexe por instancia va a encontrar ausente lo que guardó la otra.
	var una := Catalogo.de(Producto.Id.YERBA)
	var otra := Catalogo.de(Producto.Id.YERBA)
	assert_object(una).is_not_same(otra)
	assert_int(una.id).is_equal(otra.id)
