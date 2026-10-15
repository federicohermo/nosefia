extends GdUnitTestSuite


func test_suma_los_pedidos_recibidos_sin_recrear_ni_mutar_compradores() -> void:  # AC-STK-034
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var primero := Venta.new()
	primero.agregar(producto, 2)
	var segundo := Venta.new()
	segundo.agregar(Catalogo.de(producto.id), 3)
	var compradores: Array[Comprador] = [
		Comprador.new("Propio A", primero, 0), Comprador.new("Propio B", segundo, 0)
	]
	var identidad := compradores.duplicate()
	var azar := RandomNumberGenerator.new()
	azar.seed = 17
	var estado := azar.state
	for consulta in 2:
		assert_dict(Apertura.pedidos_de(compradores)).is_equal({producto.id: 5})
		assert_array(compradores).contains_exactly(identidad)
		assert_object(compradores[0].pedido()).is_same(primero)
		assert_object(compradores[1].pedido()).is_same(segundo)
		assert_int(primero.unidades_de(producto)).is_equal(2)
		assert_int(segundo.unidades_de(producto)).is_equal(3)
		assert_int(azar.state).is_equal(estado)


func test_lista_vacia_no_tiene_pedidos() -> void:
	assert_dict(Apertura.pedidos_de([])).is_empty()
