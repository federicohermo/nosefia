extends GdUnitTestSuite


func test_la_inicial_vacia_no_bloquea_la_recepcion() -> void:  # AC-CTR-014, AC-CTR-048
	var comprador := Compradores.de_la_jornada(1)[0]
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
	var comprador := Compradores.de_la_jornada(1)[0]
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
