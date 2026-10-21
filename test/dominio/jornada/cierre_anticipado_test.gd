extends GdUnitTestSuite


func _cumplidas_salvo(jornada: int, pendiente: Tarea = null) -> Array[Tarea]:
	var obligatorias := Apertura.obligatorias(jornada)
	for tarea in obligatorias:
		if pendiente == null or tarea.tipo() != pendiente.tipo():
			tarea.completar()
	return obligatorias


func test_cada_obligatoria_es_necesaria_y_solo_salen_las_noches_de_prueba() -> void:  # AC-SHF-036
	for jornada: int in range(1, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1):
		var de_prueba := jornada < ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
		assert_bool(CierreAnticipado.corresponde(jornada, _cumplidas_salvo(jornada))).is_equal(
			de_prueba
		)
		for pendiente in Apertura.obligatorias(jornada):
			(
				assert_bool(
					CierreAnticipado.corresponde(jornada, _cumplidas_salvo(jornada, pendiente))
				)
				. is_false()
			)
	assert_bool(CierreAnticipado.corresponde(0, _cumplidas_salvo(0))).is_false()


func test_perder_y_recuperar_cualquier_tarea_cambia_el_permiso() -> void:  # AC-SHF-041
	for jornada: int in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	):
		var tareas := _cumplidas_salvo(jornada)
		for tarea in tareas:
			assert_bool(CierreAnticipado.corresponde(jornada, tareas)).is_true()
			assert_bool(tarea.descompletar()).is_true()
			assert_bool(CierreAnticipado.corresponde(jornada, tareas)).is_false()
			assert_bool(tarea.completar()).is_true()
			assert_bool(CierreAnticipado.corresponde(jornada, tareas)).is_true()


func test_ventas_de_gondola_no_exigen_reponer() -> void:  # AC-STK-094, AC-SHF-036
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
		assert_bool(CierreAnticipado.corresponde(1, partida.obligatorias())).is_true()
		partida.cerrar_la_jornada(turno.tareas_cumplidas())
		assert_int(partida.medios()).is_zero()
		assert_int(partida.antecedentes().fallas(Tarea.Tipo.REPONER)).is_zero()
		assert_array(DevolucionDelJefe.new(1, partida).mensajes()).is_empty()
		assert_array(estante.casilleros_vacios(producto)).has_size(cantidad)
