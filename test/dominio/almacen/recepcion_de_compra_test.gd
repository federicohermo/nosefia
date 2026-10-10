extends GdUnitTestSuite


# AC-CTR-036, AC-CTR-039
func test_atencion_habla_antes_de_recibir_y_solo_vende_el_pedido_completo() -> void:
	var comprador := Compradores.de_la_jornada(1)[1]
	var inventario := Apertura.inventario_con_faltantes({}, {})
	var estante := Estante.new(inventario, Catalogo.todos())
	var atencion := Atencion.new(comprador, inventario)
	var unidad := estante.retirar(Catalogo.de(Producto.Id.ZUCARACHAS))
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.DIALOGO)
	assert_str(atencion.dialogo().entrada_actual()).contains("zucarachas")
	assert_bool(atencion.puede_abandonar()).is_false()
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.DIALOGO)
	assert_bool(atencion.puede_abandonar()).is_true()
	assert_bool(atencion.vendida()).is_false()
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	assert_bool(atencion.vendida()).is_false()
	atencion.interactuar(estante.retirar(Catalogo.de(Producto.Id.ZUCARACHAS)))
	atencion.interactuar(estante.retirar(Catalogo.de(Producto.Id.PEPITOS)))
	assert_bool(atencion.vendida()).is_false()
	assert_int(atencion.interactuar(_ticket())).is_equal(RecepcionDeCompra.Resultado.COMPLETA)
	assert_bool(atencion.vendida()).is_true()
	assert_bool(atencion.despachada()).is_false()
	atencion.vencer()
	assert_bool(atencion.vendida()).is_true()
	for i in 4:
		atencion.interactuar(null)
	assert_bool(atencion.despachada()).is_true()


func test_vencer_cierra_incluso_la_conversacion_inicial() -> void:  # AC-CTR-040
	var atencion := Atencion.new(Compradores.de_la_jornada(1)[0], Inventario.new([]))
	atencion.interactuar(null)
	assert_bool(atencion.puede_abandonar()).is_false()
	atencion.vencer()
	assert_bool(atencion.puede_abandonar()).is_true()
	assert_bool(atencion.despachada()).is_true()
	assert_bool(atencion.vendida()).is_false()


func test_vencer_retira_la_entrega_parcial_del_inventario() -> void:  # AC-CTR-040, AC-STK-055
	var inventario := Apertura.inventario_con_faltantes({}, {})
	var comprador := Compradores.de_la_jornada(1)[0]
	var atencion := Atencion.new(comprador, inventario)
	for _entrada in 4:
		atencion.interactuar(null)
	var producto := Catalogo.de(Producto.Id.MAROLINI)
	var unidad := Estante.new(inventario, Catalogo.todos()).retirar(producto)
	var antes := inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	atencion.vencer()
	assert_bool(inventario.esta_afuera(unidad)).is_false()
	assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(antes - 1)
	atencion.vencer()
	assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(antes - 1)
	assert_bool(atencion.vendida()).is_false()


func test_un_clic_termina_el_recordatorio_y_otro_entrega() -> void:  # AC-CTR-036
	var inventario := Apertura.inventario_con_faltantes({}, {})
	var atencion := Atencion.new(Compradores.de_la_jornada(1)[1], inventario)
	atencion.interactuar(null)
	atencion.interactuar(null)
	atencion.interactuar(null)
	var unidad := Estante.new(inventario, Catalogo.todos()).retirar(
		Catalogo.de(Producto.Id.ZUCARACHAS)
	)
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.DIALOGO)
	assert_bool(atencion.puede_abandonar()).is_true()
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)


