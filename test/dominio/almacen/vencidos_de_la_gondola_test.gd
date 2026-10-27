## Las marcas de vencido por casillero: se anotan, se quitan una sola vez y no se comparten con
## quien las armó.
extends GdUnitTestSuite


func _cindolor() -> Producto:
	return Producto.new(Producto.Id.CINDOLOR, "de prueba", 100)


func test_arranca_con_los_casilleros_de_la_apertura_ordenados() -> void:  # AC-STK-118
	var de_apertura: Dictionary[Producto.Id, Array] = {Producto.Id.CINDOLOR: [4, 1, 6]}
	var vencidos := VencidosDeLaGondola.new(de_apertura)
	assert_array(vencidos.casilleros(_cindolor())).contains_exactly([1, 4, 6])
	assert_int(vencidos.cuantos()).is_equal(3)


func test_no_comparte_la_lista_con_quien_la_armo() -> void:  # AC-STK-119
	var marcados := [1]
	var de_apertura: Dictionary[Producto.Id, Array] = {Producto.Id.CINDOLOR: marcados}
	var vencidos := VencidosDeLaGondola.new(de_apertura)
	vencidos.marcar(_cindolor(), 2)
	assert_array(marcados).contains_exactly([1])


func test_desmarcar_quita_la_marca_una_sola_vez() -> void:  # AC-STK-119
	var de_apertura: Dictionary[Producto.Id, Array] = {Producto.Id.CINDOLOR: [1, 3]}
	var vencidos := VencidosDeLaGondola.new(de_apertura)
	assert_bool(vencidos.desmarcar(_cindolor(), 1)).is_true()
	assert_bool(vencidos.desmarcar(_cindolor(), 1)).is_false()
	assert_array(vencidos.casilleros(_cindolor())).contains_exactly([3])


func test_sin_marcas_no_hay_vencidos() -> void:  # AC-STK-118
	var vencidos := VencidosDeLaGondola.new()
	assert_int(vencidos.cuantos()).is_zero()
	assert_array(vencidos.casilleros(_cindolor())).is_empty()
	assert_array(vencidos.casilleros(null)).is_empty()
