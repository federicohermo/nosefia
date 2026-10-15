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
		var pedidos := Apertura.pedidos_de(Compradores.de_la_jornada(jornada))
		var cantidades: Dictionary[int, bool] = {}
		var conjuntos: Dictionary[String, bool] = {}
		for semilla in 200:
			var faltantes := Apertura.faltantes_al_azar(pedidos, _casilleros(), _azar(semilla))
			assert_int(faltantes.size()).is_between(4, 7)
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
			. contains_exactly(
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
