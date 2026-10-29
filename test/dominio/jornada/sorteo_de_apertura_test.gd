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
	for jornada in range(2, 9):
		var compradores := Compradores.de_la_jornada(jornada)
		var pedidos := Apertura.pedidos_de(compradores)
		var casilleros: Dictionary[Producto.Id, int] = {}
		for producto in Catalogo.de_la_jornada(jornada):
			casilleros[producto.id] = 8
		# La jornada de los vencidos abre la góndola de Cindolor completa.
		if Apertura.pide(jornada, Tarea.Tipo.DESECHAR_VENCIDOS):
			casilleros[Apertura.PRODUCTO_CON_VENCIDOS] = 0
		var cantidades: Dictionary[int, bool] = {}
		var conjuntos: Dictionary[String, bool] = {}
		for semilla in 200:
			var faltantes := Apertura.faltantes_al_azar(pedidos, casilleros, _azar(semilla))
			assert_int(faltantes.size()).is_between(
				ReglasDelEstante.TIPOS_QUE_FALTAN.x, ReglasDelEstante.TIPOS_QUE_FALTAN.y
			)
			var inventario := Apertura.inventario_de_la_jornada(
				jornada, compradores, _casilleros(), _casilleros(), _azar(semilla)
			)
			for producto in Catalogo.de_la_jornada(jornada):
				assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(
					8 - faltantes.get(producto.id, 0)
				)
				assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(8)
			cantidades[faltantes.size()] = true
			var ids := faltantes.keys()
			ids.sort()
			conjuntos[str(ids)] = true
			for id: Producto.Id in faltantes:
				assert_int(faltantes[id]).is_between(
					ReglasDelEstante.MENOS_QUE_FALTA, mini(8 - pedidos.get(id, 0), 8)
				)
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
	var minimo := ReglasDelEstante.MENOS_QUE_FALTA
	assert_dict(Apertura.faltantes_al_azar({}, {}, _azar(0))).is_empty()
	var casilleros: Dictionary[Producto.Id, int] = {
		Producto.Id.ACTRONCITO: 6,
		Producto.Id.PURA_COLA: 4,
		Producto.Id.MAROLINI: 8,
		Producto.Id.PROGRES: 8,
		Producto.Id.LAYSNNT: 0,
		Producto.Id.MALBARDO: 8,
	}
	var pedidos: Dictionary[Producto.Id, int] = {
		Producto.Id.ACTRONCITO: 3,
		Producto.Id.PURA_COLA: 1,
		Producto.Id.PROGRES: 8,
		Producto.Id.MALBARDO: ReglasDelEstante.UNIDADES_POR_CAJA - (minimo - 1),
	}
	for semilla in 200:
		var faltantes := Apertura.faltantes_al_azar(pedidos, casilleros, _azar(semilla))
		(
			assert_array(faltantes.keys())
			. contains_exactly_in_any_order(
				[
					Producto.Id.ACTRONCITO,
					Producto.Id.PURA_COLA,
					Producto.Id.MAROLINI,
				]
			)
		)
		assert_int(faltantes[Producto.Id.ACTRONCITO]).is_between(minimo, 5)
		assert_int(faltantes[Producto.Id.PURA_COLA]).is_between(minimo, 4)
		assert_int(faltantes[Producto.Id.MAROLINI]).is_between(minimo, 8)
	var unico: Dictionary[Producto.Id, int] = {Producto.Id.ACTRONCITO: minimo}
	assert_dict(Apertura.faltantes_al_azar({}, unico, _azar(0))).is_equal(unico)
	var corto: Dictionary[Producto.Id, int] = {Producto.Id.ACTRONCITO: minimo - 1}
	assert_dict(Apertura.faltantes_al_azar({}, corto, _azar(0))).is_empty()


