extends GdUnitTestSuite


func _disposicion(
	jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
) -> DisposicionDeLaGondola:
	if jornada < ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA:
		return load("res://src/escenas/puestos/disposicion_de_prueba.tres")
	return load("res://src/escenas/puestos/disposicion_de_la_gondola.tres")


func _casilleros_medidos(
	jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
) -> Dictionary[Producto.Id, int]:
	var disposicion := _disposicion(jornada)
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		casilleros[producto.id] = disposicion.casilleros_de(producto.id)
	return casilleros


func _casilleros_reponibles(
	jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
) -> Dictionary[Producto.Id, int]:
	var disposicion := _disposicion(jornada)
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		casilleros[producto.id] = disposicion.filas_de_adelante[producto.id]
	return casilleros


func _comprobar_guias_llenas(
	estante: Estante,
	totales: Dictionary[Producto.Id, int],
	principales: Dictionary[Producto.Id, int]
) -> void:
	for producto in Catalogo.todos():
		assert_int(estante.cupo(producto)).is_equal(totales[producto.id])
		var guias := totales[producto.id] - principales[producto.id]
		var ocupados := estante.casilleros_ocupados(producto)
		for casillero in guias:
			assert_bool(ocupados.has(casillero)).is_true()


func _azar(semilla: int) -> RandomNumberGenerator:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	return azar


func _completar_compra_fisica(atencion: Atencion, estante: Estante, desde_gondola: bool) -> int:
	atencion.interactuar(null)
	while not atencion.dialogo().terminado():
		atencion.interactuar(null)
	var productos_del_ticket: Array[Producto] = []
	var vaciados := 0
	for producto in atencion.comprador().pedido().productos():
		for unidad in atencion.comprador().pedido().unidades_de(producto):
			var ocupados := estante.casilleros_ocupados(producto)
			var sacada: UnidadDeProducto
			if desde_gondola and not ocupados.is_empty():
				var antes := estante.unidades_en_gondola(producto)
				sacada = estante.agarrar(producto, ocupados[0])
				assert_int(estante.unidades_en_gondola(producto)).is_equal(antes - 1)
				vaciados += 1
			else:
				sacada = estante.retirar(producto)
			assert_object(sacada).is_not_null()
			assert_int(atencion.interactuar(sacada)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
			productos_del_ticket.append(producto)
	assert_int(atencion.interactuar(Ticket.new(productos_del_ticket))).is_equal(
		RecepcionDeCompra.Resultado.COMPLETA
	)
	assert_bool(atencion.vendida()).is_true()
	return vaciados


func test_doscientas_semillas_venden_y_reponen() -> void:  # AC-STK-033, AC-STK-035, AC-STK-099
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	for jornada in range(primera + 1, primera + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		var casilleros := _casilleros_medidos(jornada)
		var reponibles := _casilleros_reponibles(jornada)
		for semilla in 200:
			# La noche de compras físicas se recorre dos veces: cajas y casilleros ocupados.
			for desde_gondola: bool in (
				[false, true] if jornada == Compradores.JORNADA_DE_FEDE_Y_MIA else [false]
			):
				var compradores := Compradores.de_la_jornada(jornada)
				var inventario := Apertura.inventario_de_la_jornada(
					jornada, compradores, casilleros, reponibles, _azar(semilla)
				)
				var estante := Estante.new(inventario, Catalogo.de_la_jornada(jornada))
				_comprobar_guias_llenas(estante, casilleros, reponibles)
				assert_bool(estante.completada()).is_false()
				var tarea := TareaDeAtender.new(compradores, inventario)
				var huecos_por_ventas := 0
				for comprador in compradores:
					var atencion: Atencion
					if tarea.fisica():
						tarea.avanzar(comprador.horario.x)
						atencion = tarea.atencion()
						assert_object(atencion.comprador()).is_same(comprador)
						huecos_por_ventas += _completar_compra_fisica(
							atencion, estante, desde_gondola
						)
					else:
						assert_object(tarea.atender()).is_same(comprador)
						atencion = tarea.atencion()
						assert_int(atencion.cobrar()).is_equal(Atencion.Resultado.COBRADA)
					assert_bool(atencion.vendida()).is_true()
				assert_bool(tarea.completada()).is_true()
				if desde_gondola:
					assert_int(huecos_por_ventas).is_greater(0)
				for producto in Catalogo.de_la_jornada(jornada):
					for casillero in estante.casilleros_vacios(producto):
						var unidad := estante.retirar(producto)
						assert_object(unidad).is_not_null()
						assert_int(estante.colocar_unidad(unidad, producto, casillero)).is_equal(
							Estante.Rechazo.NINGUNO
						)
					assert_int(estante.unidades_en_gondola(producto)).is_equal(
						casilleros[producto.id]
					)
				assert_bool(estante.completada()).is_true()


func _faltantes_de(almacen: Node3D) -> Dictionary[Producto.Id, int]:
	var estante: Estante = almacen.get("_repositor").estante()
	var faltantes: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		var falta := estante.cupo(producto) - estante.unidades_en_gondola(producto)
		if falta > 0:
			faltantes[producto.id] = falta
	return faltantes


func test_la_escena_reproduce_y_continua_el_azar_de_la_apertura() -> void:  # AC-STK-034
	var escena := load("res://src/escenas/almacen.tscn") as PackedScene
	var almacen: Node3D = auto_free(escena.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	assert_dict(puesto.call("casilleros")).is_equal(_casilleros_medidos())
	assert_dict(puesto.call("casilleros_reponibles")).is_equal(_casilleros_reponibles())
	var azar: RandomNumberGenerator = almacen.get("azar_de_la_apertura")
	var control := _azar(17)
	azar.seed = 17
	for jornada: int in [
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA,
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA,
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
	]:
		var esperado := Apertura.faltantes_al_azar(
			Apertura.pedidos_de(Compradores.de_la_jornada(jornada)),
			_casilleros_reponibles(),
			control
		)
		almacen.call("_al_abrir_la_jornada", jornada)
		_comprobar_guias_llenas(
			almacen.get("_repositor").estante(), _casilleros_medidos(), _casilleros_reponibles()
		)
		assert_dict(_faltantes_de(almacen)).is_equal(esperado)
		assert_int(azar.state).is_equal(control.state)
		assert_object(almacen.get("azar_de_la_apertura")).is_same(azar)
	azar.seed = 17
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	var primera := _faltantes_de(almacen)
	azar.seed = 17
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	assert_dict(_faltantes_de(almacen)).is_equal(primera)
