extends GdUnitTestSuite


func test_el_fin_se_publica_solo_en_la_pulsacion_que_termina() -> void:  # AC-CTR-047
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var obligatorias := Apertura.obligatorias(4)
	reloj.arrancar(Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias), obligatorias)
	var ventanilla: Ventanilla = auto_free(Ventanilla.new())
	ventanilla.reloj = reloj
	var compradores := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	var dialogos := DialogosDeCompradores.new()
	dialogos.tin = PackedStringArray(["Una sola entrada"])
	compradores[0].dialogos = dialogos
	ventanilla.arrancar(TareaDeAtender.new(compradores, Inventario.new(Catalogo.todos())))
	reloj.avanzar(120.0)
	var finales: Array[bool] = []
	ventanilla.conversacion_terminada.connect(func() -> void: finales.append(true))
	ventanilla.pedir_interaccion(null)
	assert_array(finales).is_empty()
	assert_str(ventanilla.atencion().dialogo().entrada_actual()).is_equal("Una sola entrada")
	ventanilla.pedir_interaccion(null)
	assert_array(finales).has_size(1)
	assert_bool(ventanilla.atencion().dialogo().terminado()).is_true()


func test_entregar_publica_el_texto_sin_publicar_el_fin_de_una_conversacion() -> void:  # AC-CTR-096
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var obligatorias := Apertura.obligatorias(4)
	reloj.arrancar(Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias), obligatorias)
	var ventanilla: Ventanilla = auto_free(Ventanilla.new())
	ventanilla.reloj = reloj
	var compradores := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	ventanilla.arrancar(TareaDeAtender.new(compradores, inventario))
	reloj.avanzar(120.0)
	var finales: Array[bool] = []
	var textos: Array[String] = []
	ventanilla.conversacion_terminada.connect(func() -> void: finales.append(true))
	ventanilla.entrega_dicha.connect(func(texto: String) -> void: textos.append(texto))
	ventanilla.pedir_interaccion(null)
	while ventanilla.atencion().abre_la_ventanilla():
		ventanilla.pedir_interaccion(null)
	assert_array(textos).is_empty()
	var finales_de_la_inicial := finales.size()
	var estante := Estante.new(inventario, Catalogo.todos())
	var producto := ventanilla.atencion().comprador().pedido().productos()[0]
	ventanilla.pedir_interaccion(estante.retirar(producto))
	ventanilla.pedir_interaccion(null)
	assert_array(textos).has_size(2)
	assert_array(finales).has_size(finales_de_la_inicial)


## Una ventanilla con la primera entrada ya dicha, lista para recibir productos.
func _lista_para_recibir() -> Array:
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var obligatorias := Apertura.obligatorias(4)
	reloj.arrancar(Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias), obligatorias)
	var ventanilla: Ventanilla = auto_free(Ventanilla.new())
	ventanilla.reloj = reloj
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	ventanilla.arrancar(
		TareaDeAtender.new(Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA), inventario)
	)
	reloj.avanzar(120.0)
	ventanilla.pedir_interaccion(null)
	while ventanilla.atencion().abre_la_ventanilla():
		ventanilla.pedir_interaccion(null)
	return [ventanilla, Estante.new(inventario, Catalogo.todos())]


func test_cada_producto_que_el_comprador_recibe_se_publica_una_vez() -> void:
	var lista := _lista_para_recibir()
	var ventanilla: Ventanilla = lista[0]
	var estante: Estante = lista[1]
	var entregados: Array[UnidadDeProducto] = []
	ventanilla.producto_entregado.connect(
		func(unidad: UnidadDeProducto) -> void: entregados.append(unidad)
	)
	var esperados: Array[UnidadDeProducto] = []
	var pedido := ventanilla.atencion().comprador().pedido()
	for producto in pedido.productos():
		for _unidad in pedido.unidades_de(producto):
			var unidad := estante.retirar(producto)
			assert_array(entregados).has_size(esperados.size())
			ventanilla.pedir_interaccion(unidad)
			esperados.append(unidad)
			assert_array(entregados).is_equal(esperados)


func test_lo_que_el_comprador_rechaza_o_no_es_un_producto_no_se_publica() -> void:
	var lista := _lista_para_recibir()
	var ventanilla: Ventanilla = lista[0]
	var estante: Estante = lista[1]
	var entregados: Array[UnidadDeProducto] = []
	ventanilla.producto_entregado.connect(
		func(unidad: UnidadDeProducto) -> void: entregados.append(unidad)
	)
	var pedido := ventanilla.atencion().comprador().pedido()
	var ajeno: Producto = null
	for candidato in Catalogo.todos():
		if not pedido.productos().has(candidato):
			ajeno = candidato
			break
	assert_object(ajeno).is_not_null()
	var rechazo := ventanilla.pedir_interaccion(estante.retirar(ajeno))
	assert_int(rechazo).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	ventanilla.pedir_interaccion(Ticket.new([]))
	ventanilla.pedir_interaccion(null)
	assert_array(entregados).is_empty()


func test_el_ultimo_producto_que_completa_el_pedido_se_publica_tras_el_ticket() -> void:
	var lista := _lista_para_recibir()
	var ventanilla: Ventanilla = lista[0]
	var estante: Estante = lista[1]
	var entregados: Array[UnidadDeProducto] = []
	ventanilla.producto_entregado.connect(
		func(unidad: UnidadDeProducto) -> void: entregados.append(unidad)
	)
	var pedido := ventanilla.atencion().comprador().pedido()
	var renglones: Array[Producto] = []
	for producto in pedido.productos():
		for _unidad in pedido.unidades_de(producto):
			renglones.append(producto)
	var del_ticket := ventanilla.pedir_interaccion(Ticket.new(renglones))
	assert_int(del_ticket).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	assert_array(entregados).is_empty()
	var esperados: Array[UnidadDeProducto] = []
	var ultimo := RecepcionDeCompra.Resultado.BLOQUEADA
	for producto in renglones:
		var unidad := estante.retirar(producto)
		ultimo = ventanilla.pedir_interaccion(unidad)
		esperados.append(unidad)
		assert_array(entregados).is_equal(esperados)
	assert_int(ultimo).is_equal(RecepcionDeCompra.Resultado.COMPLETA)