## Las semillas se midieron una vez sobre los intervalos inclusivos del motor.
## Los tests no buscan una semilla: afirman el extremo de la fuente y el del sorteo.
func test_extremos_de_cantidad_con_fuentes_controladas() -> void:  # AC-STK-034
	var tipos := ReglasDelEstante.TIPOS_QUE_FALTAN
	var minimo := ReglasDelEstante.MENOS_QUE_FALTA
	for caso: Array in [[tipos.x, 3], [tipos.y, 5]]:
		var control := _azar(caso[1])
		assert_int(control.randi_range(tipos.x, tipos.y)).is_equal(caso[0])
		var faltantes := Apertura.faltantes_al_azar({}, _casilleros(minimo), _azar(caso[1]))
		assert_int(faltantes.size()).is_equal(caso[0])
		for cantidad: int in faltantes.values():
			assert_int(cantidad).is_equal(minimo)
		var tres: Dictionary[Producto.Id, int] = {
			Producto.Id.ACTRONCITO: minimo,
			Producto.Id.PURA_COLA: minimo,
			Producto.Id.MAROLINI: minimo,
		}
		assert_dict(Apertura.faltantes_al_azar({}, tres, _azar(caso[1]))).is_equal(tres)


func test_extremos_de_unidades_con_fuentes_controladas() -> void:  # AC-STK-034
	var tipos := ReglasDelEstante.TIPOS_QUE_FALTAN
	var minimo := ReglasDelEstante.MENOS_QUE_FALTA
	var caja := ReglasDelEstante.UNIDADES_POR_CAJA
	# Fila, pedido, máximo, semilla para el mínimo, semilla para el máximo.
	for caso: Array in [
		[6, 3, 5, 0, 6], [4, 1, 4, 1, 0], [6, caja - minimo, minimo, 0, 0], [8, 0, 8, 1, 9]
	]:
		var id := Producto.Id.ACTRONCITO
		var casilleros: Dictionary[Producto.Id, int] = {id: caso[0]}
		var pedidos: Dictionary[Producto.Id, int] = {id: caso[1]}
		for extremo: Array in [[minimo, caso[3]], [caso[2], caso[4]]]:
			var control := _azar(extremo[1])
			control.randi_range(tipos.x, tipos.y)
			control.randi_range(0, 0)
			assert_int(control.randi_range(minimo, caso[2])).is_equal(extremo[0])
			(
				assert_dict(Apertura.faltantes_al_azar(pedidos, casilleros, _azar(extremo[1])))
				. is_equal({id: extremo[0]})
			)


## Las tandas de un producto: los casilleros de la fila de adelante de cada una, numerados uno
## detrás del otro, con la reponible primero.
func _tandas(tamanos: Array[int]) -> Array:
	var tandas: Array = []
	var siguiente := 0
	for tamano in tamanos:
		var casilleros := PackedInt32Array()
		for _lugar in tamano:
			casilleros.append(siguiente)
			siguiente += 1
		tandas.append(casilleros)
	return tandas


func _tandas_de_todos(tamanos: Array[int]) -> Dictionary[Producto.Id, Array]:
	var tandas: Dictionary[Producto.Id, Array] = {}
	for producto in Catalogo.todos():
		tandas[producto.id] = _tandas(tamanos)
	return tandas


func _vacios(
	jornada: int,
	compradores: Array[Comprador],
	tandas: Dictionary[Producto.Id, Array],
	semilla: int,
	posiciones: Dictionary[Producto.Id, Array] = {}
) -> Dictionary[Producto.Id, Array]:
	return Apertura.vacios_de_la_jornada(jornada, compradores, tandas, _azar(semilla), posiciones)


## Un estante por altura, con los casilleros de todos en las mismas columnas.
func _en_estantes(alturas: Array[float], casilleros: int) -> Array:
	var estantes: Array = []
	for altura in alturas:
		var lugares := PackedVector3Array()
		for columna in casilleros:
			lugares.append(Vector3(columna * 0.3, altura, 0.0))
		estantes.append(lugares)
	return estantes


func _tanda_de(casillero: int, tamanos: Array[int]) -> int:
	var hasta := 0
	for indice in tamanos.size():
		hasta += tamanos[indice]
		if casillero < hasta:
			return indice
	return -1


