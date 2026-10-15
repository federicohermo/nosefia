extends GdUnitTestSuite


func _casilleros_medidos() -> Dictionary[Producto.Id, int]:
	var disposicion: DisposicionDeLaGondola = load(
		"res://src/escenas/puestos/disposicion_de_la_gondola.tres"
	)
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		casilleros[producto.id] = disposicion.casilleros_de(producto.id)
	return casilleros


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


func test_doscientas_semillas_venden_y_reponen_con_cupos_reales() -> void:  # AC-STK-035
	var casilleros := _casilleros_medidos()
	for jornada in range(1, 6):
		for semilla in 200:
			# La primera noche se recorre dos veces: cajas y casilleros ocupados.
			for desde_gondola: bool in [false, true] if jornada == 1 else [false]:
				var compradores := Compradores.de_la_jornada(jornada)
				var inventario := Apertura.inventario_de_la_jornada(
					compradores, casilleros, _azar(semilla)
				)
				var estante := Estante.new(inventario, Catalogo.todos())
				assert_bool(estante.completada()).is_false()
				var tarea := TareaDeAtender.new(compradores, inventario)
				var huecos_por_ventas := 0
				for comprador in compradores:
					var atencion: Atencion
					if jornada == 1:
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
				for producto in Catalogo.todos():
					for casillero in estante.casilleros_vacios(producto):
						var unidad := estante.retirar(producto)
						assert_object(unidad).is_not_null()
						assert_int(estante.colocar_unidad(unidad, casillero)).is_equal(
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
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var azar: RandomNumberGenerator = almacen.get("azar_de_la_apertura")
	var control := _azar(17)
	azar.seed = 17
	for jornada: int in [1, 1, 2]:
		var esperado := Apertura.faltantes_al_azar(
			Apertura.pedidos_de(Compradores.de_la_jornada(jornada)), _casilleros_medidos(), control
		)
		almacen.call("_al_abrir_la_jornada", jornada)
		assert_dict(_faltantes_de(almacen)).is_equal(esperado)
		assert_int(azar.state).is_equal(control.state)
		assert_object(almacen.get("azar_de_la_apertura")).is_same(azar)
	azar.seed = 17
	almacen.call("_al_abrir_la_jornada", 1)
	var primera := _faltantes_de(almacen)
	azar.seed = 17
	almacen.call("_al_abrir_la_jornada", 1)
	assert_dict(_faltantes_de(almacen)).is_equal(primera)
