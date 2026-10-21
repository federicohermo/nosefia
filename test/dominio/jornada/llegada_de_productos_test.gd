extends GdUnitTestSuite


func test_la_cuarta_jornada_apila_exactamente_los_dieciseis_ausentes() -> void:  # AC-STK-077
	var ausentes: Array[Producto.Id] = []
	for id: Producto.Id in Producto.Id.values():
		if id not in Catalogo.PRODUCTOS_DE_PRUEBA:
			ausentes.append(id)
	assert_array(Apertura.productos_con_cajas_apiladas(4)).contains_exactly(ausentes)


func test_ninguna_otra_jornada_tiene_una_llegada_de_cajas() -> void:  # AC-STK-077
	for jornada: int in [1, 2, 3, 5, 6, 7, 8]:
		assert_array(Apertura.productos_con_cajas_apiladas(jornada)).is_empty()
