extends GdUnitTestSuite


func _caja(
	id: Producto.Id,
	donde: OrdenDelDeposito.Apoyo,
	mano: bool = false,
	debajo: Producto.Id = Producto.Id.ACTRONCITO
) -> OrdenDelDeposito.Estado:
	return OrdenDelDeposito.Estado.new(id, mano, donde, debajo)


func _en_estanteria(id: Producto.Id) -> OrdenDelDeposito.Estado:
	return _caja(id, OrdenDelDeposito.Apoyo.ESTANTERIA)


func test_la_tabla_de_apoyos_resuelve_el_orden() -> void:  # AC-STK-078
	# ORDENAR_LAS_CAJAS depende de cadenas completas, no de contar cajas elevadas.
	for fila: Array in [
		[OrdenDelDeposito.Apoyo.ESTANTERIA, true],
		[OrdenDelDeposito.Apoyo.OTRO, false],
	]:
		var abajo := _caja(Producto.Id.ACTRONCITO, fila[0])
		var arriba := _caja(
			Producto.Id.MALBARDO, OrdenDelDeposito.Apoyo.CAJA, false, Producto.Id.ACTRONCITO
		)
		var estados: Array[OrdenDelDeposito.Estado] = [arriba, abajo]
		assert_bool(OrdenDelDeposito.ordenadas(estados)).is_equal(fila[1])
		assert_bool(OrdenDelDeposito.ordenadas([abajo])).is_equal(fila[1])


func test_una_caja_en_la_mano_es_la_unica_excepcion() -> void:  # AC-STK-078
	var sostenida := _caja(Producto.Id.ACTRONCITO, OrdenDelDeposito.Apoyo.OTRO, true)
	var estantes := _en_estanteria(Producto.Id.MALBARDO)
	assert_bool(OrdenDelDeposito.ordenadas([sostenida])).is_true()
	assert_bool(OrdenDelDeposito.ordenadas([sostenida, estantes])).is_true()
	# La mano cuenta aunque su caja ya estuviera apoyada en una estantería.
	sostenida.apoyo = OrdenDelDeposito.Apoyo.ESTANTERIA
	assert_bool(OrdenDelDeposito.ordenadas([sostenida, estantes])).is_true()
	var en_el_piso := _caja(Producto.Id.DUREXTRA, OrdenDelDeposito.Apoyo.OTRO)
	assert_bool(OrdenDelDeposito.ordenadas([sostenida, estantes, en_el_piso])).is_false()
	var encima := _caja(
		Producto.Id.DUREXTRA, OrdenDelDeposito.Apoyo.CAJA, false, Producto.Id.ACTRONCITO
	)
	assert_bool(OrdenDelDeposito.ordenadas([sostenida, estantes, encima])).is_false()
	assert_bool(OrdenDelDeposito.ordenadas([encima, sostenida])).is_false()


func test_una_caja_en_el_local_es_la_unica_excepcion() -> void:  # AC-STK-132
	var en_el_local := _caja(Producto.Id.ACTRONCITO, OrdenDelDeposito.Apoyo.LOCAL)
	var estantes := _en_estanteria(Producto.Id.MALBARDO)
	assert_bool(OrdenDelDeposito.ordenadas([en_el_local, estantes])).is_true()
	var otra_en_el_local := _caja(Producto.Id.DUREXTRA, OrdenDelDeposito.Apoyo.LOCAL)
	assert_bool(OrdenDelDeposito.ordenadas([en_el_local, otra_en_el_local, estantes])).is_false()
	var sostenida := _caja(Producto.Id.DUREXTRA, OrdenDelDeposito.Apoyo.OTRO, true)
	assert_bool(OrdenDelDeposito.ordenadas([en_el_local, sostenida, estantes])).is_false()
	var encima := _caja(
		Producto.Id.DUREXTRA, OrdenDelDeposito.Apoyo.CAJA, false, Producto.Id.ACTRONCITO
	)
	assert_bool(OrdenDelDeposito.ordenadas([en_el_local, encima, estantes])).is_false()
	assert_bool(OrdenDelDeposito.ordenadas([encima, en_el_local])).is_false()


func test_el_piso_y_el_pallet_del_piso_no_son_la_excepcion() -> void:  # AC-STK-132
	# El baño, el cuartito y afuera llegan como cualquier apoyo que no es estantería ni local.
	var fuera := _caja(Producto.Id.ACTRONCITO, OrdenDelDeposito.Apoyo.OTRO)
	(
		assert_bool(OrdenDelDeposito.ordenadas([fuera, _en_estanteria(Producto.Id.MALBARDO)]))
		. is_false()
	)


func test_ciclos_y_apoyos_ausentes_no_ordenan() -> void:  # AC-STK-078
	var uno := OrdenDelDeposito.Estado.new(
		Producto.Id.ACTRONCITO, false, OrdenDelDeposito.Apoyo.CAJA, Producto.Id.MALBARDO
	)
	var dos := OrdenDelDeposito.Estado.new(
		Producto.Id.MALBARDO, false, OrdenDelDeposito.Apoyo.CAJA, Producto.Id.ACTRONCITO
	)
	assert_bool(OrdenDelDeposito.ordenadas([uno, dos])).is_false()
	assert_bool(OrdenDelDeposito.ordenadas([uno])).is_false()
	uno.sobre = uno.producto
	assert_bool(OrdenDelDeposito.ordenadas([uno])).is_false()
	assert_bool(OrdenDelDeposito.ordenadas([])).is_true()


func test_una_cadena_larga_termina_en_estanteria_o_en_el_piso() -> void:  # AC-STK-078
	var estados: Array[OrdenDelDeposito.Estado] = []
	for producto in Catalogo.todos():
		estados.append(OrdenDelDeposito.Estado.new(producto.id))
	for indice in range(1, estados.size()):
		estados[indice].apoyo = OrdenDelDeposito.Apoyo.CAJA
		estados[indice].sobre = estados[indice - 1].producto
	estados[0].apoyo = OrdenDelDeposito.Apoyo.ESTANTERIA
	assert_bool(OrdenDelDeposito.ordenadas(estados)).is_true()
	estados[0].apoyo = OrdenDelDeposito.Apoyo.OTRO
	assert_bool(OrdenDelDeposito.ordenadas(estados)).is_false()