func test_el_rechazo_se_cierra_con_el_objeto_en_mano_y_deja_salir() -> void:  # AC-CTR-037
	var inventario := Apertura.inventario_con_faltantes({}, {})
	var atencion := Atencion.new(Compradores.de_la_jornada(1)[1], inventario)
	atencion.interactuar(null)
	atencion.interactuar(null)
	var incorrecto := ObjetoDelAlmacen.new()
	assert_int(atencion.interactuar(incorrecto)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	assert_bool(atencion.puede_abandonar()).is_false()
	assert_int(atencion.interactuar(incorrecto)).is_equal(RecepcionDeCompra.Resultado.DIALOGO)
	assert_bool(atencion.puede_abandonar()).is_true()
	assert_bool(atencion.vendida()).is_false()


func _pedido() -> Venta:
	var pedido := Venta.new()
	pedido.agregar(Catalogo.de(Producto.Id.ZUCARACHAS), 2)
	pedido.agregar(Catalogo.de(Producto.Id.PEPITOS), 1)
	return pedido


func _unidad(id: Producto.Id = Producto.Id.ZUCARACHAS) -> UnidadDeProducto:
	return UnidadDeProducto.new(Catalogo.de(id))


func _ticket(
	ids: Array = [Producto.Id.PEPITOS, Producto.Id.ZUCARACHAS, Producto.Id.ZUCARACHAS]
) -> Ticket:
	var productos: Array[Producto] = []
	for id: Producto.Id in ids:
		productos.append(Catalogo.de(id))
	return Ticket.new(productos)


func test_antes_de_hablar_no_recibe_ni_rechaza() -> void:  # AC-CTR-036
	var recepcion := RecepcionDeCompra.new(_pedido())
	assert_int(recepcion.recibir(_unidad(), false)).is_equal(RecepcionDeCompra.Resultado.BLOQUEADA)
	assert_int(recepcion.recibir(ObjetoDelAlmacen.new(), false)).is_equal(
		RecepcionDeCompra.Resultado.BLOQUEADA
	)
	assert_int(recepcion.pendientes(Catalogo.de(Producto.Id.ZUCARACHAS))).is_equal(2)


func test_recibe_identidades_distintas_y_rechaza_sobrantes() -> void:  # AC-CTR-037
	var recepcion := RecepcionDeCompra.new(_pedido())
	var primera := _unidad()
	assert_int(recepcion.recibir(primera, true)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	assert_int(recepcion.pendientes(primera.producto)).is_equal(1)
	for objeto: ObjetoDelAlmacen in [
		primera, _unidad(Producto.Id.CORACOLA), ObjetoDelAlmacen.new()
	]:
		assert_int(recepcion.recibir(objeto, true)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	assert_int(recepcion.recibir(_unidad(), true)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	assert_int(recepcion.recibir(_unidad(), true)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	assert_int(recepcion.unidades().size()).is_equal(2)


func test_el_ticket_compara_cantidades_sin_orden() -> void:  # AC-CTR-038
	for ids: Array in [
		[Producto.Id.ZUCARACHAS, Producto.Id.ZUCARACHAS, Producto.Id.PEPITOS],
		[Producto.Id.PEPITOS, Producto.Id.ZUCARACHAS, Producto.Id.ZUCARACHAS],
	]:
		var recepcion := RecepcionDeCompra.new(_pedido())
		assert_int(recepcion.recibir(_ticket(ids), true)).is_equal(
			RecepcionDeCompra.Resultado.ACEPTADA
		)
		assert_bool(recepcion.completa()).is_false()
	for ids: Array in [
		[Producto.Id.ZUCARACHAS, Producto.Id.PEPITOS],
		[
			Producto.Id.ZUCARACHAS,
			Producto.Id.ZUCARACHAS,
			Producto.Id.ZUCARACHAS,
			Producto.Id.PEPITOS
		],
		[Producto.Id.ZUCARACHAS, Producto.Id.ZUCARACHAS],
		[Producto.Id.ZUCARACHAS, Producto.Id.ZUCARACHAS, Producto.Id.CORACOLA],
	]:
		var recepcion := RecepcionDeCompra.new(_pedido())
		assert_int(recepcion.recibir(_ticket(ids), true)).is_equal(
			RecepcionDeCompra.Resultado.RECHAZADA
		)


# AC-CTR-038, AC-CTR-039
func test_solo_productos_no_completan_y_el_ultimo_elemento_completa() -> void:
	var recepcion := RecepcionDeCompra.new(_pedido())
	for unidad: UnidadDeProducto in [_unidad(), _unidad(), _unidad(Producto.Id.PEPITOS)]:
		assert_int(recepcion.recibir(unidad, true)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	assert_bool(recepcion.completa()).is_false()
	assert_int(recepcion.recibir(_ticket(), true)).is_equal(RecepcionDeCompra.Resultado.COMPLETA)
	assert_int(recepcion.recibir(_ticket(), true)).is_equal(RecepcionDeCompra.Resultado.BLOQUEADA)
	var otra := RecepcionDeCompra.new(_pedido())
	assert_int(otra.unidades().size()).is_zero()
