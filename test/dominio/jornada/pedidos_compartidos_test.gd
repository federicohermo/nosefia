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
	for consulta in 2:
		assert_dict(Apertura.pedidos_de(compradores)).is_equal({producto.id: 5})
		assert_array(compradores).contains_exactly(identidad)
		assert_object(compradores[0].pedido()).is_same(primero)
		assert_object(compradores[1].pedido()).is_same(segundo)
		assert_int(primero.unidades_de(producto)).is_equal(2)
		assert_int(segundo.unidades_de(producto)).is_equal(3)


func test_lista_vacia_no_tiene_pedidos() -> void:
	assert_dict(Apertura.pedidos_de([])).is_empty()


func test_el_inventario_usa_los_mismos_pedidos_y_el_mismo_azar_que_atencion() -> void:  # AC-STK-034
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var compradores: Array[Comprador] = []
	for cantidad: int in [2, 3]:
		var pedido := Venta.new()
		pedido.agregar(producto, cantidad)
		compradores.append(Comprador.new("Propio", pedido, pedido.total()))
	var casilleros: Dictionary[Producto.Id, int] = {producto.id: 6}
	var azar := RandomNumberGenerator.new()
	var control := RandomNumberGenerator.new()
	azar.seed = 17
	control.seed = 17
	var esperado := Apertura.faltantes_al_azar({producto.id: 5}, casilleros, control)
	var inventario := Apertura.inventario_de_la_jornada(compradores, casilleros, azar)
	assert_int(azar.state).is_equal(control.state)
	assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(
		6 - esperado[producto.id]
	)
	assert_int(esperado[producto.id]).is_between(1, 3)
	var atenciones := TareaDeAtender.new(compradores, inventario)
	for comprador in compradores:
		assert_object(atenciones.atender()).is_same(comprador)
		assert_object(atenciones.atencion().comprador().pedido()).is_same(comprador.pedido())
		assert_int(atenciones.atencion().cobrar()).is_equal(Atencion.Resultado.COBRADA)
	assert_bool(atenciones.completada()).is_true()
