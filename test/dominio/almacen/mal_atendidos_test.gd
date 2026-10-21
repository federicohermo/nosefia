extends GdUnitTestSuite


func _inventario() -> Inventario:
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var inventario := Inventario.new([producto])
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 9)
	return inventario


func _compradores(cuantos: int) -> Array[Comprador]:
	var lista: Array[Comprador] = []
	for indice in cuantos:
		var pedido := Venta.new()
		pedido.agregar(Catalogo.de(Producto.Id.ACTRONCITO), 1)
		lista.append(Comprador.new("Comprador %d" % indice, pedido, pedido.total()))
	return lista


func test_mal_atendido_es_el_que_llego_no_se_vendio_y_se_fue() -> void:  # AC-EMP-078
	var tarea := TareaDeAtender.new(_compradores(3), _inventario())
	assert_int(tarea.mal_atendidos()).is_zero()
	tarea.atender()
	assert_int(tarea.atencion().cobrar()).is_equal(Atencion.Resultado.COBRADA)
	assert_int(tarea.mal_atendidos()).is_zero()
	tarea.atender()
	assert_int(tarea.mal_atendidos()).is_zero()
	assert_bool(tarea.atencion().despachar_sin_vender()).is_true()
	assert_int(tarea.mal_atendidos()).is_equal(1)


func test_el_que_se_cansa_de_esperar_cuenta_y_el_que_no_llego_no() -> void:  # AC-EMP-078
	var compradores := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	var tarea := TareaDeAtender.new(compradores, Apertura.inventario_con_faltantes({}, {}))
	tarea.avanzar(compradores[0].horario.x)
	assert_int(tarea.mal_atendidos()).is_zero()
	tarea.avanzar(compradores[0].horario.y + 1.0)
	assert_int(tarea.mal_atendidos()).is_equal(1)
