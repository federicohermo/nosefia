extends GdUnitTestSuite


func _cumplidas_salvo(jornada: int, pendientes: Array[Tarea.Tipo]) -> Array[Tarea]:
	var obligatorias := Apertura.obligatorias(jornada)
	for tarea in obligatorias:
		if tarea.tipo() not in pendientes:
			tarea.completar()
	return obligatorias


func test_cerradas_las_compras_con_lo_demas_cumplido_corresponde() -> void:  # AC-SHF-031
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var sin_cobrar := _cumplidas_salvo(jornada, [Tarea.Tipo.CAJA])
	assert_bool(CierreAnticipado.corresponde(jornada, false, false, sin_cobrar)).is_false()
	assert_bool(CierreAnticipado.corresponde(jornada, true, false, sin_cobrar)).is_true()
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, true, false, _cumplidas_salvo(jornada, []))
		)
		. is_true()
	)


func test_el_que_espera_o_no_llego_no_deja_acelerar() -> void:  # AC-SHF-032
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var compradores := Compradores.de_la_jornada(jornada)
	assert_array(compradores).is_not_empty()
	var tarea := TareaDeAtender.new(
		compradores, Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	)
	var cumplidas := _cumplidas_salvo(jornada, [Tarea.Tipo.CAJA])
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, tarea.compras_cerradas(), false, cumplidas)
		)
		. is_false()
	)
	tarea.avanzar(compradores[-1].horario.x)
	assert_object(tarea.en_ventanilla()).is_same(compradores[-1])
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, tarea.compras_cerradas(), false, cumplidas)
		)
		. is_false()
	)
	tarea.avanzar(compradores[-1].horario.y)
	assert_bool(tarea.compras_cerradas()).is_true()
	assert_bool(tarea.completada()).is_false()
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, tarea.compras_cerradas(), false, cumplidas)
		)
		. is_true()
	)


func test_una_obligatoria_pendiente_que_no_es_cobrar_no_deja_acelerar() -> void:  # AC-SHF-032
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var probadas := 0
	for tarea in Apertura.obligatorias(jornada):
		if tarea.tipo() == Tarea.Tipo.CAJA:
			continue
		var pendientes: Array[Tarea.Tipo] = [tarea.tipo()]
		var obligatorias := _cumplidas_salvo(jornada, pendientes)
		(
			assert_bool(CierreAnticipado.corresponde(jornada, true, false, obligatorias))
			. override_failure_message(str(tarea.tipo()))
			. is_false()
		)
		probadas += 1
	assert_int(probadas).is_greater(0)


func test_sin_compradores_las_compras_estan_cerradas() -> void:  # AC-SHF-032
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var nadie := TareaDeAtender.new([], Inventario.new([]))
	var cumplidas := _cumplidas_salvo(jornada, [Tarea.Tipo.CAJA])
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, nadie.compras_cerradas(), false, cumplidas)
		)
		. is_true()
	)


func test_solo_la_primera_noche_acelera() -> void:  # AC-SHF-035
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
	):
		var todas := _cumplidas_salvo(jornada, [])
		(
			assert_bool(CierreAnticipado.corresponde(jornada, true, false, todas))
			. override_failure_message("jornada %d" % jornada)
			. is_equal(jornada == ReglasDeLaPartida.PRIMERA_JORNADA)
		)


func test_sin_ventas_el_registro_que_coincide_deja_acelerar() -> void:  # AC-SHF-032
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var compradores := Compradores.de_la_jornada(jornada)
	var tarea := TareaDeAtender.new(
		compradores, Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	)
	tarea.avanzar(compradores[-1].horario.y)
	assert_bool(tarea.compras_cerradas()).is_true()
	var registro := RegistroDeVentas.new(Catalogo.todos(), tarea)
	assert_bool(tarea.completada()).is_false()
	assert_bool(registro.completada()).is_false()
	var obligatorias := _cumplidas_salvo(jornada, [Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR])
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, true, registro.completada(true), obligatorias)
		)
		. is_true()
	)
	registro.sumar(Catalogo.todos()[0])
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, true, registro.completada(true), obligatorias)
		)
		. is_false()
	)
	assert_bool(Apertura.pide(jornada, Tarea.Tipo.REPONER)).is_false()
	assert_bool(CierreAnticipado.corresponde(jornada, true, true, obligatorias)).is_true()


func test_ventas_de_gondola_no_exigen_reponer() -> void:  # AC-STK-094, AC-SHF-031
	for cantidad: int in [1, 3]:
		var producto := Catalogo.de(Producto.Id.MAROLINI)
		var pedido := Venta.new()
		pedido.agregar(producto, cantidad)
		var modelo := Compradores.de_la_jornada(1)[0]
		var comprador := Comprador.new(modelo.nombre(), pedido, pedido.total())
		comprador.horario = modelo.horario
		comprador.personaje = modelo.personaje
		comprador.dialogos = modelo.dialogos
		var compradores: Array[Comprador] = [comprador]
		var casilleros: Dictionary[Producto.Id, int] = {producto.id: 3}
		var inventario := Apertura.inventario_de_la_jornada(
			1, compradores, casilleros, casilleros, RandomNumberGenerator.new()
		)
		var estante := Estante.new(inventario, [producto])
		var atender := TareaDeAtender.new(compradores, inventario)
		var registro := RegistroDeVentas.new(Catalogo.todos(), atender)
		atender.avanzar(comprador.horario.x)
		var atencion := atender.atencion()
		assert_object(atencion).is_not_null()
		atencion.interactuar(null)
		for _entrada in 8:
			if atencion.puede_abandonar():
				break
			atencion.interactuar(null)
		assert_bool(atencion.puede_abandonar()).is_true()
		var renglones: Array[Producto] = []
		for _unidad in cantidad:
			var unidad := estante.agarrar(producto, estante.casilleros_ocupados(producto)[0])
			assert_object(unidad).is_not_null()
			assert_int(atencion.interactuar(unidad)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
			assert_bool(registro.sumar(producto)).is_true()
			renglones.append(producto)
		assert_int(atencion.interactuar(Ticket.new(renglones))).is_equal(
			RecepcionDeCompra.Resultado.COMPLETA
		)
		assert_bool(atender.completada()).is_true()
		assert_bool(registro.completada()).is_true()
		assert_bool(estante.completada()).is_false()
		assert_array(estante.casilleros_vacios(producto)).has_size(cantidad)
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(
			3 - cantidad
		)
		var partida := Partida.nueva()
		var turno := partida.abrir_la_jornada()
		for tarea in partida.obligatorias():
			if tarea.tipo() == Tarea.Tipo.CAJA and atender.completada():
				turno.completar(tarea)
			elif tarea.tipo() == Tarea.Tipo.REGISTRAR and registro.completada():
				turno.completar(tarea)
		assert_bool(turno.todas_cumplidas()).is_true()
		assert_int(turno.tareas_cumplidas()).is_equal(2)
		(
			assert_bool(
				CierreAnticipado.corresponde(
					1, atender.compras_cerradas(), registro.completada(), partida.obligatorias()
				)
			)
			. is_true()
		)
		partida.cerrar_la_jornada(turno.tareas_cumplidas())
		assert_int(partida.medios()).is_zero()
		assert_int(partida.antecedentes().fallas(Tarea.Tipo.REPONER)).is_zero()
		assert_array(DevolucionDelJefe.new(1, partida).mensajes()).is_empty()
		assert_array(estante.casilleros_vacios(producto)).has_size(cantidad)
