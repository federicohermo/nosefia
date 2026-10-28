## Los casilleros con una unidad vencida: la marca viaja con la unidad, tirarla no llena su
## casillero y reponer no se cumple mientras quede una en la góndola.
##
## Ni un `Node3D`: igual que el resto del estante, se ejerce sin levantar una escena.
extends GdUnitTestSuite

const CASILLEROS := ReglasDelEstante.UNIDADES_POR_CAJA


func _cindolor() -> Producto:
	return Producto.new(Producto.Id.CINDOLOR, "de prueba", 100)


## La góndola completa y la caja llena, con esos casilleros marcados como vencidos.
func _estante(vencidos: Array) -> Estante:
	var producto := _cindolor()
	var productos: Array[Producto] = [producto]
	var inventario := Inventario.new(productos, {producto.id: CASILLEROS})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, ReglasDelEstante.UNIDADES_POR_CAJA)
	inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, CASILLEROS)
	var marcas: Dictionary[Producto.Id, Array] = {producto.id: vencidos}
	return Estante.new(inventario, productos, {}, {}, marcas)


func _reponer(estante: Estante, cuantas: int) -> void:
	for _vuelta in cuantas:
		var sana := estante.retirar(_cindolor())
		assert_int(estante.colocar_unidad(sana)).is_equal(Estante.Rechazo.NINGUNO)


func test_agarrar_un_vencido_da_una_vencida_y_vacia_su_casillero() -> void:  # AC-STK-119
	var estante := _estante([1, 3])
	var unidad := estante.agarrar(_cindolor(), 1)
	assert_bool(unidad.vencido).is_true()
	assert_array(estante.casilleros_vacios(_cindolor())).contains_exactly([1])
	assert_array(estante.vencidos.casilleros(_cindolor())).contains_exactly([3])
	assert_int(estante.vencidos.cuantos()).is_equal(1)


func test_agarrar_una_sana_no_da_una_vencida() -> void:  # AC-STK-119
	var estante := _estante([1, 3])
	var unidad := estante.agarrar(_cindolor(), 0)
	assert_bool(unidad.vencido).is_false()
	assert_array(estante.vencidos.casilleros(_cindolor())).contains_exactly([1, 3])


func test_la_unidad_que_sale_de_la_caja_no_es_vencida() -> void:  # AC-STK-119
	var estante := _estante([1])
	assert_bool(estante.retirar(_cindolor()).vencido).is_false()


func test_la_vencida_colocada_en_otro_casillero_lo_marca_ahi() -> void:  # AC-STK-119
	var estante := _estante([1, 3])
	var vencida := estante.agarrar(_cindolor(), 1)
	estante.agarrar(_cindolor(), 0)
	assert_int(estante.colocar_unidad(vencida, _cindolor(), 0)).is_equal(Estante.Rechazo.NINGUNO)
	assert_array(estante.vencidos.casilleros(_cindolor())).contains_exactly([0, 3])


func test_la_vencida_colocada_sin_elegir_casillero_marca_el_primero_vacio() -> void:  # AC-STK-119
	var estante := _estante([2, 5])
	var vencida := estante.agarrar(_cindolor(), 5)
	assert_int(estante.colocar_unidad(vencida)).is_equal(Estante.Rechazo.NINGUNO)
	assert_array(estante.vencidos.casilleros(_cindolor())).contains_exactly([2, 5])


func test_la_sana_colocada_no_marca_nada() -> void:  # AC-STK-119
	var estante := _estante([2])
	var sana := estante.agarrar(_cindolor(), 0)
	assert_int(estante.colocar_unidad(sana)).is_equal(Estante.Rechazo.NINGUNO)
	assert_array(estante.vencidos.casilleros(_cindolor())).contains_exactly([2])


func test_tirar_un_vencido_deja_la_caja_como_estaba_y_no_llena_su_casillero() -> void:  # AC-STK-121
	var estante := _estante([1])
	var antes := estante.unidades_en_deposito(_cindolor())
	var vencida := estante.agarrar(_cindolor(), 1)
	assert_bool(estante.desechar(vencida)).is_true()
	assert_int(estante.unidades_en_deposito(_cindolor())).is_equal(antes)
	assert_int(estante.unidades_en_gondola(_cindolor())).is_equal(CASILLEROS - 1)
	assert_array(estante.casilleros_vacios(_cindolor())).contains_exactly([1])
	assert_int(estante.vencidos.cuantos()).is_zero()


func test_con_un_vencido_en_la_gondola_reponer_no_se_cumple() -> void:  # AC-STK-122
	var estante := _estante([0, 2, 4, 6, 7])
	assert_int(estante.unidades_en_gondola(_cindolor())).is_equal(CASILLEROS)
	assert_bool(estante.completada()).is_false()


func test_tirados_los_cinco_reponer_espera_a_las_sanas() -> void:  # AC-STK-122
	var casilleros := [0, 2, 4, 6, 7]
	var estante := _estante(casilleros)
	for casillero: int in casilleros:
		estante.desechar(estante.agarrar(_cindolor(), casillero))
	assert_bool(estante.completada()).is_false()
	_reponer(estante, casilleros.size())
	assert_bool(estante.completada()).is_true()


func test_uno_que_sigue_en_su_casillero_deja_reponer_sin_cumplir() -> void:  # AC-STK-122
	var casilleros := [0, 2, 4, 6, 7]
	var estante := _estante(casilleros)
	for casillero: int in casilleros.slice(1):
		estante.desechar(estante.agarrar(_cindolor(), casillero))
	_reponer(estante, casilleros.size() - 1)
	assert_int(estante.unidades_en_gondola(_cindolor())).is_equal(CASILLEROS)
	assert_bool(estante.completada()).is_false()


func test_al_cerrar_una_sana_en_la_mano_cuenta_como_puesta_y_una_vencida_no() -> void:  # AC-STK-122
	var con_sana := _estante([])
	var sana := con_sana.agarrar(_cindolor(), 1)
	assert_bool(con_sana.completada(sana)).is_true()
	var con_vencida := _estante([1])
	var vencida := con_vencida.agarrar(_cindolor(), 1)
	assert_bool(con_vencida.completada(vencida)).is_false()
