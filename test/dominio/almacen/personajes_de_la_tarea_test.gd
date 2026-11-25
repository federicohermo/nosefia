extends GdUnitTestSuite


func _comprador(personaje: DialogosDeCompradores.Personaje) -> Comprador:
	var pedido := Venta.new()
	pedido.agregar(Catalogo.de(Producto.Id.ACTRONCITO), 1)
	var comprador := Comprador.new("Comprador", pedido, pedido.total())
	comprador.personaje = personaje
	return comprador


func test_personajes_devuelve_los_distintos_sin_ninguno() -> void:
	var compradores: Array[Comprador] = [
		_comprador(DialogosDeCompradores.Personaje.NINGUNO),
		_comprador(DialogosDeCompradores.Personaje.TIN),
		_comprador(DialogosDeCompradores.Personaje.TIA),
		_comprador(DialogosDeCompradores.Personaje.TIN),
	]
	var tarea := TareaDeAtender.new(compradores, Inventario.new([]))
	assert_array(tarea.personajes()).contains_exactly(
		[DialogosDeCompradores.Personaje.TIN, DialogosDeCompradores.Personaje.TIA]
	)


func test_personajes_vacio_sin_compradores_con_personaje() -> void:
	var compradores: Array[Comprador] = [_comprador(DialogosDeCompradores.Personaje.NINGUNO)]
	var tarea := TareaDeAtender.new(compradores, Inventario.new([]))
	assert_array(tarea.personajes()).is_empty()
