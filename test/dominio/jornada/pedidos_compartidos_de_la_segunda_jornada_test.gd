extends GdUnitTestSuite


func _compradores() -> Array[Comprador]:
	return Compradores.segunda_jornada_definida()


func _cupos() -> Dictionary[Producto.Id, int]:
	var cupos: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		cupos[producto.id] = 8
	return cupos


func _guiones(compradores: Array[Comprador]) -> void:
	var textos := DialogosDeCompradores.new()
	textos.fede = PackedStringArray(["Inicial fixture"])
	textos.mia = PackedStringArray(["Inicial fixture"])
	textos.despedida_fede = PackedStringArray(["Despedida fixture"])
	textos.despedida_mia = PackedStringArray(["Despedida fixture"])
	for comprador in compradores:
		comprador.dialogos = textos


# AC-CTR-052, AC-STK-081
func test_atencion_y_faltantes_comparten_compradores_y_ventas_en_ambos_ordenes() -> void:
	for consultar_primero: bool in [true, false]:
		var compradores := _compradores()
		var ventas: Array[Venta] = [compradores[0].pedido(), compradores[1].pedido()]
		var azar := RandomNumberGenerator.new()
		azar.seed = 433
		var atender: TareaDeAtender
		var inventario: Inventario
		var pedidos: Dictionary[Producto.Id, int]
		if consultar_primero:
			pedidos = Apertura.pedidos_de(compradores)
			inventario = Apertura.inventario_de_la_jornada(compradores, _cupos(), _cupos(), azar)
			atender = TareaDeAtender.new(compradores, inventario)
		else:
			inventario = Apertura.inventario_de_la_jornada(compradores, _cupos(), _cupos(), azar)
			atender = TareaDeAtender.new(compradores, inventario)
			pedidos = Apertura.pedidos_de(compradores)
		for _lectura in 3:
			assert_that(Apertura.pedidos_de(compradores)).is_equal(pedidos)
		assert_int(pedidos.size()).is_equal(6)
		for indice in 2:
			atender.avanzar(compradores[indice].horario.x)
			assert_object(atender.atencion().comprador()).is_same(compradores[indice])
			assert_object(atender.atencion().comprador().pedido()).is_same(ventas[indice])
			assert_object(atender.atencion().get("_inventario")).is_same(inventario)
			for producto in ventas[indice].productos():
				assert_int(pedidos[producto.id]).is_equal(1)
				assert_int(inventario.vendibles(producto)).is_greater_equal(1)


# AC-CTR-052, AC-STK-081, AC-STK-084
func test_la_venta_desde_deposito_descuenta_una_vez_y_la_apertura_nueva_no_hereda() -> void:
	var compradores := _compradores()
	_guiones(compradores)
	var inventario := Apertura.inventario_con_faltantes({}, _cupos())
	var atender := TareaDeAtender.new(compradores, inventario)
	atender.avanzar(compradores[0].horario.x)
	var atencion := atender.atencion()
	atencion.interactuar(null)
	atencion.interactuar(null)
	var productos := compradores[0].pedido().productos()
	var estante := Estante.new(inventario, Catalogo.todos())
	var unidades: Array[UnidadDeProducto] = []
	for producto in productos:
		var unidad := estante.retirar(producto)
		unidades.append(unidad)
		assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
		assert_object(atencion.comprador().pedido()).is_same(compradores[0].pedido())
	var ticket := Ticket.new(productos)
	assert_int(atencion.interactuar(ticket)).is_equal(RecepcionDeCompra.Resultado.COMPLETA)
	atencion.interactuar(null)
	assert_int(atencion.interactuar(ticket)).is_equal(RecepcionDeCompra.Resultado.BLOQUEADA)
	var nuevos := _compradores()
	var nuevo := Apertura.inventario_con_faltantes({}, _cupos())
	for indice in productos.size():
		var producto := productos[indice]
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(
			ReglasDelEstante.UNIDADES_POR_CAJA - 1
		)
		assert_int(nuevo.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(
			ReglasDelEstante.UNIDADES_POR_CAJA
		)
		assert_bool(inventario.esta_afuera(unidades[indice])).is_false()
		assert_bool(nuevo.esta_afuera(unidades[indice])).is_false()
		assert_object(nuevos[0].pedido()).is_not_same(compradores[0].pedido())
	assert_bool(TareaDeAtender.new(nuevos, nuevo).compras_cerradas()).is_false()
