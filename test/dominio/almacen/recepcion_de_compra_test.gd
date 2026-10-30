extends GdUnitTestSuite


# AC-CTR-036, AC-CTR-039
func test_atencion_habla_antes_de_recibir_y_solo_vende_el_pedido_completo() -> void:
	var comprador := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[1]
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var estante := Estante.new(inventario, Catalogo.todos())
	var atencion := Atencion.new(comprador, inventario)
	var unidad := estante.retirar(Catalogo.de(Producto.Id.ZUCARACHAS))
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.DIALOGO)
	assert_str(atencion.dialogo().entrada_actual()).contains("Zucarachas")
	assert_bool(atencion.puede_abandonar()).is_false()
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.DIALOGO)
	assert_bool(atencion.puede_abandonar()).is_true()
	assert_bool(atencion.vendida()).is_false()
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	assert_bool(atencion.vendida()).is_false()
	atencion.interactuar(estante.retirar(Catalogo.de(Producto.Id.PEPITO)))
	assert_bool(atencion.vendida()).is_false()
	(
		assert_int(atencion.interactuar(_ticket([Producto.Id.ZUCARACHAS, Producto.Id.PEPITO])))
		. is_equal(RecepcionDeCompra.Resultado.COMPLETA)
	)
	assert_bool(atencion.vendida()).is_true()
	assert_bool(atencion.despachada()).is_false()
	atencion.vencer()
	assert_bool(atencion.vendida()).is_true()
	for i in 4:
		atencion.interactuar(null)
	assert_bool(atencion.despachada()).is_true()


func test_vencer_cierra_incluso_la_conversacion_inicial() -> void:  # AC-CTR-040
	var atencion := Atencion.new(
		Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[0], Inventario.new([])
	)
	atencion.interactuar(null)
	assert_bool(atencion.puede_abandonar()).is_false()
	atencion.vencer()
	assert_bool(atencion.puede_abandonar()).is_true()
	assert_bool(atencion.despachada()).is_true()
	assert_bool(atencion.vendida()).is_false()


func test_vencer_conserva_y_permite_recuperar_la_entrega() -> void:  # AC-CTR-040, AC-STK-055
	for desde_gondola: bool in [false, true]:
		var producto := Catalogo.de(Producto.Id.MAROLINI)
		var inventario := Inventario.new(Catalogo.todos(), {Producto.Id.MAROLINI: 3})
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 8)
		inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, 3)
		var estante := Estante.new(inventario, Catalogo.todos())
		var atencion := Atencion.new(
			Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[0], inventario
		)
		while not atencion.conversacion_iniciada() or not atencion.puede_abandonar():
			atencion.interactuar(null)
		var unidad := estante.agarrar(producto, 1) if desde_gondola else estante.retirar(producto)
		var deposito := inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)
		var gondola := inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)
		var caja := ContenidoDeLaCaja.new(producto, estante)
		var contenido := caja.unidades()
		assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
		atencion.vencer()
		atencion.vencer()
		assert_bool(inventario.esta_afuera(unidad)).is_true()
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(deposito)
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(gondola)
		assert_int(caja.unidades()).is_equal(contenido)
		assert_bool(atencion.vendida()).is_false()
		var recepcion: RecepcionDeCompra = atencion.get("_recepcion")
		assert_array(recepcion.unidades()).contains_exactly([unidad])
		if desde_gondola:
			assert_bool(caja.meter(unidad)).is_false()
			var de_la_caja := caja.sacar()
			assert_bool(caja.meter(unidad)).is_true()
			assert_int(estante.colocar_unidad(de_la_caja, producto, 1)).is_equal(
				Estante.Rechazo.NINGUNO
			)
		else:
			assert_bool(caja.meter(unidad)).is_true()
		assert_bool(inventario.esta_afuera(unidad)).is_false()


func test_el_recordatorio_no_retiene_el_clic_de_la_entrega() -> void:  # AC-CTR-098
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var atencion := Atencion.new(
		Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[1], inventario
	)
	atencion.interactuar(null)
	atencion.interactuar(null)
	atencion.interactuar(null)
	var unidad := Estante.new(inventario, Catalogo.todos()).retirar(
		Catalogo.de(Producto.Id.ZUCARACHAS)
	)
	assert_bool(atencion.puede_abandonar()).is_true()
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)


