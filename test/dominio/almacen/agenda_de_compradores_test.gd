extends GdUnitTestSuite


func test_los_bordes_de_ambas_ventanas() -> void:  # AC-CTR-034
	var compradores := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	var agenda := AgendaDeCompradores.new(compradores)
	assert_that(compradores[0].horario).is_equal(Vector2(1800, 10800))
	assert_that(compradores[1].horario).is_equal(Vector2(12600, 21600))
	for fila: Array in [
		[Producto.Id.MAROLINI, 1], [Producto.Id.PURA_COLA, 1], [Producto.Id.MALBARDO, 1]
	]:
		assert_int(compradores[0].pedido().unidades_de(Catalogo.de(fila[0]))).is_equal(fila[1])
	assert_int(compradores[1].pedido().unidades_de(Catalogo.de(Producto.Id.ZUCARACHAS))).is_equal(1)
	assert_int(compradores[1].pedido().unidades_de(Catalogo.de(Producto.Id.PEPITO))).is_equal(1)
	assert_str(compradores[0].nombre()).is_equal("Tin")
	assert_str(compradores[1].nombre()).is_equal("Tia")
	for i in 2:
		var ventana := compradores[i].horario
		assert_int(agenda.avanzar(ventana.x - 1.0).size()).is_zero()
		var llegada := agenda.avanzar(ventana.x)
		assert_int(llegada.size()).is_equal(1)
		assert_int(llegada[0].tipo).is_equal(AgendaDeCompradores.Tipo.LLEGO)
		assert_object(llegada[0].comprador).is_same(compradores[i])
		assert_int(agenda.avanzar(ventana.x).size()).is_zero()
		assert_int(agenda.avanzar(ventana.y - 1.0).size()).is_zero()
		var salida := agenda.avanzar(ventana.y)
		assert_int(salida.size()).is_equal(1)
		assert_int(salida[0].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)
		assert_int(agenda.avanzar(ventana.y).size()).is_zero()


func _segundos(hora: Vector2i) -> float:
	var horas := posmod(hora.x - Reglas.HORA_DE_APERTURA, Marcador.HORAS_POR_DIA)
	return float((horas * Marcador.MINUTOS_POR_HORA + hora.y) * Marcador.SEGUNDOS_POR_MINUTO)


func test_tia_llega_y_se_va_segun_cuando_se_retira_tin() -> void:  # AC-CTR-106
	var casos := [
		# [cuándo se completa Tin (null: nunca), llegada de Tia, límite de Tia]
		[null, Vector2i(23, 30), Vector2i(2, 0)],
		[Vector2i(21, 0), Vector2i(21, 30), Vector2i(0, 0)],
		[Vector2i(23, 0), Vector2i(23, 30), Vector2i(2, 0)],
	]
	for caso: Array in casos:
		var compradores := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
		var tin := compradores[0]
		var tia := compradores[1]
		var agenda := AgendaDeCompradores.new(compradores)
		var completas: Array[Comprador] = []
		agenda.avanzar(tin.horario.x)
		if caso[0] == null:
			agenda.avanzar(tin.horario.y)
		else:
			completas.append(tin)
			agenda.avanzar(_segundos(caso[0]), completas)
		var llegada := _segundos(caso[1])
		var limite := _segundos(caso[2])
		assert_array(agenda.avanzar(llegada - 1.0, completas)).is_empty()
		var llego := agenda.avanzar(llegada, completas)
		assert_array(llego).has_size(1)
		assert_int(llego[0].tipo).is_equal(AgendaDeCompradores.Tipo.LLEGO)
		assert_object(llego[0].comprador).is_same(tia)
		assert_array(agenda.avanzar(llegada, completas)).is_empty()
		assert_array(agenda.avanzar(limite - 1.0, completas)).is_empty()
		var vencio := agenda.avanzar(limite, completas)
		assert_array(vencio).has_size(1)
		assert_int(vencio[0].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)
		assert_array(agenda.avanzar(limite, completas)).is_empty()


