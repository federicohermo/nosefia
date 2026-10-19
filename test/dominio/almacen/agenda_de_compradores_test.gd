extends GdUnitTestSuite

# `[llegada de Tin, límite de Tin, llegada de Tia, límite de Tia]`, en segundos desde las 20:00.
const VENTANAS_DE_LA_INTRODUCCION := {
	1: [3600.0, 18000.0, 21600.0, 36000.0],
	2: [5400.0, 15000.0, 27000.0, 36600.0],
	3: [9000.0, 18000.0, 30600.0, 39600.0],
}


func test_los_bordes_de_ambas_ventanas() -> void:  # AC-CTR-034
	var compradores := Compradores.de_la_jornada(4)
	var agenda := AgendaDeCompradores.new(compradores)
	assert_that(compradores[0].horario).is_equal(Vector2(7200, 14400))
	assert_that(compradores[1].horario).is_equal(Vector2(28800, 36000))
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


func test_un_salto_recibe_y_vence_en_orden() -> void:  # AC-CTR-035
	var agenda := AgendaDeCompradores.new(Compradores.de_la_jornada(4))
	var eventos := agenda.avanzar(Reglas.DURACION_DEL_TURNO)
	assert_int(eventos.size()).is_equal(4)
	assert_str(eventos[0].comprador.nombre()).is_equal("Tin")
	assert_int(eventos[0].tipo).is_equal(AgendaDeCompradores.Tipo.LLEGO)
	assert_int(eventos[1].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)
	assert_str(eventos[2].comprador.nombre()).is_equal("Tia")
	assert_int(eventos[2].tipo).is_equal(AgendaDeCompradores.Tipo.LLEGO)
	assert_int(eventos[3].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)


func test_una_compra_completa_no_vence() -> void:  # AC-CTR-039
	var compradores := Compradores.de_la_jornada(4)
	var agenda := AgendaDeCompradores.new(compradores)
	agenda.avanzar(compradores[0].horario.x)
	assert_int(agenda.avanzar(compradores[0].horario.y, [compradores[0]]).size()).is_zero()


func test_otras_jornadas_conservan_el_padron() -> void:  # AC-CTR-041
	for jornada in range(6, 9):
		var compradores := Compradores.de_la_jornada(jornada)
		assert_str(compradores[0].nombre()).is_equal("Marta")
		assert_bool(compradores[0].tiene_horario()).is_false()
	(
		assert_int(
			Compradores.de_la_jornada(4)[1].pedido().unidades_de(
				Catalogo.de(Producto.Id.ZUCARACHAS)
			)
		)
		. is_equal(1)
	)


#


func test_las_ventanas_de_la_introduccion() -> void:  # AC-CTR-068
	var completa := Compradores.de_la_jornada(4)
	for jornada: int in VENTANAS_DE_LA_INTRODUCCION:
		var ventanas: Array = VENTANAS_DE_LA_INTRODUCCION[jornada]
		var compradores := Compradores.de_la_jornada(jornada)
		var agenda := AgendaDeCompradores.new(compradores)
		for i in 2:
			assert_str(compradores[i].nombre()).is_equal(completa[i].nombre())
			for producto in completa[i].pedido().productos():
				assert_int(compradores[i].pedido().unidades_de(producto)).is_equal(
					completa[i].pedido().unidades_de(producto)
				)
			var llegada: float = ventanas[2 * i]
			var limite: float = ventanas[2 * i + 1]
			var mensaje := "jornada %d, %s" % [jornada, compradores[i].nombre()]
			(
				assert_int(agenda.avanzar(llegada - 1.0).size())
				. override_failure_message(mensaje)
				. is_zero()
			)
			var llego := agenda.avanzar(llegada)
			assert_int(llego.size()).override_failure_message(mensaje).is_equal(1)
			assert_int(llego[0].tipo).is_equal(AgendaDeCompradores.Tipo.LLEGO)
			(
				assert_int(agenda.avanzar(limite - 1.0).size())
				. override_failure_message(mensaje)
				. is_zero()
			)
			var vencio := agenda.avanzar(limite)
			assert_int(vencio.size()).override_failure_message(mensaje).is_equal(1)
			assert_int(vencio[0].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)