func test_el_rechazo_no_retiene_con_el_objeto_en_mano_y_deja_salir() -> void:  # AC-CTR-037
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var atencion := Atencion.new(
		Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[1], inventario
	)
	atencion.interactuar(null)
	atencion.interactuar(null)
	var incorrecto := ObjetoDelAlmacen.new()
	assert_int(atencion.interactuar(incorrecto)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	assert_bool(atencion.puede_abandonar()).is_true()
	assert_int(atencion.interactuar(incorrecto)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	assert_bool(atencion.puede_abandonar()).is_true()
	assert_bool(atencion.vendida()).is_false()


func _pedido() -> Venta:
	var pedido := Venta.new()
	pedido.agregar(Catalogo.de(Producto.Id.ZUCARACHAS), 2)
	pedido.agregar(Catalogo.de(Producto.Id.PEPITO), 1)
	return pedido


func _unidad(id: Producto.Id = Producto.Id.ZUCARACHAS) -> UnidadDeProducto:
	return UnidadDeProducto.new(Catalogo.de(id))


func _ticket(
	ids: Array = [Producto.Id.PEPITO, Producto.Id.ZUCARACHAS, Producto.Id.ZUCARACHAS]
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
		primera, _unidad(Producto.Id.PURA_COLA), ObjetoDelAlmacen.new()
	]:
		assert_int(recepcion.recibir(objeto, true)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	assert_int(recepcion.recibir(_unidad(), true)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	assert_int(recepcion.recibir(_unidad(), true)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	assert_int(recepcion.unidades().size()).is_equal(2)


func test_tia_rechaza_otra_zucarachas_y_conserva_el_pedido_entero() -> void:  # AC-CTR-037
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var atencion := Atencion.new(
		Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[1], inventario
	)
	atencion.interactuar(null)
	atencion.interactuar(null)
	var estante := Estante.new(inventario, Catalogo.todos())
	var primera := estante.retirar(Catalogo.de(Producto.Id.ZUCARACHAS))
	assert_int(atencion.interactuar(primera)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	var recepcion: RecepcionDeCompra = atencion.get("_recepcion")
	assert_int(recepcion.pendientes(primera.producto)).is_zero()
	assert_int(recepcion.pendientes(Catalogo.de(Producto.Id.PEPITO))).is_equal(1)
	for objeto: ObjetoDelAlmacen in [
		primera,
		estante.retirar(primera.producto),
		_unidad(Producto.Id.PURA_COLA),
		ObjetoDelAlmacen.new()
	]:
		assert_int(atencion.interactuar(objeto)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
		assert_array(recepcion.unidades()).contains_exactly([primera])
		assert_bool(atencion.vendida()).is_false()
	assert_int(atencion.interactuar(null)).is_equal(RecepcionDeCompra.Resultado.DIALOGO)
	# El recordatorio nombra sólo lo que falta: el Pepito, y no la Zucarachas ya recibida.
	assert_int(atencion.dialogo().entrada_actual().count("[color=#e4f850]")).is_equal(1)
	assert_str(atencion.dialogo().entrada_actual()).not_contains(primera.producto.nombre)


func test_el_ticket_compara_cantidades_sin_orden() -> void:  # AC-CTR-038
	var pedido := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[1].pedido()
	for ids: Array in [
		[Producto.Id.ZUCARACHAS, Producto.Id.PEPITO],
		[Producto.Id.PEPITO, Producto.Id.ZUCARACHAS],
	]:
		var recepcion := RecepcionDeCompra.new(pedido)
		assert_int(recepcion.recibir(_ticket(ids), true)).is_equal(
			RecepcionDeCompra.Resultado.ACEPTADA
		)
		assert_bool(recepcion.completa()).is_false()
		assert_array(recepcion.unidades()).is_empty()
	for ids: Array in [
		[],
		[Producto.Id.PEPITO],
		[Producto.Id.ZUCARACHAS],
		[Producto.Id.ZUCARACHAS, Producto.Id.ZUCARACHAS, Producto.Id.PEPITO],
		[Producto.Id.ZUCARACHAS, Producto.Id.PEPITO, Producto.Id.PURA_COLA],
	]:
		var recepcion := RecepcionDeCompra.new(pedido)
		var papel := _ticket(ids)
		assert_int(recepcion.recibir(papel, true)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
		assert_array(recepcion.unidades()).is_empty()
		assert_bool(recepcion.completa()).is_false()
		assert_object(recepcion.get("_ticket")).is_null()


# AC-CTR-038, AC-CTR-039
func test_solo_productos_no_completan_y_el_ultimo_elemento_completa() -> void:
	var recepcion := RecepcionDeCompra.new(_pedido())
	for unidad: UnidadDeProducto in [_unidad(), _unidad(), _unidad(Producto.Id.PEPITO)]:
		assert_int(recepcion.recibir(unidad, true)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	assert_bool(recepcion.completa()).is_false()
	assert_int(recepcion.recibir(_ticket(), true)).is_equal(RecepcionDeCompra.Resultado.COMPLETA)
	assert_int(recepcion.recibir(_ticket(), true)).is_equal(RecepcionDeCompra.Resultado.BLOQUEADA)
	var otra := RecepcionDeCompra.new(_pedido())
	assert_int(otra.unidades().size()).is_zero()
