## Quién es un comprador: cómo se llama, qué pide y con cuánto paga.
##
## Un comprador no hace nada, **es** — igual que `Producto`. Lo que se hace con su pedido es de
## `Atencion`, y por eso acá no hay una sola cuenta.
extends GdUnitTestSuite


func _pedido() -> Venta:
	var venta := Venta.new()
	venta.agregar(Catalogo.de(Producto.Id.YERBA), 2)
	return venta


func test_el_comprador_contesta_su_nombre_y_lo_que_paga() -> void:  # 013-AC1
	var comprador := Comprador.new("Marta", _pedido(), 5000)
	assert_str(comprador.nombre()).is_equal("Marta")
	assert_int(comprador.paga()).is_equal(5000)


func test_lo_que_paga_es_un_entero_y_no_un_flotante() -> void:  # 013-AC1
	# El dinero del juego es `int`: un `float` acá dejaría diferencias de un centavo que el
	# jugador no puede ver y que ninguna aserción de igualdad caza.
	var comprador := Comprador.new("Marta", _pedido(), 5000)
	assert_int(typeof(comprador.paga())).is_equal(TYPE_INT)


func test_el_pedido_es_la_misma_instancia_que_recibio_y_no_una_copia() -> void:  # 013-AC1
	# Con una copia, `Inventario.cobrar()` descontaría contra un pedido y la pantalla mostraría
	# otro: los dos con las mismas líneas hasta que alguien agregue una, y ahí se separan sin un
	# solo error.
	var pedido := _pedido()
	var comprador := Comprador.new("Marta", pedido, 5000)
	assert_object(comprador.pedido()).is_same(pedido)


func test_dos_compradores_no_comparten_el_pedido() -> void:  # 013-AC1
	var uno := Comprador.new("Marta", _pedido(), 5000)
	var otro := Comprador.new("Rubén", _pedido(), 5000)
	assert_object(uno.pedido()).is_not_same(otro.pedido())
