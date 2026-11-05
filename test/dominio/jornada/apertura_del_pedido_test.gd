## La sexta noche declara el pedido al proveedor, y sólo ella (BR-SHF-031).
extends GdUnitTestSuite

const PEDIDO := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3


func test_solo_la_jornada_del_pedido_lo_declara() -> void:  # AC-SHF-087
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
	):
		(
			assert_bool(Apertura.pide(jornada, Tarea.Tipo.PEDIR_AL_PROVEEDOR))
			. override_failure_message("jornada %d" % jornada)
			. is_equal(jornada == PEDIDO)
		)
		var declara := false
		for tarea in Apertura.obligatorias(jornada):
			declara = declara or tarea.tipo() == Tarea.Tipo.PEDIR_AL_PROVEEDOR
		assert_bool(declara).is_equal(jornada == PEDIDO)


func test_la_nota_lista_el_pedido_despues_de_las_fijas() -> void:  # AC-SHF-087
	var nota := NotaPegada.tareas_a_realizar(Apertura.obligatorias(PEDIDO))
	var nombres := nota.renglones()
	assert_int(nombres.size()).is_equal(Apertura.cantidad_de_obligatorias(PEDIDO))
	assert_str(nombres.back()).is_equal(
		NotaPegada.NOMBRES_DE_LAS_TAREAS[Tarea.Tipo.PEDIR_AL_PROVEEDOR]
	)
	for fija in Apertura.FIJAS:
		var propio: String = NotaPegada.NOMBRES_DE_LAS_TAREAS[fija]
		assert_int(nombres.find(propio)).is_greater_equal(0)
		assert_int(nombres.find(propio)).is_less(nombres.size() - 1)


func test_dos_aperturas_de_la_sexta_dan_pedidos_nuevos_y_sin_cumplir() -> void:  # AC-SHF-087
	var primera := Apertura.obligatorias(PEDIDO)
	for tarea in primera:
		tarea.completar()
	for tarea in Apertura.obligatorias(PEDIDO):
		assert_bool(primera.has(tarea)).is_false()
		assert_bool(tarea.completada()).is_false()