func test_un_salto_recibe_y_vence_en_orden() -> void:  # AC-CTR-035
	var agenda := AgendaDeCompradores.new(
		Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	)
	var eventos := agenda.avanzar(Reglas.DURACION_DEL_TURNO)
	assert_int(eventos.size()).is_equal(4)
	assert_str(eventos[0].comprador.nombre()).is_equal("Tin")
	assert_int(eventos[0].tipo).is_equal(AgendaDeCompradores.Tipo.LLEGO)
	assert_int(eventos[1].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)
	assert_str(eventos[2].comprador.nombre()).is_equal("Tia")
	assert_int(eventos[2].tipo).is_equal(AgendaDeCompradores.Tipo.LLEGO)
	assert_int(eventos[3].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)


func test_una_compra_completa_no_vence() -> void:  # AC-CTR-039
	var compradores := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	var agenda := AgendaDeCompradores.new(compradores)
	agenda.avanzar(compradores[0].horario.x)
	assert_int(agenda.avanzar(compradores[0].horario.y, [compradores[0]]).size()).is_zero()


func test_otras_jornadas_conservan_el_padron() -> void:  # AC-CTR-041
	for jornada: int in [
		ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA
	]:
		var compradores := Compradores.de_la_jornada(jornada)
		assert_str(compradores[0].nombre()).is_equal("Marta")
		assert_bool(compradores[0].tiene_horario()).is_false()
	(
		assert_int(
			Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[1].pedido().unidades_de(
				Catalogo.de(Producto.Id.ZUCARACHAS)
			)
		)
		. is_equal(1)
	)


func test_los_bordes_de_fede_y_mia_en_la_segunda_jornada() -> void:  # AC-CTR-050
	var compradores := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	assert_str(compradores[0].nombre()).is_equal("Fede")
	assert_str(compradores[1].nombre()).is_equal("Mía")
	assert_that(compradores[0].horario).is_equal(Vector2(4500, 13500))
	assert_that(compradores[1].horario).is_equal(Vector2(18000, 27000))
	var agenda := AgendaDeCompradores.new(compradores)
	for comprador in compradores:
		var ventana := comprador.horario
		assert_int(agenda.avanzar(ventana.x - 1.0).size()).is_zero()
		var llegada := agenda.avanzar(ventana.x)
		assert_int(llegada.size()).is_equal(1)
		assert_int(llegada[0].tipo).is_equal(AgendaDeCompradores.Tipo.LLEGO)
		assert_object(llegada[0].comprador).is_same(comprador)
		assert_int(agenda.avanzar(ventana.x).size()).is_zero()
		assert_int(agenda.avanzar(ventana.y - 1.0).size()).is_zero()
		var salida := agenda.avanzar(ventana.y)
		assert_int(salida.size()).is_equal(1)
		assert_int(salida[0].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)
		assert_int(agenda.avanzar(ventana.y).size()).is_zero()
	var salto := AgendaDeCompradores.new(
		Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	)
	var eventos := salto.avanzar(Reglas.DURACION_DEL_TURNO)
	assert_int(eventos.size()).is_equal(4)
	for indice in 4:
		assert_str(eventos[indice].comprador.nombre()).is_equal(
			["Fede", "Fede", "Mía", "Mía"][indice]
		)
		(
			assert_int(eventos[indice].tipo)
			. is_equal(
				[
					AgendaDeCompradores.Tipo.LLEGO,
					AgendaDeCompradores.Tipo.VENCIO,
					AgendaDeCompradores.Tipo.LLEGO,
					AgendaDeCompradores.Tipo.VENCIO,
				][indice]
			)
		)


func test_tin_y_tia_no_atienden_la_segunda_ni_el_padron() -> void:  # AC-CTR-026
	var jornadas: Array[int] = [ReglasDeLaPartida.PRIMERA_JORNADA + 1]
	jornadas.append(ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA)
	for jornada in jornadas:
		for comprador in Compradores.de_la_jornada(jornada):
			assert_array(["Tin", "Tia"]).not_contains([comprador.nombre()])
