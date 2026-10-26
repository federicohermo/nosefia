## La apertura de los productos de una sola fila, contra las tandas y los lugares que mide el puesto
## sobre las disposiciones de las jornadas: ninguno abre un estante vacío entero, y el vacío que
## sobra cae en el estante de justo arriba.
##
## **Ningún caso escribe una altura**: salen de la disposición, y «justo arriba» se lee de ellas.
extends GdUnitTestSuite

const PUESTO := preload("res://src/escenas/puestos/reposicion_manual.gd")
const COMPLETA := "res://src/escenas/puestos/disposicion_de_la_gondola.tres"


func _puesto_de(jornada: int) -> Node3D:
	var puesto: Node3D = auto_free(PUESTO.new())
	puesto.set("disposicion", load(COMPLETA))
	puesto.call("seleccionar_disposicion", jornada)
	return puesto


func _azar(semilla: int) -> RandomNumberGenerator:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	return azar


func _altura_de(lugares: PackedVector3Array) -> float:
	var suma := 0.0
	for lugar in lugares:
		suma += lugar.y
	return suma / maxi(lugares.size(), 1)


func _vaciados_de(tanda: PackedInt32Array, vacios: Array) -> int:
	var vaciados := 0
	for casillero in tanda:
		vaciados += 1 if vacios.has(casillero) else 0
	return vaciados


## Los índices de las tandas con más de un casillero, de la de arriba de todo hacia abajo.
func _de_arriba_a_abajo(tandas: Array, lugares: Array) -> Array[int]:
	var estantes: Array[int] = []
	for indice in tandas.size():
		if tandas[indice].size() > 1:
			estantes.append(indice)
	estantes.sort_custom(
		func(a: int, b: int) -> bool: return _altura_de(lugares[a]) > _altura_de(lugares[b])
	)
	return estantes


func _sorteo(jornada: int, puesto: Node3D, semilla: int) -> Dictionary[Producto.Id, Array]:
	return Apertura.vacios_de_la_jornada(
		jornada,
		[],
		puesto.call("tandas"),
		puesto.call("productos_de_una_fila"),
		_azar(semilla),
		puesto.call("posiciones")
	)


## Los vacíos de un producto con una tanda de cada estante: seguidos, y la parcial arriba de las
## llenas, o abajo sólo si las llenas llegan al estante de arriba de todo.
func _comprobar_el_vacio_que_sobra(jornada: int, id: Producto.Id) -> void:
	var puesto := _puesto_de(jornada)
	var tandas: Array = puesto.call("tandas")[id]
	var lugares: Array = puesto.call("posiciones")[id]
	var partidos := 0
	for semilla in 200:
		var sorteo := _sorteo(jornada, puesto, semilla)
		if not sorteo.has(id):
			continue
		var estantes := _de_arriba_a_abajo(tandas, lugares)
		var con_vacios: Array[int] = []
		var parciales: Array[int] = []
		for lugar in estantes.size():
			var tanda: PackedInt32Array = tandas[estantes[lugar]]
			var vaciados := _vaciados_de(tanda, sorteo[id])
			if vaciados > 0:
				con_vacios.append(lugar)
			if vaciados > 0 and vaciados < tanda.size() - 1:
				parciales.append(lugar)
		if con_vacios.size() < 2:
			continue
		partidos += 1
		assert_int(con_vacios.back() - con_vacios.front() + 1).is_equal(con_vacios.size())
		assert_int(parciales.size()).is_less_equal(1)
		if not parciales.is_empty() and con_vacios.front() > 0:
			assert_int(parciales[0]).is_equal(con_vacios.front())
	assert_int(partidos).is_greater(0)


func test_el_vacio_que_sobra_de_poetico_cae_en_el_estante_de_justo_arriba() -> void:  # AC-STK-093
	for jornada: int in [
		ReglasDeLaPartida.PRIMERA_JORNADA + 1, ReglasDeLaPartida.PRIMERA_JORNADA + 2
	]:
		_comprobar_el_vacio_que_sobra(jornada, Producto.Id.POETICO)


func test_el_vacio_que_sobra_de_flin_puf_cae_en_el_estante_de_justo_arriba() -> void:  # AC-STK-093
	_comprobar_el_vacio_que_sobra(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA, Producto.Id.FLIM_POF)


func test_ningun_producto_de_una_fila_abre_un_estante_vacio_entero() -> void:  # AC-STK-093
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	for jornada in range(primera + 1, primera + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		var puesto := _puesto_de(jornada)
		var tandas: Dictionary[Producto.Id, Array] = puesto.call("tandas")
		var de_una_fila: Dictionary[Producto.Id, bool] = puesto.call("productos_de_una_fila")
		for semilla in 100:
			var vacios := Apertura.vacios_de_la_jornada(
				jornada,
				Compradores.de_la_jornada(jornada),
				tandas,
				de_una_fila,
				_azar(semilla),
				puesto.call("posiciones")
			)
			for id: Producto.Id in vacios:
				if not de_una_fila[id]:
					continue
				for tanda: PackedInt32Array in tandas[id]:
					assert_int(_vaciados_de(tanda, vacios[id])).is_less(tanda.size())


func test_un_producto_de_dos_filas_abre_un_estante_vacio_entero() -> void:  # AC-STK-033
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	var puesto := _puesto_de(jornada)
	var id := Producto.Id.ACTRONCITO
	assert_bool(puesto.call("productos_de_una_fila")[id]).is_false()
	var tandas: Array = puesto.call("tandas")[id]
	var abrio_vacio := false
	for semilla in 200:
		var sorteo := _sorteo(jornada, puesto, semilla)
		for tanda: PackedInt32Array in tandas:
			abrio_vacio = (
				abrio_vacio or (sorteo.has(id) and _vaciados_de(tanda, sorteo[id]) == tanda.size())
			)
	assert_bool(abrio_vacio).is_true()
