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


func _atender_de(jornada: int) -> TareaDeAtender:
	return TareaDeAtender.new(
		Compradores.de_la_jornada(jornada),
		Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	)


func _salvo_atender(jornada: int) -> Array[Tarea]:
	return _cumplidas_salvo(jornada, Tarea.new(Tarea.Tipo.CAJA))


func test_la_puerta_deja_salir_cuando_se_fue_el_ultimo_mal_atendido() -> void:  # AC-SHF-048
	for jornada: int in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	):
		var compradores := Compradores.de_la_jornada(jornada)
		assert_bool(compradores[0].horario.y < compradores[1].horario.x).is_true()
		var atender := _atender_de(jornada)
		var obligatorias := _salvo_atender(jornada)
		assert_bool(CierreAnticipado.corresponde(jornada, obligatorias, atender)).is_false()
		atender.avanzar(compradores[0].horario.x)
		assert_bool(CierreAnticipado.corresponde(jornada, obligatorias, atender)).is_false()
		atender.avanzar(compradores[0].horario.y)
		assert_bool(CierreAnticipado.corresponde(jornada, obligatorias, atender)).is_false()
		atender.avanzar(compradores[1].horario.x)
		assert_bool(CierreAnticipado.corresponde(jornada, obligatorias, atender)).is_false()
		atender.avanzar(compradores[1].horario.y)
		assert_int(atender.mal_atendidos()).is_equal(compradores.size())
		assert_bool(CierreAnticipado.corresponde(jornada, obligatorias, atender)).is_true()
		assert_bool(atender.completada()).is_false()


func test_con_las_compras_cerradas_las_demas_obligatorias_siguen_trabando() -> void:  # AC-SHF-048
	for jornada: int in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	):
		var atender := _atender_de(jornada)
		atender.avanzar(Compradores.de_la_jornada(jornada)[-1].horario.y)
		assert_bool(atender.compras_cerradas()).is_true()
		for pendiente in Apertura.obligatorias(jornada):
			var obligatorias := _cumplidas_salvo(jornada, pendiente)
			assert_bool(CierreAnticipado.corresponde(jornada, obligatorias, atender)).is_equal(
				pendiente.tipo() == Tarea.Tipo.CAJA
			)


func test_vender_al_ultimo_con_el_anterior_mal_atendido_deja_salir() -> void:  # AC-SHF-048
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var compradores := Compradores.de_la_jornada(jornada)
	var atender := TareaDeAtender.new(compradores, inventario)
	var obligatorias := _salvo_atender(jornada)
	atender.avanzar(compradores[0].horario.y)
	atender.avanzar(compradores[1].horario.x)
	assert_bool(CierreAnticipado.corresponde(jornada, obligatorias, atender)).is_false()
	var atencion := atender.atencion()
	atencion.interactuar(null)
	atencion.interactuar(null)
	var productos: Array[Producto] = []
	for producto in compradores[1].pedido().productos():
		atencion.interactuar(Estante.new(inventario, Catalogo.todos()).retirar(producto))
		productos.append(producto)
	assert_bool(CierreAnticipado.corresponde(jornada, obligatorias, atender)).is_false()
	assert_int(atencion.interactuar(Ticket.new(productos))).is_equal(
		RecepcionDeCompra.Resultado.COMPLETA
	)
	assert_bool(CierreAnticipado.corresponde(jornada, obligatorias, atender)).is_true()
	assert_int(atender.mal_atendidos()).is_equal(1)
	assert_bool(atender.completada()).is_false()


func test_sin_compradores_fisicos_la_atencion_se_cumple_como_antes() -> void:  # AC-SHF-048
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var obligatorias := _salvo_atender(jornada)
	var sin_nadie := TareaDeAtender.new([], inventario)
	assert_bool(CierreAnticipado.corresponde(jornada, obligatorias, sin_nadie)).is_true()
	var virtuales: Array[Comprador] = []
	virtuales.assign(Compradores.padron().slice(0, 2))
	var virtual := TareaDeAtender.new(virtuales, inventario)
	assert_bool(virtual.fisica()).is_false()
	assert_bool(CierreAnticipado.corresponde(jornada, obligatorias, virtual)).is_false()
	var tareas := _cumplidas_salvo(jornada)
	assert_bool(CierreAnticipado.corresponde(jornada, tareas, virtual)).is_true()


func test_la_primera_jornada_completa_no_sale_con_las_compras_cerradas() -> void:  # AC-SHF-048
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	var atender := _atender_de(jornada)
	atender.avanzar(Compradores.de_la_jornada(jornada)[-1].horario.y)
	assert_bool(atender.compras_cerradas()).is_true()
	(
		assert_bool(
			CierreAnticipado.corresponde(
				jornada, _cumplidas_salvo(jornada, Tarea.new(Tarea.Tipo.CAJA)), atender
			)
		)
		. is_false()
	)
