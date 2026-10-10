extends GdUnitTestSuite


func test_se_llena_en_orden_y_repite_productos() -> void:  # AC-CTR-021
	var generador := GeneradorDeTickets.new()
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	var coracola := Catalogo.de(Producto.Id.CORACOLA)
	for producto: Producto in [marolini, marolini, coracola]:
		assert_int(generador.anotar(UnidadDeProducto.new(producto))).is_equal(
			GeneradorDeTickets.Resultado.ANOTADO
		)
	assert_array(generador.renglones()).contains_exactly([marolini, marolini, coracola])
	(
		assert_int(generador.anotar(UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))))
		. is_equal(GeneradorDeTickets.Resultado.LLENO)
	)
	assert_array(generador.renglones()).contains_exactly([marolini, marolini, coracola])


func test_una_caja_no_se_confunde_con_su_producto() -> void:  # AC-CTR-022
	var generador := GeneradorDeTickets.new()
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	generador.anotar(UnidadDeProducto.new(marolini))
	for id: StringName in [&"caja", &"mopa", &"balde", &"jabon", &"bolsa"]:
		var objeto := ObjetoDelAlmacen.new()
		objeto.id = id
		assert_int(generador.anotar(objeto)).is_equal(GeneradorDeTickets.Resultado.NO_ES_PRODUCTO)
		assert_array(generador.renglones()).contains_exactly([marolini])
	assert_int(generador.anotar(Ticket.new([marolini]))).is_equal(
		GeneradorDeTickets.Resultado.NO_ES_PRODUCTO
	)
	assert_array(generador.renglones()).contains_exactly([marolini])


func test_sin_unidad_valida_no_se_anota_nada() -> void:  # AC-CTR-022
	var generador := GeneradorDeTickets.new()
	for objeto: ObjetoDelAlmacen in [null, UnidadDeProducto.new()]:
		assert_int(generador.anotar(objeto)).is_equal(GeneradorDeTickets.Resultado.NO_ES_PRODUCTO)
		assert_array(generador.renglones()).is_empty()


func test_el_rechazo_por_tipo_precede_al_programa_lleno() -> void:  # AC-CTR-022
	var generador := GeneradorDeTickets.new()
	for renglon in GeneradorDeTickets.RENGLONES:
		generador.anotar(UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI)))
	assert_int(generador.anotar(ObjetoDelAlmacen.new())).is_equal(
		GeneradorDeTickets.Resultado.NO_ES_PRODUCTO
	)


func test_imprimir_y_borrar_preserva_el_papel() -> void:  # AC-CTR-023
	var generador := GeneradorDeTickets.new()
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	var coracola := Catalogo.de(Producto.Id.CORACOLA)
	generador.anotar(UnidadDeProducto.new(marolini))
	generador.anotar(UnidadDeProducto.new(coracola))
	var ticket := generador.imprimir()
	assert_object(ticket).is_not_null()
	assert_array(generador.renglones()).contains_exactly([marolini, coracola])
	assert_array(ticket.renglones()).contains_exactly([marolini, coracola])
	generador.borrar()
	assert_array(generador.renglones()).is_empty()
	assert_array(ticket.renglones()).contains_exactly([marolini, coracola])


func test_los_tres_vacios_no_imprimen() -> void:  # AC-CTR-024
	var generador := GeneradorDeTickets.new()
	assert_object(generador.imprimir()).is_null()
	generador.borrar()
	assert_object(generador.imprimir()).is_null()


func test_la_lectura_de_renglones_no_permite_borrarlos() -> void:  # AC-CTR-023
	var generador := GeneradorDeTickets.new()
	var producto := Catalogo.de(Producto.Id.MAROLINI)
	generador.anotar(UnidadDeProducto.new(producto))
	var lectura := generador.renglones()
	lectura.clear()
	assert_array(generador.renglones()).contains_exactly([producto])


func test_dos_impresiones_son_dos_papeles_independientes() -> void:  # AC-CTR-023
	var generador := GeneradorDeTickets.new()
	var producto := Catalogo.de(Producto.Id.MAROLINI)
	generador.anotar(UnidadDeProducto.new(producto))
	var primero := generador.imprimir()
	var segundo := generador.imprimir()
	assert_object(primero).is_not_same(segundo)
	assert_array(primero.renglones()).contains_exactly([producto])
	assert_array(segundo.renglones()).contains_exactly([producto])


