extends GdUnitTestSuite


func test_la_primera_completa_apila_exactamente_los_dieciseis_ausentes() -> void:  # AC-STK-077
	var ausentes: Array[Producto.Id] = []
	for id: Producto.Id in Producto.Id.values():
		if id not in Catalogo.PRODUCTOS_DE_PRUEBA:
			ausentes.append(id)
	(
		assert_array(
			Apertura.productos_con_cajas_apiladas(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
		)
		. contains_exactly(ausentes)
	)


func test_ninguna_otra_jornada_tiene_una_llegada_de_cajas() -> void:  # AC-STK-077
	for jornada: int in range(1, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1):
		if jornada == ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA:
			continue
		assert_array(Apertura.productos_con_cajas_apiladas(jornada)).is_empty()