func test_los_vacios_caen_en_cualquier_tanda_del_producto_sin_repetirse() -> void:  # AC-STK-033
	var tamanos: Array[int] = [3, 3, 3, 3]
	var tandas := _tandas_de_todos(tamanos)
	for jornada in range(2, 9):
		var compradores := Compradores.de_la_jornada(jornada)
		var pedidos := Apertura.pedidos_de(compradores)
		var tandas_con_vacios: Dictionary[int, bool] = {}
		for semilla in 200:
			var vacios := _vacios(jornada, compradores, tandas, semilla)
			for id: Producto.Id in vacios:
				var casilleros: Array = vacios[id]
				assert_int(casilleros.size()).is_between(
					ReglasDelEstante.MENOS_QUE_FALTA,
					mini(ReglasDelEstante.UNIDADES_POR_CAJA - pedidos.get(id, 0), 8)
				)
				var vistos: Dictionary[int, bool] = {}
				for casillero: int in casilleros:
					assert_int(casillero).is_between(0, 11)
					assert_bool(vistos.has(casillero)).is_false()
					vistos[casillero] = true
					tandas_con_vacios[_tanda_de(casillero, tamanos)] = true
		assert_array(tandas_con_vacios.keys()).contains_exactly_in_any_order([0, 1, 2, 3])


func test_con_las_dos_tandas_del_local_los_vacios_caen_en_las_dos() -> void:  # AC-STK-033
	var tamanos: Array[int] = [4, 4]
	var tandas := _tandas_de_todos(tamanos)
	for jornada in range(4, 9):
		var tandas_con_vacios: Dictionary[int, bool] = {}
		for semilla in 200:
			var vacios := _vacios(jornada, Compradores.de_la_jornada(jornada), tandas, semilla)
			for id: Producto.Id in vacios:
				for casillero: int in vacios[id]:
					tandas_con_vacios[_tanda_de(casillero, tamanos)] = true
		assert_array(tandas_con_vacios.keys()).contains_exactly_in_any_order([0, 1])


func test_los_vacios_de_cada_tanda_son_casilleros_seguidos() -> void:  # AC-STK-033
	for forma: Array in [[3, 3, 3, 3], [4, 4], [2, 5, 3]]:
		var tamanos: Array[int] = []
		tamanos.assign(forma)
		var tandas := _tandas_de_todos(tamanos)
		for jornada in range(2, 9):
			var compradores := Compradores.de_la_jornada(jornada)
			for semilla in 200:
				var vacios := _vacios(jornada, compradores, tandas, semilla)
				for id: Producto.Id in vacios:
					for tanda: PackedInt32Array in tandas[id]:
						var lugares: Array[int] = []
						for lugar in tanda.size():
							if vacios[id].has(tanda[lugar]):
								lugares.append(lugar)
						if not lugares.is_empty():
							assert_int(lugares.back() - lugares.front() + 1).is_equal(
								lugares.size()
							)


func test_si_el_faltante_entra_entero_en_alguna_tanda_cae_entero_en_una() -> void:  # AC-STK-033
	var producto := Producto.Id.ACTRONCITO
	var tamanos: Array[int] = [5, 4]
	var tandas: Dictionary[Producto.Id, Array] = {producto: _tandas(tamanos)}
	var tandas_usadas: Dictionary[int, bool] = {}
	var cuatro_vistos := 0
	for semilla in 200:
		var vacios := _vacios(8, [], tandas, semilla)
		var casilleros: Array = vacios[producto]
		var en_tandas: Dictionary[int, bool] = {}
		for casillero: int in casilleros:
			en_tandas[_tanda_de(casillero, tamanos)] = true
		tandas_usadas.merge(en_tandas)
		if casilleros.size() <= 4:
			assert_int(en_tandas.size()).is_equal(1)
		if casilleros.size() == 4:
			cuatro_vistos += 1
			assert_array(en_tandas.keys()).contains_exactly([0])
		if casilleros.size() > 4:
			assert_int(en_tandas.size()).is_equal(2)
	assert_int(cuatro_vistos).is_greater(0)
	assert_array(tandas_usadas.keys()).contains_exactly_in_any_order([0, 1])


