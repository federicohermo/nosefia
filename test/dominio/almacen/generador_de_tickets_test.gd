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
