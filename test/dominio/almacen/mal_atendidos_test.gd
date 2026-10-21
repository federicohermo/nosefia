## Cuántos clientes quedaron sin vender al cerrar: lo que la prueba cuenta uno por uno.
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


func test_mal_atendido_es_todo_cliente_que_no_se_vendio_haya_llegado_o_no() -> void:  # AC-EMP-078
	var tarea := TareaDeAtender.new(_compradores(3), _inventario())
	assert_int(tarea.mal_atendidos()).is_equal(3)
	tarea.atender()
	assert_int(tarea.atencion().cobrar()).is_equal(Atencion.Resultado.COBRADA)
	assert_int(tarea.mal_atendidos()).is_equal(2)
	tarea.atender()
	assert_bool(tarea.atencion().despachar_sin_vender()).is_true()
	assert_int(tarea.mal_atendidos()).is_equal(2)
	tarea.atender()
	tarea.atencion().cobrar()
	assert_int(tarea.mal_atendidos()).is_equal(1)


func test_sin_clientes_nadie_quedo_mal_atendido() -> void:  # AC-EMP-078
	assert_int(TareaDeAtender.new(_compradores(0), _inventario()).mal_atendidos()).is_zero()
