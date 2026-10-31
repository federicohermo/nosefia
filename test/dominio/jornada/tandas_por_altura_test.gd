## La apertura de un producto con sus tandas en estantes a distinta altura: en ninguno abre vacía
## entera la fila de adelante, y el vacío que no cabe en un estante cae en el de
## justo arriba.
extends GdUnitTestSuite

const PRODUCTO := Producto.Id.FLIM_POF


func _azar(semilla: int) -> RandomNumberGenerator:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	return azar


## Las tandas del producto: los casilleros de la fila de adelante de cada una, numerados uno
## detrás del otro.
func _tandas(tamanos: Array[int]) -> Array:
	var tandas: Array = []
	var siguiente := 0
	for tamano in tamanos:
		tandas.append(PackedInt32Array(range(siguiente, siguiente + tamano)))
		siguiente += tamano
	return tandas


## Un estante por tanda, a su altura, con los casilleros en columnas.
func _en_estantes(tamanos: Array[int], alturas: Array[float]) -> Array:
	var estantes: Array = []
	for indice in tamanos.size():
		var lugares := PackedVector3Array()
		for columna in tamanos[indice]:
			lugares.append(Vector3(columna * 0.3, alturas[indice], 0.0))
		estantes.append(lugares)
	return estantes


## Cuántos vacíos tiene cada estante, del de arriba de todo hacia abajo.
func _vacios_por_estante(tamanos: Array[int], alturas: Array[float], semilla: int) -> Array[int]:
	var tandas := _tandas(tamanos)
	var por_producto: Dictionary[Producto.Id, Array] = {PRODUCTO: tandas}
	var posiciones: Dictionary[Producto.Id, Array] = {PRODUCTO: _en_estantes(tamanos, alturas)}
	var sorteados := Apertura.vacios_de_la_jornada(8, [], por_producto, _azar(semilla), posiciones)
	var vacios: Array = sorteados[PRODUCTO]
	var de_arriba_a_abajo: Array[int] = []
	de_arriba_a_abajo.assign(range(tamanos.size()))
	de_arriba_a_abajo.sort_custom(func(a: int, b: int) -> bool: return alturas[a] > alturas[b])
	var por_estante: Array[int] = []
	for indice in de_arriba_a_abajo:
		var vaciados := 0
		for casillero: int in tandas[indice]:
			vaciados += 1 if vacios.has(casillero) else 0
		por_estante.append(vaciados)
	return por_estante


func _suma(cantidades: Array[int]) -> int:
	var total := 0
	for cantidad in cantidades:
		total += cantidad
	return total


func test_cuatro_faltantes_son_tres_en_un_estante_y_uno_en_el_de_arriba() -> void:  # AC-STK-093
	var tamanos: Array[int] = [4, 4, 4, 4]
	var alturas: Array[float] = [1.0, 0.0, 2.0, 3.0]
	var con_el_otro_arriba := 0
	var con_el_otro_abajo := 0
	for semilla in 200:
		var por_estante := _vacios_por_estante(tamanos, alturas, semilla)
		for vacios in por_estante:
			assert_int(vacios).is_less(tamanos[0])
		if _suma(por_estante) != 4:
			continue
		var de_tres := por_estante.find(3)
		var de_uno := por_estante.find(1)
		assert_int(de_tres).is_greater_equal(0)
		assert_int(de_uno).is_greater_equal(0)
		if de_tres == 0:
			con_el_otro_abajo += 1
			assert_int(de_uno).is_equal(1)
		else:
			con_el_otro_arriba += 1
			assert_int(de_uno).is_equal(de_tres - 1)
	assert_int(con_el_otro_arriba).is_greater(0)
	assert_int(con_el_otro_abajo).is_greater(0)


func test_un_faltante_mayor_deja_las_vacias_juntas_y_la_parcial_arriba() -> void:  # AC-STK-093
	var tamanos: Array[int] = [4, 4, 4, 4]
	var alturas: Array[float] = [1.0, 0.0, 2.0, 3.0]
	var partidos := 0
	for semilla in 200:
		var por_estante := _vacios_por_estante(tamanos, alturas, semilla)
		if _suma(por_estante) <= 3:
			continue
		partidos += 1
		var con_vacios: Array[int] = []
		for estante in por_estante.size():
			if por_estante[estante] > 0:
				con_vacios.append(estante)
		assert_int(con_vacios.back() - con_vacios.front() + 1).is_equal(con_vacios.size())
		var parciales := con_vacios.filter(
			func(estante: int) -> bool: return por_estante[estante] < 3
		)
		assert_int(parciales.size()).is_less_equal(1)
		if not parciales.is_empty() and con_vacios.front() > 0:
			assert_int(parciales[0]).is_equal(con_vacios.front())
	assert_int(partidos).is_greater(0)


func test_el_estante_de_una_unidad_no_recibe_vacios_y_pasan_al_siguiente() -> void:  # AC-STK-093
	var tamanos: Array[int] = [4, 1, 4]
	var alturas: Array[float] = [0.0, 1.0, 2.0]
	var partidos := 0
	for semilla in 200:
		var por_estante := _vacios_por_estante(tamanos, alturas, semilla)
		assert_int(por_estante[1]).is_zero()
		if _suma(por_estante) <= 3:
			continue
		partidos += 1
		assert_int(por_estante[0]).is_greater(0)
		assert_int(por_estante[2]).is_greater(0)
		assert_int(maxi(por_estante[0], por_estante[2])).is_equal(3)
	assert_int(partidos).is_greater(0)
