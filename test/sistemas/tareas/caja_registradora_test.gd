extends GdUnitTestSuite


func test_publica_lectura_y_cambio_solo_cuando_anota() -> void:  # AC-CTR-021, AC-CTR-022
	var caja: CajaRegistradora = auto_free(CajaRegistradora.new())
	caja.arrancar(GeneradorDeTickets.new())
	var avisos: Array[String] = []
	var rechazos: Array[int] = []
	caja.producto_leido.connect(func() -> void: avisos.append("leido"))
	caja.renglones_cambiados.connect(func() -> void: avisos.append("cambiado"))
	caja.lectura_rechazada.connect(func(motivo: int) -> void: rechazos.append(motivo))
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI))
	for renglon in GeneradorDeTickets.RENGLONES:
		caja.pedir_anotar(unidad)
	assert_array(avisos).contains_exactly(
		["leido", "cambiado", "leido", "cambiado", "leido", "cambiado"]
	)
	caja.pedir_anotar(unidad)
	caja.pedir_anotar(ObjetoDelAlmacen.new())
	assert_array(rechazos).contains_exactly(
		[GeneradorDeTickets.Resultado.LLENO, GeneradorDeTickets.Resultado.NO_ES_PRODUCTO]
	)
	assert_int(avisos.size()).is_equal(6)


func test_borrar_publica_la_vista_vacia() -> void:  # AC-CTR-023
	var caja: CajaRegistradora = auto_free(CajaRegistradora.new())
	var generador := GeneradorDeTickets.new()
	caja.arrancar(generador)
	caja.pedir_anotar(UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI)))
	var cambios: Array[int] = [0]
	caja.renglones_cambiados.connect(func() -> void: cambios[0] += 1)
	caja.pedir_borrar()
	assert_array(generador.renglones()).is_empty()
	assert_int(cambios[0]).is_equal(1)


func test_imprimir_publica_el_papel_y_no_un_cambio_del_programa() -> void:  # AC-CTR-023, AC-CTR-024
	var caja: CajaRegistradora = auto_free(CajaRegistradora.new())
	caja.arrancar(GeneradorDeTickets.new())
	var impresos: Array[Ticket] = []
	var cambios: Array[int] = [0]
	caja.ticket_impreso.connect(func(ticket: Ticket) -> void: impresos.append(ticket))
	caja.renglones_cambiados.connect(func() -> void: cambios[0] += 1)
	caja.pedir_imprimir()
	assert_array(impresos).is_empty()
	var producto := Catalogo.de(Producto.Id.MAROLINI)
	caja.pedir_anotar(UnidadDeProducto.new(producto))
	var cambios_antes := cambios[0]
	caja.pedir_imprimir()
	assert_int(impresos.size()).is_equal(1)
	if impresos.is_empty():
		return
	assert_array(impresos[0].renglones()).contains_exactly([producto])
	assert_array(caja.generador().renglones()).contains_exactly([producto])
	assert_int(cambios[0]).is_equal(cambios_antes)


func test_otra_jornada_reemplaza_el_programa_y_avisa_la_vista() -> void:  # AC-CTR-025
	var caja: CajaRegistradora = auto_free(CajaRegistradora.new())
	var anterior := GeneradorDeTickets.new()
	caja.arrancar(anterior)
	caja.pedir_anotar(UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI)))
	var cambios: Array[int] = [0]
	caja.renglones_cambiados.connect(func() -> void: cambios[0] += 1)
	var nuevo := GeneradorDeTickets.new()
	caja.arrancar(nuevo)
	assert_object(caja.generador()).is_same(nuevo)
	assert_array(nuevo.renglones()).is_empty()
	assert_int(anterior.renglones().size()).is_equal(1)
	assert_int(cambios[0]).is_equal(1)


func test_sin_generador_el_cableado_avisa_y_no_publica_eventos() -> void:
	var caja: CajaRegistradora = auto_free(CajaRegistradora.new())
	var avisos: Array[String] = []
	caja.producto_leido.connect(func() -> void: avisos.append("leido"))
	caja.lectura_rechazada.connect(func(_motivo: int) -> void: avisos.append("rechazo"))
	caja.renglones_cambiados.connect(func() -> void: avisos.append("cambiado"))
	caja.ticket_impreso.connect(func(_ticket: Ticket) -> void: avisos.append("impreso"))
	await assert_error(caja.pedir_borrar).is_push_error(
		"Caja registradora sin generador: revisar almacen.gd"
	)
	await assert_error(caja.pedir_imprimir).is_push_error(
		"Caja registradora sin generador: revisar almacen.gd"
	)
	await (
		assert_error(func() -> void: caja.pedir_anotar(ObjetoDelAlmacen.new()))
		. is_push_error("Caja registradora sin generador: revisar almacen.gd")
	)
	assert_array(avisos).is_empty()
