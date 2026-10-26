## La apertura de los productos de una sola fila, contra las tandas y las alturas que mide el puesto
## sobre las disposiciones de las jornadas: ninguno abre un estante vacío entero, y el vacío que
## sobra pasa al estante vecino.
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


func _de_abajo_hacia_arriba(alturas: PackedFloat32Array) -> Array[int]:
	var orden: Array[int] = []
	orden.assign(range(alturas.size()))
	orden.sort_custom(func(a: int, b: int) -> bool: return alturas[a] < alturas[b])
	return orden


func _vaciados_de(tanda: PackedInt32Array, vacios: Array) -> int:
	var vaciados := 0
	for casillero in tanda:
		vaciados += 1 if vacios.has(casillero) else 0
	return vaciados


func _vaciar_cada_estante(jornada: int, id: Producto.Id) -> void:
	var puesto := _puesto_de(jornada)
	var de_una_fila: Dictionary[Producto.Id, bool] = puesto.call("productos_de_una_fila")
	assert_bool(de_una_fila[id]).is_true()
	var tandas: Array = puesto.call("tandas")[id]
	var alturas: PackedFloat32Array = puesto.call("alturas_de_las_tandas")[id]
	var orden := _de_abajo_hacia_arriba(alturas)
	assert_int(orden.size()).is_greater(1)
	for lugar in orden.size():
		var casilleros: Array[int] = []
		for casillero in tandas[orden[lugar]]:
			casilleros.append(casillero)
		var vecina := orden[lugar + 1] if lugar + 1 < orden.size() else orden[lugar - 1]
		var vacios := Apertura.sin_tandas_vacias(casilleros, tandas, alturas, _azar(lugar))
		assert_int(vacios.size()).is_equal(casilleros.size())
		assert_int(_vaciados_de(tandas[orden[lugar]], vacios)).is_equal(casilleros.size() - 1)
		assert_int(_vaciados_de(tandas[vecina], vacios)).is_equal(1)


func test_cada_estante_de_poetico_que_se_vaciaria_pasa_el_que_sobra() -> void:  # AC-STK-093
	_vaciar_cada_estante(ReglasDeLaPartida.PRIMERA_JORNADA + 1, Producto.Id.POETICO)
	_vaciar_cada_estante(ReglasDeLaPartida.PRIMERA_JORNADA + 2, Producto.Id.POETICO)


func test_en_flin_puf_el_estante_de_arriba_pasa_el_que_sobra_al_de_abajo() -> void:  # AC-STK-093
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	var alturas: PackedFloat32Array = _puesto_de(jornada).call("alturas_de_las_tandas")[
		Producto.Id.FLIM_POF
	]
	assert_int(_de_abajo_hacia_arriba(alturas).back()).is_equal(0)
	_vaciar_cada_estante(jornada, Producto.Id.FLIM_POF)


func test_ningun_producto_de_una_fila_abre_un_estante_vacio_entero() -> void:  # AC-STK-093
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	for jornada in range(primera + 1, primera + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		var puesto := _puesto_de(jornada)
		var tandas: Dictionary[Producto.Id, Array] = puesto.call("tandas")
		var alturas: Dictionary[Producto.Id, PackedFloat32Array] = puesto.call(
			"alturas_de_las_tandas"
		)
		var de_una_fila: Dictionary[Producto.Id, bool] = puesto.call("productos_de_una_fila")
		var compradores := Compradores.de_la_jornada(jornada)
		for semilla in 100:
			var vacios := Apertura.vacios_de_la_jornada(
				jornada, compradores, tandas, de_una_fila, _azar(semilla), alturas
			)
			for id: Producto.Id in vacios:
				if not de_una_fila[id]:
					continue
				for tanda: PackedInt32Array in tandas[id]:
					assert_int(_vaciados_de(tanda, vacios[id])).is_less(tanda.size())


func test_un_producto_de_dos_filas_abre_un_estante_vacio_entero() -> void:  # AC-STK-093
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	var puesto := _puesto_de(jornada)
	var id := Producto.Id.ACTRONCITO
	var de_una_fila: Dictionary[Producto.Id, bool] = puesto.call("productos_de_una_fila")
	assert_bool(de_una_fila[id]).is_false()
	var tandas: Dictionary[Producto.Id, Array] = {id: puesto.call("tandas")[id]}
	var alturas: Dictionary[Producto.Id, PackedFloat32Array] = {
		id: puesto.call("alturas_de_las_tandas")[id]
	}
	var abrio_vacio := false
	for semilla in 200:
		var vacios := Apertura.vacios_de_la_jornada(
			jornada, [], tandas, de_una_fila, _azar(semilla), alturas
		)
		for tanda: PackedInt32Array in tandas[id]:
			abrio_vacio = abrio_vacio or _vaciados_de(tanda, vacios[id]) == tanda.size()
	assert_bool(abrio_vacio).is_true()
