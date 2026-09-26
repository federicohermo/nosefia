## La planilla de registrar: una fila por producto, «+» y «−», el total y si coincide con lo
## vendido.
extends GdUnitTestSuite


func _de(id: Producto.Id) -> Producto:
	return Catalogo.de(id)


## Una noche con el depósito y la góndola llenos, y cada pedido ya cobrado.
func _atender_con_ventas(pedidos: Array[Venta]) -> TareaDeAtender:
	var inventario := Inventario.new(Catalogo.todos())
	for producto in Catalogo.todos():
		inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, producto.umbral)
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 9)
	var compradores: Array[Comprador] = []
	for pedido in pedidos:
		compradores.append(Comprador.new("Comprador", pedido, pedido.total()))
	var atender := TareaDeAtender.new(compradores, inventario)
	for _pedido in pedidos:
		atender.atender()
		atender.atencion().cobrar()
	return atender


func _venta(unidades_por_id: Dictionary) -> Venta:
	var venta := Venta.new()
	for id: Producto.Id in unidades_por_id:
		venta.agregar(_de(id), unidades_por_id[id])
	return venta


func _registro(pedidos: Array[Venta] = []) -> RegistroDeVentas:
	return RegistroDeVentas.new(Catalogo.todos(), _atender_con_ventas(pedidos))


func test_la_planilla_tiene_una_fila_por_producto_en_orden_y_en_cero() -> void:  # AC-STK-020
	var registro := _registro()
	var catalogo := Catalogo.todos()
	var productos := registro.productos()
	assert_int(productos.size()).is_equal(catalogo.size())
	for indice in catalogo.size():
		assert_int(productos[indice].id).is_equal(catalogo[indice].id)
		assert_int(registro.unidades_de(catalogo[indice])).is_equal(0)


func test_un_producto_nulo_o_repetido_no_suma_una_fila() -> void:
	var actroncito := _de(Producto.Id.ACTRONCITO)
	var productos: Array[Producto] = [actroncito, null, _de(Producto.Id.ACTRONCITO)]
	var registro := RegistroDeVentas.new(productos, _atender_con_ventas([]))
	assert_int(registro.productos().size()).is_equal(1)


func test_los_productos_salen_como_copia() -> void:
	var registro := _registro()
	registro.productos().clear()
	assert_int(registro.productos().size()).is_equal(Catalogo.todos().size())


func test_mas_y_menos_mueven_una_sola_fila() -> void:  # AC-STK-021
	var registro := _registro()
	var durextra := _de(Producto.Id.DUREXTRA)
	assert_bool(registro.sumar(durextra)).is_true()
	assert_bool(registro.sumar(_de(Producto.Id.DUREXTRA))).is_true()
	assert_bool(registro.restar(durextra)).is_true()
	for producto in Catalogo.todos():
		var esperadas := 1 if producto.id == Producto.Id.DUREXTRA else 0
		assert_int(registro.unidades_de(producto)).is_equal(esperadas)


func test_menos_con_la_fila_en_cero_se_rechaza() -> void:  # AC-STK-022
	var registro := _registro()
	var burbaloo := _de(Producto.Id.BURBALOO)
	assert_bool(registro.restar(burbaloo)).is_false()
	assert_int(registro.unidades_de(burbaloo)).is_equal(0)


func test_mas_con_la_fila_en_el_tope_se_rechaza() -> void:  # AC-STK-022
	var registro := _registro()
	var burbaloo := _de(Producto.Id.BURBALOO)
	for _vez in RegistroDeVentas.TOPE_POR_FILA:
		registro.sumar(burbaloo)
	assert_int(registro.unidades_de(burbaloo)).is_equal(99)
	assert_bool(registro.sumar(burbaloo)).is_false()
	assert_int(registro.unidades_de(burbaloo)).is_equal(99)


func test_un_producto_ajeno_o_nulo_se_rechaza_sin_tocar_ninguna_fila() -> void:  # AC-STK-022
	var actroncito := _de(Producto.Id.ACTRONCITO)
	var productos: Array[Producto] = [actroncito]
	var registro := RegistroDeVentas.new(productos, _atender_con_ventas([]))
	var ajeno := _de(Producto.Id.MACUMBAS)
	assert_bool(registro.sumar(ajeno)).is_false()
	assert_bool(registro.restar(ajeno)).is_false()
	assert_bool(registro.sumar(null)).is_false()
	assert_bool(registro.restar(null)).is_false()
	assert_int(registro.unidades_de(ajeno)).is_equal(0)
	assert_int(registro.unidades_de(actroncito)).is_equal(0)
	assert_int(registro.total()).is_equal(0)


func test_el_total_sigue_a_cada_gesto() -> void:  # AC-STK-023
	var registro := _registro()
	var actroncito := _de(Producto.Id.ACTRONCITO)
	var durextra := _de(Producto.Id.DUREXTRA)
	assert_int(actroncito.precio).is_equal(2500)
	assert_int(durextra.precio).is_equal(1200)
	registro.sumar(actroncito)
	registro.sumar(actroncito)
	registro.sumar(durextra)
	assert_int(registro.total()).is_equal(6200)
	registro.restar(actroncito)
	assert_int(registro.total()).is_equal(3700)


func test_el_mismo_total_con_otro_producto_no_coincide() -> void:  # AC-STK-023
	var durextra := _de(Producto.Id.DUREXTRA)
	var prongles := _de(Producto.Id.PRONGLES)
	assert_int(prongles.precio).is_equal(durextra.precio)
	var registro := _registro([_venta({Producto.Id.DUREXTRA: 1})])
	registro.sumar(prongles)
	assert_int(registro.total()).is_equal(durextra.precio)
	assert_bool(registro.coincide()).is_false()


func test_coincide_recien_con_la_ultima_unidad() -> void:  # AC-STK-024
	var registro := _registro([_venta({Producto.Id.ACTRONCITO: 2, Producto.Id.DUREXTRA: 1})])
	var actroncito := _de(Producto.Id.ACTRONCITO)
	registro.sumar(actroncito)
	assert_bool(registro.coincide()).is_false()
	registro.sumar(actroncito)
	assert_bool(registro.coincide()).is_false()
	registro.sumar(_de(Producto.Id.DUREXTRA))
	assert_bool(registro.coincide()).is_true()


func test_una_unidad_de_mas_deja_de_coincidir_y_restarla_vuelve() -> void:  # AC-STK-025
	var registro := _registro([_venta({Producto.Id.ACTRONCITO: 1})])
	var actroncito := _de(Producto.Id.ACTRONCITO)
	registro.sumar(actroncito)
	assert_bool(registro.coincide()).is_true()
	registro.sumar(_de(Producto.Id.FLINPUF))
	assert_bool(registro.coincide()).is_false()
	registro.restar(_de(Producto.Id.FLINPUF))
	assert_bool(registro.coincide()).is_true()


func test_dos_ventas_del_mismo_producto_se_anotan_juntas() -> void:
	var pedidos: Array[Venta] = [
		_venta({Producto.Id.ACTRONCITO: 1}), _venta({Producto.Id.ACTRONCITO: 2})
	]
	var registro := _registro(pedidos)
	for _vez in 3:
		registro.sumar(_de(Producto.Id.ACTRONCITO))
	assert_bool(registro.coincide()).is_true()
