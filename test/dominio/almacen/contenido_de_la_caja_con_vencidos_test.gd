## La caja no recibe de vuelta una unidad vencida: saldría después como sana.
extends GdUnitTestSuite

const CASILLEROS := ReglasDelEstante.UNIDADES_POR_CAJA


func _cindolor() -> Producto:
	return Producto.new(Producto.Id.CINDOLOR, "de prueba", 100)


func _estante(vencidos: Array) -> Estante:
	var producto := _cindolor()
	var productos: Array[Producto] = [producto]
	var inventario := Inventario.new(productos, {producto.id: CASILLEROS})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, ReglasDelEstante.UNIDADES_POR_CAJA)
	inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, CASILLEROS)
	var marcas: Dictionary[Producto.Id, Array] = {producto.id: vencidos}
	return Estante.new(inventario, productos, {}, {}, marcas)


func test_la_caja_no_recibe_una_vencida_y_la_unidad_sigue_en_la_mano() -> void:  # AC-STK-120
	var estante := _estante([1])
	var caja := ContenidoDeLaCaja.new(_cindolor(), estante)
	# Una unidad fuera de la caja le deja lugar: lo que se prueba es la marca y no la caja llena.
	estante.retirar(_cindolor())
	var vencida := estante.agarrar(_cindolor(), 1)
	var antes := caja.unidades()
	assert_bool(caja.meter(vencida)).is_false()
	assert_int(caja.unidades()).is_equal(antes)
	assert_bool(estante.reservadas(_cindolor()) > 0).is_true()
	assert_int(caja.gesto_posible(vencida, true)).is_equal(ContenidoDeLaCaja.Gesto.NADA)


func test_la_caja_recibe_una_sana() -> void:  # AC-STK-120
	var estante := _estante([1])
	var caja := ContenidoDeLaCaja.new(_cindolor(), estante)
	estante.retirar(_cindolor())
	var sana := estante.agarrar(_cindolor(), 0)
	var antes := caja.unidades()
	assert_bool(caja.meter(sana)).is_true()
	assert_int(caja.unidades()).is_equal(antes + 1)
	assert_int(caja.gesto_posible(sana, true)).is_equal(ContenidoDeLaCaja.Gesto.METER)
