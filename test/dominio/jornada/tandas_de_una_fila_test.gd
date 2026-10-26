extends GdUnitTestSuite


func _azar(semilla: int) -> RandomNumberGenerator:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	return azar


## Las tandas de un producto: los casilleros de la fila de adelante de cada una, numerados uno
## detrás del otro.
func _tandas(tamanos: Array[int]) -> Array:
	var tandas: Array = []
	var siguiente := 0
	for tamano in tamanos:
		tandas.append(PackedInt32Array(range(siguiente, siguiente + tamano)))
		siguiente += tamano
	return tandas


func _vaciar(tanda: PackedInt32Array) -> Array[int]:
	var casilleros: Array[int] = []
	for casillero in tanda:
		casilleros.append(casillero)
	return casilleros


func _vaciados_de(tanda: PackedInt32Array, vacios: Array) -> int:
	var vaciados := 0
	for casillero in tanda:
		vaciados += 1 if vacios.has(casillero) else 0
	return vaciados


func test_la_que_se_vaciaria_entera_pasa_el_que_sobra_a_la_de_arriba() -> void:  # AC-STK-093
	# De abajo hacia arriba: la tanda 1, la 0, la 2 y la 3.
	var tandas := _tandas([4, 4, 4, 4])
	var alturas := PackedFloat32Array([1.0, 0.0, 2.0, 3.0])
	for semilla in 50:
		var vacios := Apertura.sin_tandas_vacias(
			_vaciar(tandas[0]), tandas, alturas, _azar(semilla)
		)
		assert_int(vacios.size()).is_equal(4)
		assert_int(_vaciados_de(tandas[0], vacios)).is_equal(3)
		assert_int(_vaciados_de(tandas[2], vacios)).is_equal(1)
		assert_int(_vaciados_de(tandas[1], vacios)).is_equal(0)
		assert_int(_vaciados_de(tandas[3], vacios)).is_equal(0)


func test_la_de_arriba_de_todo_pasa_el_que_sobra_a_la_de_justo_abajo() -> void:  # AC-STK-093
	var tandas := _tandas([4, 4, 4, 4])
	var alturas := PackedFloat32Array([1.0, 0.0, 2.0, 3.0])
	for semilla in 50:
		var vacios := Apertura.sin_tandas_vacias(
			_vaciar(tandas[3]), tandas, alturas, _azar(semilla)
		)
		assert_int(vacios.size()).is_equal(4)
		assert_int(_vaciados_de(tandas[3], vacios)).is_equal(3)
		assert_int(_vaciados_de(tandas[2], vacios)).is_equal(1)


func test_sin_estante_arriba_el_que_sobra_pasa_al_de_abajo() -> void:  # AC-STK-093
	var tandas := _tandas([3, 5])
	var alturas := PackedFloat32Array([1.0, 0.0])
	for semilla in 50:
		var vacios := Apertura.sin_tandas_vacias(
			_vaciar(tandas[0]), tandas, alturas, _azar(semilla)
		)
		assert_int(_vaciados_de(tandas[0], vacios)).is_equal(2)
		assert_int(_vaciados_de(tandas[1], vacios)).is_equal(1)


func test_el_vacio_que_pasa_al_vecino_queda_pegado_a_los_que_ya_tiene() -> void:  # AC-STK-093
	var tandas := _tandas([4, 6])
	var alturas := PackedFloat32Array([0.0, 1.0])
	for semilla in 50:
		var entrada := _vaciar(tandas[0])
		entrada.append(tandas[1][2])
		entrada.append(tandas[1][3])
		var vacios := Apertura.sin_tandas_vacias(entrada, tandas, alturas, _azar(semilla))
		var lugares: Array[int] = []
		for lugar in tandas[1].size():
			if vacios.has(tandas[1][lugar]):
				lugares.append(lugar)
		assert_int(lugares.size()).is_equal(3)
		assert_int(lugares.back() - lugares.front()).is_equal(2)


func test_si_la_vecina_ya_abre_vacia_entera_el_que_sobra_sigue_al_siguiente() -> void:  # AC-STK-093
	var tandas := _tandas([4, 4, 4, 4])
	var alturas := PackedFloat32Array([0.0, 1.0, 2.0, 3.0])
	var entrada := _vaciar(tandas[0])
	for casillero in tandas[1]:
		entrada.append(casillero)
	for semilla in 50:
		var vacios := Apertura.sin_tandas_vacias(entrada, tandas, alturas, _azar(semilla))
		assert_int(vacios.size()).is_equal(8)
		assert_int(_vaciados_de(tandas[0], vacios)).is_equal(3)
		assert_int(_vaciados_de(tandas[1], vacios)).is_equal(3)
		assert_int(_vaciados_de(tandas[2], vacios)).is_equal(2)
		assert_int(_vaciados_de(tandas[3], vacios)).is_equal(0)


func test_una_tanda_que_conserva_unidades_no_mueve_ningun_vacio() -> void:  # AC-STK-093
	var tandas := _tandas([4, 4])
	var alturas := PackedFloat32Array([0.0, 1.0])
	var entrada: Array[int] = [0, 1, 2, 4]
	var vacios := Apertura.sin_tandas_vacias(entrada, tandas, alturas, _azar(0))
	assert_array(vacios).contains_exactly_in_any_order(entrada)


func test_un_producto_de_una_fila_conserva_una_unidad_en_cada_tanda() -> void:  # AC-STK-093
	var producto := Producto.Id.FLIM_POF
	var tandas: Dictionary[Producto.Id, Array] = {producto: _tandas([3, 3, 3])}
	var alturas: Dictionary[Producto.Id, PackedFloat32Array] = {
		producto: PackedFloat32Array([1.0, 0.0, 2.0])
	}
	var de_una_fila: Dictionary[Producto.Id, bool] = {producto: true}
	var cantidades: Dictionary[int, bool] = {}
	for semilla in 200:
		var vacios := Apertura.vacios_de_la_jornada(
			8, [], tandas, de_una_fila, _azar(semilla), alturas
		)
		var casilleros: Array = vacios[producto]
		cantidades[casilleros.size()] = true
		for tanda: PackedInt32Array in tandas[producto]:
			assert_int(_vaciados_de(tanda, casilleros)).is_less(tanda.size())
	assert_int(cantidades.keys().max()).is_equal(6)
