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
	await (
		assert_error(func() -> void: caja.pedir_elegir(0, null))
		. is_push_error("Caja registradora sin generador: revisar almacen.gd")
	)
	assert_array(avisos).is_empty()


func test_arrancar_publica_el_modo_de_cada_jornada_y_la_vista_vacia() -> void:  # AC-CTR-026
	var caja: CajaRegistradora = auto_free(CajaRegistradora.new())
	var modos: Array[bool] = []
	var cambios: Array[int] = [0]
	caja.programa_arrancado.connect(func(manual: bool) -> void: modos.append(manual))
	caja.renglones_cambiados.connect(func() -> void: cambios[0] += 1)
	for jornada: int in [2, 3, 4, 5, 1]:
		var generador := GeneradorDeTickets.para_la_jornada(jornada)
		caja.arrancar(generador)
		assert_object(caja.generador()).is_same(generador)
	assert_array(modos).contains_exactly([false, true, true, true, false])
	assert_int(cambios[0]).is_equal(5)


func test_elegir_publica_solo_un_cambio_aceptado_y_no_una_lectura() -> void:  # AC-CTR-027
	var caja: CajaRegistradora = auto_free(CajaRegistradora.new())
	var cambios: Array[int] = [0]
	var sonidos: Array[String] = []
	caja.renglones_cambiados.connect(func() -> void: cambios[0] += 1)
	caja.producto_leido.connect(func() -> void: sonidos.append("leido"))
	caja.lectura_rechazada.connect(func(_motivo: int) -> void: sonidos.append("rechazo"))
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	caja.arrancar(GeneradorDeTickets.para_la_jornada(2))
	caja.pedir_elegir(1, marolini)
	assert_int(cambios[0]).is_equal(1)
	assert_array(caja.generador().renglones()).is_empty()
	caja.arrancar(GeneradorDeTickets.para_la_jornada(3))
	for indice: int in [-1, 3]:
		caja.pedir_elegir(indice, marolini)
	assert_int(cambios[0]).is_equal(2)
	caja.pedir_elegir(1, marolini)
	assert_int(cambios[0]).is_equal(3)
	assert_object(caja.generador().en_el_renglon(1)).is_same(marolini)
	assert_object(caja.generador().en_el_renglon(0)).is_null()
	caja.pedir_elegir(1, null)
	assert_int(cambios[0]).is_equal(4)
	assert_object(caja.generador().en_el_renglon(1)).is_null()
	assert_array(sonidos).is_empty()


func test_usar_el_hueco_es_silencioso_tanto_vacio_como_lleno() -> void:  # AC-CTR-029
	var caja: CajaRegistradora = auto_free(CajaRegistradora.new())
	caja.arrancar(GeneradorDeTickets.para_la_jornada(3))
	var avisos: Array[String] = []
	caja.producto_leido.connect(func() -> void: avisos.append("leido"))
	caja.lectura_rechazada.connect(func(_motivo: int) -> void: avisos.append("rechazo"))
	caja.renglones_cambiados.connect(func() -> void: avisos.append("cambio"))
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	for lleno: bool in [false, true]:
		if lleno:
			for indice in GeneradorDeTickets.RENGLONES:
				caja.pedir_elegir(indice, marolini)
		avisos.clear()
		var antes := caja.generador().renglones()
		for objeto: ObjetoDelAlmacen in [
			null, UnidadDeProducto.new(marolini), ObjetoDelAlmacen.new()
		]:
			caja.pedir_anotar(objeto)
		assert_array(avisos).is_empty()
		assert_array(caja.generador().renglones()).contains_exactly(antes)


func test_desechar_avisa_solo_el_papel_y_conserva_el_programa() -> void:  # AC-CTR-031, AC-CTR-032
	var caja: CajaRegistradora = auto_free(CajaRegistradora.new())
	var eventos: Array[String] = []
	caja.ticket_desechado.connect(func() -> void: eventos.append("descarte"))
	caja.producto_leido.connect(func() -> void: eventos.append("lectura"))
	caja.lectura_rechazada.connect(func(_motivo: int) -> void: eventos.append("rechazo"))
	caja.renglones_cambiados.connect(func() -> void: eventos.append("cambio"))
	for jornada: int in [1, 3, 5]:
		var generador := GeneradorDeTickets.para_la_jornada(jornada)
		var producto := Catalogo.de(Producto.Id.MAROLINI)
		if generador.es_manual():
			generador.elegir(2, producto)
		else:
			generador.anotar(UnidadDeProducto.new(producto))
		caja.arrancar(generador)
		eventos.clear()
		var papel := Ticket.new([producto])
		assert_bool(caja.pedir_desechar(papel, ReglasDeLaLimpieza.ID_DEL_INODORO)).is_true()
		assert_array(eventos).contains_exactly(["descarte"])
		assert_array(generador.renglones()).contains_exactly([producto])
		assert_object(generador.en_el_renglon(2 if generador.es_manual() else 0)).is_same(producto)
		eventos.clear()
		assert_bool(caja.pedir_desechar(papel, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)).is_false()
		assert_bool(caja.pedir_desechar(null, ReglasDeLaLimpieza.ID_DEL_INODORO)).is_false()
		(
			assert_bool(
				caja.pedir_desechar(ObjetoDelAlmacen.new(), ReglasDeLaLimpieza.ID_DEL_INODORO)
			)
			. is_false()
		)
		assert_array(eventos).is_empty()
		assert_array(generador.renglones()).contains_exactly([producto])


func test_desechar_no_requiere_un_programa_de_renglones() -> void:  # AC-CTR-031
	var caja: CajaRegistradora = auto_free(CajaRegistradora.new())
	var eventos: Array[int] = []
	caja.ticket_desechado.connect(func() -> void: eventos.append(1))
	assert_bool(caja.pedir_desechar(Ticket.new(), ReglasDeLaLimpieza.ID_DEL_INODORO)).is_true()
	assert_array(eventos).contains_exactly([1])
