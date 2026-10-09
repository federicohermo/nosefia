extends GdUnitTestSuite


func test_los_bordes_de_ambas_ventanas() -> void:  # AC-CTR-034
	var compradores := Compradores.de_la_jornada(1)
	var agenda := AgendaDeCompradores.new(compradores)
	assert_str(compradores[0].nombre()).is_equal("Martín")
	assert_str(compradores[1].nombre()).is_equal("Tiago")
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


func test_un_salto_recibe_y_vence_en_orden() -> void:  # AC-CTR-035
	var agenda := AgendaDeCompradores.new(Compradores.de_la_jornada(1))
	var eventos := agenda.avanzar(Reglas.DURACION_DEL_TURNO)
	assert_int(eventos.size()).is_equal(4)
	assert_str(eventos[0].comprador.nombre()).is_equal("Martín")
	assert_int(eventos[0].tipo).is_equal(AgendaDeCompradores.Tipo.LLEGO)
	assert_int(eventos[1].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)
	assert_str(eventos[2].comprador.nombre()).is_equal("Tiago")
	assert_int(eventos[2].tipo).is_equal(AgendaDeCompradores.Tipo.LLEGO)
	assert_int(eventos[3].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)
	assert_object(agenda.presente()).is_null()


func test_una_compra_completa_no_vence() -> void:  # AC-CTR-039
	var compradores := Compradores.de_la_jornada(1)
	var agenda := AgendaDeCompradores.new(compradores)
	agenda.avanzar(compradores[0].horario.x)
	assert_int(agenda.avanzar(compradores[0].horario.y, [compradores[0]]).size()).is_zero()


func test_otras_jornadas_conservan_el_padron() -> void:  # AC-CTR-041
	for jornada in range(2, 6):
		var compradores := Compradores.de_la_jornada(jornada)
		assert_str(compradores[0].nombre()).is_equal("Marta")
		assert_bool(compradores[0].tiene_horario()).is_false()
	(
		assert_int(
			Compradores.de_la_jornada(1)[1].pedido().unidades_de(
				Catalogo.de(Producto.Id.ZUCARACHAS)
			)
		)
		. is_equal(2)
	)
