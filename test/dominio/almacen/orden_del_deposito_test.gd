extends GdUnitTestSuite


func test_la_tabla_de_apoyos_y_la_mano_resuelven_el_orden() -> void:  # AC-STK-078
	# ORDENAR_LAS_CAJAS depende de cadenas completas, no de contar cajas elevadas.
	for fila: Array in [
		[OrdenDelDeposito.Apoyo.ESTANTERIA, false, true],
		[OrdenDelDeposito.Apoyo.OTRO, false, false],
		[OrdenDelDeposito.Apoyo.OTRO, true, true]
	]:
		var abajo := OrdenDelDeposito.Estado.new(Producto.Id.ACTRONCITO, fila[1], fila[0])
		var arriba := OrdenDelDeposito.Estado.new(
			Producto.Id.MALBARDO, false, OrdenDelDeposito.Apoyo.CAJA, Producto.Id.ACTRONCITO
		)
		var estados: Array[OrdenDelDeposito.Estado] = [arriba, abajo]
		assert_bool(OrdenDelDeposito.ordenadas(estados)).is_equal(fila[2])
		assert_bool(OrdenDelDeposito.ordenadas([abajo])).is_equal(fila[2])


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
