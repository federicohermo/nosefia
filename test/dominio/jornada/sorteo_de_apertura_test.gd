extends GdUnitTestSuite


func _azar(semilla: int) -> RandomNumberGenerator:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	return azar


func _casilleros(cantidad: int = 8) -> Dictionary[Producto.Id, int]:
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		casilleros[producto.id] = cantidad
	return casilleros


func test_doscientas_semillas_por_jornada_respetan_limites_y_varian() -> void:  # AC-STK-034
	for jornada in range(1, 6):
		var compradores := Compradores.de_la_jornada(jornada)
		var pedidos := Apertura.pedidos_de(compradores)
		var cantidades: Dictionary[int, bool] = {}
		var conjuntos: Dictionary[String, bool] = {}
		for semilla in 200:
			var faltantes := Apertura.faltantes_al_azar(pedidos, _casilleros(), _azar(semilla))
			assert_int(faltantes.size()).is_between(4, 7)
			var inventario := Apertura.inventario_de_la_jornada(
				compradores, _casilleros(), _casilleros(), _azar(semilla)
			)
			for producto in Catalogo.todos():
				assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(
					8 - faltantes.get(producto.id, 0)
				)
				assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(8)
			cantidades[faltantes.size()] = true
			var ids := faltantes.keys()
			ids.sort()
			conjuntos[str(ids)] = true
			for id: Producto.Id in faltantes:
				assert_int(faltantes[id]).is_between(1, mini(8 - pedidos.get(id, 0), 8))
		assert_int(cantidades.size()).is_greater_equal(2)
		assert_int(conjuntos.size()).is_greater_equal(2)


func test_misma_semilla_reproduce_y_no_muta_las_entradas() -> void:  # AC-STK-034
	var pedidos: Dictionary[Producto.Id, int] = {Producto.Id.ACTRONCITO: 3}
	var casilleros := _casilleros()
	var antes := casilleros.duplicate()
	var uno := Apertura.faltantes_al_azar(pedidos, casilleros, _azar(17))
	assert_dict(Apertura.faltantes_al_azar(pedidos, casilleros, _azar(17))).is_equal(uno)
	assert_dict(casilleros).is_equal(antes)
	assert_dict(pedidos).is_equal({Producto.Id.ACTRONCITO: 3})


func test_cero_uno_y_tres_elegibles_y_los_maximos_de_pedido_y_fila() -> void:  # AC-STK-034
	assert_dict(Apertura.faltantes_al_azar({}, {}, _azar(0))).is_empty()
	var casilleros: Dictionary[Producto.Id, int] = {
		Producto.Id.ACTRONCITO: 6,
		Producto.Id.CORACOLA: 4,
		Producto.Id.MAROLINI: 8,
		Producto.Id.PRONGLES: 8,
		Producto.Id.LAYSNTT: 0,
	}
	var pedidos: Dictionary[Producto.Id, int] = {
		Producto.Id.ACTRONCITO: 3,
		Producto.Id.CORACOLA: 1,
		Producto.Id.PRONGLES: 8,
	}
	for semilla in 200:
		var faltantes := Apertura.faltantes_al_azar(pedidos, casilleros, _azar(semilla))
		(
			assert_array(faltantes.keys())
			. contains_exactly_in_any_order(
				[
					Producto.Id.ACTRONCITO,
					Producto.Id.CORACOLA,
					Producto.Id.MAROLINI,
				]
			)
		)
		assert_int(faltantes[Producto.Id.ACTRONCITO]).is_between(1, 5)
		assert_int(faltantes[Producto.Id.CORACOLA]).is_between(1, 4)
		assert_int(faltantes[Producto.Id.MAROLINI]).is_between(1, 8)
	var unico: Dictionary[Producto.Id, int] = {Producto.Id.ACTRONCITO: 1}
	assert_dict(Apertura.faltantes_al_azar({}, unico, _azar(0))).is_equal(unico)


## Las semillas se midieron una vez sobre los intervalos inclusivos del motor.
## Los tests no buscan una semilla: afirman el extremo de la fuente y el del sorteo.
func test_extremos_de_cantidad_con_fuentes_controladas() -> void:  # AC-STK-034
	for caso: Array in [[4, 3], [7, 0]]:
		var control := _azar(caso[1])
		assert_int(control.randi_range(4, 7)).is_equal(caso[0])
		var faltantes := Apertura.faltantes_al_azar({}, _casilleros(1), _azar(caso[1]))
		assert_int(faltantes.size()).is_equal(caso[0])
		for cantidad: int in faltantes.values():
			assert_int(cantidad).is_equal(1)
		var tres: Dictionary[Producto.Id, int] = {
			Producto.Id.ACTRONCITO: 1,
			Producto.Id.CORACOLA: 1,
			Producto.Id.MAROLINI: 1,
		}
		assert_dict(Apertura.faltantes_al_azar({}, tres, _azar(caso[1]))).is_equal(tres)


func test_extremos_de_unidades_con_fuentes_controladas() -> void:  # AC-STK-034
	# Fila, pedido, máximo, semilla para 1, semilla para el máximo.
	for caso: Array in [[6, 3, 5, 19, 4], [4, 1, 4, 1, 0], [6, 5, 3, 0, 6], [8, 0, 8, 1, 29]]:
		var id := Producto.Id.ACTRONCITO
		var casilleros: Dictionary[Producto.Id, int] = {id: caso[0]}
		var pedidos: Dictionary[Producto.Id, int] = {id: caso[1]}
		for extremo: Array in [[1, caso[3]], [caso[2], caso[4]]]:
			var control := _azar(extremo[1])
			control.randi_range(4, 7)
			control.randi_range(0, 0)
			assert_int(control.randi_range(1, caso[2])).is_equal(extremo[0])
			(
				assert_dict(Apertura.faltantes_al_azar(pedidos, casilleros, _azar(extremo[1])))
				. is_equal({id: extremo[0]})
			)