func test_el_modo_sale_de_la_jornada_y_no_del_estado_anterior() -> void:  # AC-CTR-026
	assert_int(GeneradorDeTickets.JORNADA_SIN_LECTOR).is_equal(3)
	for jornada: int in [1, 2, 3, 4, 5, 10]:
		var generador := GeneradorDeTickets.para_la_jornada(jornada)
		assert_bool(generador.es_manual()).is_equal(jornada >= 3)
		assert_array(generador.renglones()).is_empty()
		for indice in GeneradorDeTickets.RENGLONES:
			assert_object(generador.en_el_renglon(indice)).is_null()
	var nueva := GeneradorDeTickets.para_la_jornada(1)
	assert_bool(nueva.es_manual()).is_false()


func test_cada_posicion_manual_elige_catalogo_y_vacio_sin_mover_otras() -> void:  # AC-CTR-027
	var generador := GeneradorDeTickets.para_la_jornada(3)
	for producto: Producto in Catalogo.todos():
		for indice in GeneradorDeTickets.RENGLONES:
			assert_bool(generador.elegir(indice, producto)).is_true()
			assert_object(generador.en_el_renglon(indice)).is_same(producto)
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	for indice in GeneradorDeTickets.RENGLONES:
		assert_bool(generador.elegir(indice, marolini)).is_true()
	var impreso := generador.imprimir()
	assert_object(impreso).is_not_null()
	if impreso != null:
		assert_array(impreso.renglones()).contains_exactly([marolini, marolini, marolini])
	assert_bool(generador.elegir(1, null)).is_true()
	assert_object(generador.en_el_renglon(0)).is_same(marolini)
	assert_object(generador.en_el_renglon(1)).is_null()
	assert_object(generador.en_el_renglon(2)).is_same(marolini)


func test_un_indice_invalido_y_el_modo_automatico_rechazan_la_eleccion() -> void:  # AC-CTR-027
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	for jornada: int in [2, 3]:
		var generador := GeneradorDeTickets.para_la_jornada(jornada)
		if jornada == 2:
			generador.anotar(UnidadDeProducto.new(marolini))
		else:
			generador.elegir(0, marolini)
		for indice: int in [-1, 3]:
			assert_bool(generador.elegir(indice, null)).is_false()
			assert_object(generador.en_el_renglon(indice)).is_null()
		assert_array(generador.renglones()).contains_exactly([marolini])
	var automatico := GeneradorDeTickets.para_la_jornada(2)
	for indice in GeneradorDeTickets.RENGLONES:
		assert_bool(automatico.elegir(indice, marolini)).is_false()
	assert_array(automatico.renglones()).is_empty()


func test_solo_el_segundo_o_tercero_imprime_sin_mover_su_posicion() -> void:  # AC-CTR-028
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	var coracola := Catalogo.de(Producto.Id.CORACOLA)
	for elegido: int in [1, 2]:
		var generador := GeneradorDeTickets.para_la_jornada(3)
		assert_bool(generador.elegir(elegido, marolini)).is_true()
		var papel := generador.imprimir()
		assert_object(papel).is_not_null()
		if papel == null:
			continue
		assert_array(papel.renglones()).contains_exactly([marolini])
		for indice in GeneradorDeTickets.RENGLONES:
			assert_object(generador.en_el_renglon(indice)).is_same(
				marolini if indice == elegido else null
			)
		generador.elegir(elegido, coracola)
		generador.borrar()
		assert_array(papel.renglones()).contains_exactly([marolini])
		assert_object(generador.imprimir()).is_null()
		for indice in GeneradorDeTickets.RENGLONES:
			assert_object(generador.en_el_renglon(indice)).is_null()
	var dos := GeneradorDeTickets.para_la_jornada(3)
	dos.elegir(1, marolini)
	dos.elegir(2, coracola)
	var impreso := dos.imprimir()
	assert_object(impreso).is_not_null()
	if impreso != null:
		assert_array(impreso.renglones()).contains_exactly([marolini, coracola])
	assert_object(dos.en_el_renglon(0)).is_null()
	assert_object(dos.en_el_renglon(1)).is_same(marolini)
	assert_object(dos.en_el_renglon(2)).is_same(coracola)


func test_sin_lector_precede_al_tipo_y_al_lleno_y_no_toca_el_programa() -> void:  # AC-CTR-029
	var generador := GeneradorDeTickets.para_la_jornada(3)
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	for lleno: bool in [false, true]:
		if lleno:
			for indice in GeneradorDeTickets.RENGLONES:
				generador.elegir(indice, marolini)
		var antes := generador.renglones()
		for objeto: ObjetoDelAlmacen in [
			null,
			UnidadDeProducto.new(),
			UnidadDeProducto.new(marolini),
			ObjetoDelAlmacen.new(),
			Ticket.new()
		]:
			assert_int(generador.anotar(objeto)).is_equal(GeneradorDeTickets.Resultado.SIN_LECTOR)
			assert_array(generador.renglones()).contains_exactly(antes)
