extends GdUnitTestSuite


func test_la_inicial_vacia_no_bloquea_la_recepcion() -> void:  # AC-CTR-014, AC-CTR-048
	var comprador := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[0]
	comprador.dialogos = DialogosDeCompradores.new()
	var inventario := Inventario.new(Catalogo.todos())
	for producto in Catalogo.todos():
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 8)
	var atencion := Atencion.new(comprador, inventario)
	assert_int(atencion.interactuar(null)).is_equal(RecepcionDeCompra.Resultado.DIALOGO)
	assert_bool(atencion.puede_abandonar()).is_true()
	var producto := comprador.pedido().productos()[0]
	var unidad := Estante.new(inventario, Catalogo.todos()).retirar(producto)
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)


func test_consultar_no_termina_la_inicial_ni_recibe_el_ticket() -> void:  # AC-PLY-094
	var comprador := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[0]
	var atencion := Atencion.new(comprador, Inventario.new(Catalogo.todos()))
	var ticket := Ticket.new([])
	assert_int(atencion.contexto_de_interaccion(ticket).primario).is_equal(
		ReferenciaDeControles.Linea.HABLAR
	)
	assert_bool(atencion.conversacion_iniciada()).is_false()
	atencion.interactuar(null)
	while not atencion.puede_abandonar():
		assert_int(atencion.contexto_de_interaccion(ticket).primario).is_equal(
			ReferenciaDeControles.Linea.HABLAR
		)
		atencion.interactuar(null)
	assert_int(atencion.contexto_de_interaccion(ticket).primario).is_equal(
		ReferenciaDeControles.Linea.ENTREGAR
	)
	assert_int(atencion.contexto_de_interaccion(null).primario).is_equal(
		ReferenciaDeControles.Linea.HABLAR
	)
	assert_bool(atencion.vendida()).is_false()


func test_recibir_agradece_sin_retener_y_lo_repetido_ya_estaba() -> void:  # AC-CTR-067
	var comprador := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[1]
	var inventario := Inventario.new(Catalogo.todos())
	for producto in Catalogo.todos():
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 8)
	var estante := Estante.new(inventario, Catalogo.todos())
	var atencion := Atencion.new(comprador, inventario)
	atencion.interactuar(null)
	while not atencion.puede_abandonar():
		atencion.interactuar(null)
	var primero := comprador.pedido().productos()[0]
	var segundo := comprador.pedido().productos()[1]
	var unidad := estante.retirar(primero)
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	(
		assert_bool(atencion.dialogo().entrada_actual().begins_with(DialogosDeCompradores.FALTA))
		. is_true()
	)
	assert_bool(atencion.puede_abandonar()).is_true()
	# El agradecimiento no se come el clic: lo repetido se ofrece y se contesta en el mismo.
	var otra := estante.retirar(primero)
	assert_int(atencion.interactuar(otra)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	assert_str(atencion.dialogo().entrada_actual()).is_equal(DialogosDeCompradores.YA_ENTREGADO)
	# Lo ya entregado tampoco retiene: la misma unidad en la mano se vuelve a contestar.
	assert_bool(atencion.puede_abandonar()).is_true()
	assert_int(atencion.interactuar(otra)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	assert_str(atencion.dialogo().entrada_actual()).is_equal(DialogosDeCompradores.YA_ENTREGADO)
	assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	assert_str(atencion.dialogo().entrada_actual()).is_equal(DialogosDeCompradores.YA_ENTREGADO)
	var ajeno := estante.retirar(Catalogo.de(Producto.Id.MALBARDO))
	assert_int(atencion.interactuar(ajeno)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	(
		assert_bool(atencion.dialogo().entrada_actual().begins_with(DialogosDeCompradores.RECHAZO))
		. is_true()
	)
	assert_bool(atencion.puede_abandonar()).is_true()
	assert_int(atencion.interactuar(estante.retirar(segundo))).is_equal(
		RecepcionDeCompra.Resultado.ACEPTADA
	)
	# Con el último producto recibido ya no falta nada: el agradecimiento pide el ticket.
	assert_str(atencion.dialogo().entrada_actual()).is_equal(DialogosDeCompradores.PIDE_EL_TICKET)
