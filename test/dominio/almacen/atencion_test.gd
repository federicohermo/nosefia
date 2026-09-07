## Atender a un comprador: cuánto marca la caja, cuánto pagó, qué falta y cómo se despacha.
##
## **Ni un `Node3D` en toda la suite.** Todo lo que un criterio de este spec afirma se ejerce
## acá, sin levantar la ventanilla: es lo que hace que la pantalla pueda ser cáscara.
extends GdUnitTestSuite

const ATENCION := "res://src/dominio/almacen/atencion.gd"

## Cuántas unidades de cada producto se le ponen a la góndola cuando el caso quiere stock de
## sobra. Cualquier número por encima del pedido más grande de esta suite sirve.
const EN_GONDOLA := 9


func _productos() -> Array[Producto]:
	return [Catalogo.de(Producto.Id.YERBA), Catalogo.de(Producto.Id.JABON)]


func _pedido(unidades_de_yerba: int = 2, unidades_de_jabon: int = 1) -> Venta:
	var venta := Venta.new()
	venta.agregar(Catalogo.de(Producto.Id.YERBA), unidades_de_yerba)
	venta.agregar(Catalogo.de(Producto.Id.JABON), unidades_de_jabon)
	return venta


func _inventario(en_gondola: int = EN_GONDOLA) -> Inventario:
	var productos := _productos()
	var inventario := Inventario.new(productos)
	for producto in productos:
		inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, en_gondola)
	return inventario


func _atencion(paga: int, en_gondola: int = EN_GONDOLA, pedido: Venta = null) -> Atencion:
	var venta := pedido if pedido != null else _pedido()
	return Atencion.new(Comprador.new("Marta", venta, paga), _inventario(en_gondola))


func test_la_caja_marca_el_total_del_pedido_y_no_lo_vuelve_a_sumar() -> void:  # 013-AC2
	# Se compara contra `Venta.total()` y nunca contra un número escrito acá: una segunda suma
	# en la atención daría el mismo resultado hasta el día que el catálogo cambie, y ahí las dos
	# ventanas dirían distinto sin un solo error.
	var pedido := _pedido()
	var atencion := _atencion(0, EN_GONDOLA, pedido)
	assert_int(atencion.total_de_la_caja()).is_equal(pedido.total())


func test_la_atencion_no_conoce_lo_que_sale_cada_producto() -> void:  # 013-AC2
	# El criterio pide que la palabra que nombra ese dato no aparezca en el archivo. Es la forma
	# ejecutable de «la caja no vuelve a sumar»: sin el dato no hay con qué.
	var texto := FileAccess.get_file_as_string(ATENCION)
	assert_str(texto).is_not_empty()
	(
		assert_bool(texto.contains("precio"))
		. override_failure_message("`atencion.gd` nombra el dato con el que se vuelve a sumar")
		. is_false()
	)


func test_pagar_justo_da_una_diferencia_de_cero() -> void:  # 013-AC3
	var atencion := _atencion(0)
	assert_int(atencion.diferencia()).is_equal(-atencion.total_de_la_caja())
	var justo := _atencion(_pedido().total())
	assert_int(justo.diferencia()).is_equal(0)


func test_pagar_de_mas_da_una_diferencia_positiva() -> void:  # 013-AC3
	var total := _pedido().total()
	var atencion := _atencion(total + 700)
	assert_int(atencion.diferencia()).is_equal(700)


func test_pagar_de_menos_da_una_diferencia_negativa() -> void:  # 013-AC3
	# El signo es lo que el spec vino a comprar: un `abs()` mal puesto pasa los otros dos casos
	# y deja al comprador que paga de menos indistinguible del que paga de más.
	var total := _pedido().total()
	var atencion := _atencion(total - 700)
	assert_int(atencion.diferencia()).is_equal(-700)


func test_los_faltantes_nombran_exactamente_los_productos_que_no_alcanzan() -> void:  # 013-AC4
	# Con una sola unidad en góndola, la yerba —que se pide de a dos— falta y el jabón no.
	var atencion := _atencion(0, 1)
	var faltantes := atencion.faltantes_del_pedido()
	assert_int(faltantes.size()).is_equal(1)
	assert_int(faltantes[0].id).is_equal(Producto.Id.YERBA)


func test_con_stock_de_sobra_no_falta_nada() -> void:  # 013-AC4
	assert_array(_atencion(0).faltantes_del_pedido()).is_empty()


func test_cobrar_con_stock_descuenta_de_la_gondola() -> void:  # 013-AC4
	var pedido := _pedido()
	var inventario := _inventario()
	var atencion := Atencion.new(Comprador.new("Marta", pedido, pedido.total()), inventario)
	assert_int(atencion.cobrar()).is_equal(Atencion.Resultado.COBRADA)
	var yerba := Catalogo.de(Producto.Id.YERBA)
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.GONDOLA)).is_equal(EN_GONDOLA - 2)
	assert_bool(atencion.despachada()).is_true()
	assert_bool(atencion.vendida()).is_true()


func test_cobrar_sin_stock_no_mueve_una_sola_unidad() -> void:  # 013-AC4
	# `Inventario.cobrar()` es todo o nada, y la atención se apoya en eso: descontar el jabón y
	# no la yerba dejaría un estado que el jugador no puede distinguir de una venta completa.
	var inventario := _inventario(1)
	var pedido := _pedido()
	var atencion := Atencion.new(Comprador.new("Marta", pedido, pedido.total()), inventario)
	assert_int(atencion.cobrar()).is_equal(Atencion.Resultado.SIN_STOCK)
	for producto in _productos():
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(1)
	assert_bool(atencion.despachada()).is_false()


func test_cobrar_dos_veces_avisa_que_ya_estaba_despachada() -> void:  # 013-AC4
	var inventario := _inventario()
	var pedido := _pedido()
	var atencion := Atencion.new(Comprador.new("Marta", pedido, pedido.total()), inventario)
	assert_int(atencion.cobrar()).is_equal(Atencion.Resultado.COBRADA)
	assert_int(atencion.cobrar()).is_equal(Atencion.Resultado.YA_DESPACHADA)
	var yerba := Catalogo.de(Producto.Id.YERBA)
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.GONDOLA)).is_equal(EN_GONDOLA - 2)


func test_despachar_sin_vender_no_toca_el_inventario() -> void:  # 013-AC5
	# Es lo que desencadena `CAJA` de `REPONER`: la góndola arranca vacía, así que exigir la
	# venta dejaría dos obligatorias encadenadas y la primera noche imposible.
	var inventario := _inventario()
	var atencion := Atencion.new(Comprador.new("Marta", _pedido(), 0), inventario)
	assert_bool(atencion.despachar_sin_vender()).is_true()
	for producto in _productos():
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(EN_GONDOLA)
	assert_bool(atencion.despachada()).is_true()
	assert_bool(atencion.vendida()).is_false()


func test_despachar_dos_veces_devuelve_false_la_segunda() -> void:  # 013-AC5
	var atencion := _atencion(0)
	assert_bool(atencion.despachar_sin_vender()).is_true()
	assert_bool(atencion.despachar_sin_vender()).is_false()


func test_cobrar_sobre_una_despachada_a_mano_no_vende() -> void:  # 013-AC5
	var inventario := _inventario()
	var atencion := Atencion.new(Comprador.new("Marta", _pedido(), 0), inventario)
	atencion.despachar_sin_vender()
	assert_int(atencion.cobrar()).is_equal(Atencion.Resultado.YA_DESPACHADA)
	for producto in _productos():
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(EN_GONDOLA)