func test_el_bloque_que_sigue_va_en_el_estante_contiguo_y_alineado() -> void:  # AC-STK-033
	var producto := Producto.Id.ACTRONCITO
	var tamanos: Array[int] = [4, 4, 4]
	var alturas: Array[float] = [0.5, 1.0, 2.5]
	var tandas: Dictionary[Producto.Id, Array] = {producto: _tandas(tamanos)}
	var posiciones: Dictionary[Producto.Id, Array] = {producto: _en_estantes(alturas, 4)}
	var pares: Dictionary[String, bool] = {}
	for semilla in 200:
		var casilleros: Array = _vacios(8, [], tandas, semilla, posiciones)[producto]
		var columnas_por_tanda: Dictionary[int, Array] = {}
		for casillero: int in casilleros:
			var tanda := _tanda_de(casillero, tamanos)
			if not columnas_por_tanda.has(tanda):
				columnas_por_tanda[tanda] = []
			columnas_por_tanda[tanda].append(casillero % 4)
		if columnas_por_tanda.size() == 3:
			assert_int(casilleros.size()).is_greater(6)
		if columnas_por_tanda.size() != 2:
			continue
		pares[str(columnas_por_tanda.keys())] = true
		var bloques: Array = columnas_por_tanda.values()
		bloques.sort_custom(func(a: Array, b: Array) -> bool: return a.size() < b.size())
		for columna: int in bloques[0]:
			assert_bool(bloques[1].has(columna)).is_true()
	assert_array(pares.keys()).contains_exactly_in_any_order(["[0, 1]", "[1, 2]"])


func test_la_misma_semilla_deja_vacios_los_mismos_casilleros() -> void:  # AC-STK-034
	var tandas := _tandas_de_todos([4, 4])
	var compradores := Compradores.de_la_jornada(3)
	for semilla in 20:
		var uno := _vacios(3, compradores, tandas, semilla)
		assert_dict(_vacios(3, compradores, tandas, semilla)).is_equal(uno)


func test_la_primera_jornada_no_vacia_ningun_casillero() -> void:  # AC-STK-094
	var tandas := _tandas_de_todos([4, 4])
	for semilla in 20:
		var vacios := _vacios(ReglasDeLaPartida.PRIMERA_JORNADA, [], tandas, semilla)
		assert_dict(vacios).is_empty()


func test_una_tanda_no_abre_vacia_entera() -> void:  # AC-STK-033
	var producto := Producto.Id.FLIM_POF
	var tandas: Dictionary[Producto.Id, Array] = {producto: _tandas([3, 3])}
	var cantidades: Dictionary[int, bool] = {}
	for semilla in 200:
		var vacios := _vacios(8, [], tandas, semilla)
		var casilleros: Array = vacios[producto]
		cantidades[casilleros.size()] = true
		for tanda: PackedInt32Array in tandas[producto]:
			var vaciados := 0
			for casillero in tanda:
				vaciados += 1 if casilleros.has(casillero) else 0
			assert_int(vaciados).is_less(tanda.size())
	assert_int(cantidades.keys().max()).is_equal(4)


func test_sin_casilleros_en_ninguna_tanda_el_producto_no_falta() -> void:  # AC-STK-030
	var tandas: Dictionary[Producto.Id, Array] = {Producto.Id.ACTRONCITO: _tandas([0, 0])}
	for semilla in 200:
		assert_dict(_vacios(8, [], tandas, semilla)).is_empty()


func test_con_casilleros_solo_en_una_fija_el_producto_falta() -> void:  # AC-STK-030
	var tandas: Dictionary[Producto.Id, Array] = {Producto.Id.ACTRONCITO: _tandas([0, 4])}
	for semilla in 200:
		var vacios := _vacios(8, [], tandas, semilla)
		assert_array(vacios.keys()).contains_exactly([Producto.Id.ACTRONCITO])
		for casillero: int in vacios[Producto.Id.ACTRONCITO]:
			assert_int(casillero).is_between(0, 3)
