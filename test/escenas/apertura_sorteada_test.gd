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


## Las tandas que mide el puesto numeran, una vez cada uno, todos los casilleros del producto, y
## la primera es la reponible.
func _comprobar_tandas(
	puesto: Node3D, totales: Dictionary[Producto.Id, int], reponibles: Dictionary[Producto.Id, int]
) -> void:
	var tandas: Dictionary[Producto.Id, Array] = puesto.call("tandas")
	for producto in Catalogo.todos():
		var numerados: Array[int] = []
		for tanda: PackedInt32Array in tandas[producto.id]:
			numerados.append_array(Array(tanda))
		numerados.sort()
		assert_array(numerados).is_equal(range(totales[producto.id]))
		assert_int(tandas[producto.id][0].size()).is_equal(reponibles[producto.id])


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
			var fisica := Compradores.de_la_jornada(jornada, semilla)[0].tiene_horario()
			for desde_gondola: bool in [false, true] if fisica else [false]:
				var compradores := Compradores.de_la_jornada(jornada, semilla)
				var inventario := Apertura.inventario_de_la_jornada(
					jornada, compradores, casilleros, reponibles, _azar(semilla)
				)
				var estante := Estante.new(inventario, Catalogo.de_la_jornada(jornada))
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


func _almacen_de(partida: Partida) -> Node3D:
	var escena := load("res://src/escenas/almacen.tscn") as PackedScene
	var almacen: Node3D = auto_free(escena.instantiate())
	almacen.set("_partida", partida)
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func _faltantes_de(almacen: Node3D) -> Dictionary[Producto.Id, int]:
	var estante: Estante = almacen.get("_repositor").estante()
	var faltantes: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		var falta := estante.cupo(producto) - estante.unidades_en_gondola(producto)
		if falta > 0:
			faltantes[producto.id] = falta
	return faltantes


func test_la_escena_reproduce_y_continua_el_azar_de_la_apertura() -> void:  # AC-STK-034
	var almacen := _almacen_de(
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA})
	)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	assert_dict(puesto.call("casilleros")).is_equal(_casilleros_medidos())
	_comprobar_tandas(puesto, _casilleros_medidos(), _casilleros_reponibles())
	var azar: RandomNumberGenerator = almacen.get("azar_de_la_apertura")
	var control := _azar(17)
	azar.seed = 17
	for jornada: int in [
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA,
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA,
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
	]:
		almacen.call("_al_abrir_la_jornada", jornada)
		var compradores: Array[Comprador] = almacen.get("_atenciones").tarea().get("_compradores")
		var de_una_fila: Dictionary[Producto.Id, bool] = puesto.call("productos_de_una_fila")
		var tandas: Dictionary[Producto.Id, Array] = puesto.call("tandas")
		var esperado := Apertura.vacios_de_la_jornada(
			jornada, compradores, tandas, de_una_fila, control
		)
		var estante: Estante = almacen.get("_repositor").estante()
		for producto in Catalogo.todos():
			assert_array(estante.casilleros_vacios(producto)).is_equal(
				esperado.get(producto.id, [])
			)
		assert_dict(_faltantes_de(almacen)).is_equal(Apertura.faltantes_de(esperado))
		assert_int(azar.state).is_equal(control.state)
		assert_object(almacen.get("azar_de_la_apertura")).is_same(azar)
	azar.seed = 17
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	var primera := _faltantes_de(almacen)
	azar.seed = 17
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	assert_dict(_faltantes_de(almacen)).is_equal(primera)


func _productos_de(compradores: Array[Comprador]) -> Array:
	var ids: Array = []
	for comprador in compradores:
		for producto in comprador.pedido().productos():
			ids.append(producto.id)
	return ids


func test_la_escena_sortea_con_la_semilla_de_la_partida() -> void:  # AC-CTR-072, AC-CTR-073
	var tercera := ReglasDeLaPartida.PRIMERA_JORNADA + 2
	var partida := Partida.desde({"jornada": tercera})
	var almacen := _almacen_de(partida)
	var esperados := _productos_de(Compradores.de_la_jornada(tercera, partida.semilla))
	for _apertura in 2:
		almacen.call("_al_abrir_la_jornada", tercera)
		var compradores: Array[Comprador] = almacen.get("_atenciones").tarea().get("_compradores")
		assert_array(_productos_de(compradores)).is_equal(esperados)
