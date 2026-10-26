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
	var tandas: Dictionary[Producto.Id, Array] = {producto.id: [PackedInt32Array(range(6))]}
	var esperado := Apertura.vacios_de_la_jornada(2, compradores, tandas, {}, control)
	var inventario := Apertura.inventario_de_la_jornada(
		2, compradores, casilleros, casilleros, azar
	)
	assert_int(azar.state).is_equal(control.state)
	assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(
		6 - esperado[producto.id].size()
	)
	assert_int(esperado[producto.id].size()).is_between(ReglasDelEstante.MENOS_QUE_FALTA, 3)
	var atenciones := TareaDeAtender.new(compradores, inventario)
	for comprador in compradores:
		assert_object(atenciones.atender()).is_same(comprador)
		assert_object(atenciones.atencion().comprador().pedido()).is_same(comprador.pedido())
		assert_int(atenciones.atencion().cobrar()).is_equal(Atencion.Resultado.COBRADA)
	assert_bool(atenciones.completada()).is_true()


func test_la_apertura_puede_vaciar_cualquier_tanda_y_conserva_el_cupo_total() -> void:  # AC-STK-033
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var totales: Dictionary[Producto.Id, int] = {producto.id: 8}
	var principales: Dictionary[Producto.Id, int] = {producto.id: 4}
	for semilla in 200:
		var azar := RandomNumberGenerator.new()
		azar.seed = semilla
		var inventario := Apertura.inventario_de_la_jornada(2, [], totales, principales, azar)
		var estante := Estante.new(inventario, Catalogo.todos())
		assert_int(estante.cupo(producto)).is_equal(8)
		assert_int(estante.casilleros_vacios(producto).size()).is_between(
			ReglasDelEstante.MENOS_QUE_FALTA, totales[producto.id]
		)
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(
			ReglasDelEstante.UNIDADES_POR_CAJA
		)


func test_un_producto_con_casilleros_solo_en_una_fija_falta() -> void:  # AC-STK-030
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var totales: Dictionary[Producto.Id, int] = {producto.id: 8}
	var principales: Dictionary[Producto.Id, int] = {producto.id: 0}
	for semilla in 200:
		var azar := RandomNumberGenerator.new()
		azar.seed = semilla
		var inventario := Apertura.inventario_de_la_jornada(2, [], totales, principales, azar)
		assert_int(inventario.casilleros(producto)).is_equal(8)
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_less(8)


func test_un_producto_sin_casilleros_en_ninguna_tanda_no_falta() -> void:  # AC-STK-030
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var totales: Dictionary[Producto.Id, int] = {producto.id: 0}
	var principales: Dictionary[Producto.Id, int] = {producto.id: 0}
	for semilla in 200:
		var azar := RandomNumberGenerator.new()
		azar.seed = semilla
		var inventario := Apertura.inventario_de_la_jornada(2, [], totales, principales, azar)
		assert_array(inventario.faltantes()).is_empty()


func test_un_producto_de_una_fila_no_abre_vacia_ninguna_de_sus_dos_tandas() -> void:  # AC-STK-033
	var producto := Catalogo.de(Producto.Id.FLIM_POF)
	var totales: Dictionary[Producto.Id, int] = {producto.id: 6}
	var reponibles: Dictionary[Producto.Id, int] = {producto.id: 3}
	var de_una_fila: Dictionary[Producto.Id, bool] = {producto.id: true}
	var faltantes: Dictionary[int, bool] = {}
	for semilla in 200:
		var azar := RandomNumberGenerator.new()
		azar.seed = semilla
		var inventario := Apertura.inventario_de_la_jornada(
			8, [], totales, reponibles, azar, de_una_fila
		)
		var falta := 6 - inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)
		faltantes[falta] = true
		assert_int(falta).is_between(ReglasDelEstante.MENOS_QUE_FALTA, 4)
	assert_bool(faltantes.has(4)).is_true()
