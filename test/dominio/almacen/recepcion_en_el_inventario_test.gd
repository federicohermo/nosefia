extends GdUnitTestSuite


func test_vender_la_unidad_retirada_conserva_la_caja() -> void:  # AC-STK-054
	var producto := Catalogo.de(Producto.Id.MAROLINI)
	var inventario := Inventario.new([producto], {producto.id: 1})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 8)
	inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, 1)
	var estante := Estante.new(inventario, [producto])
	var unidad := estante.retirar(producto)
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(7)
	assert_bool(inventario.vender_unidades([unidad])).is_true()
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(7)
	assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(7)
	assert_bool(inventario.vender_unidades([unidad])).is_false()
	assert_bool(inventario.anotar_afuera(unidad)).is_false()
	assert_bool(estante.devolver(unidad)).is_false()


func test_la_gondola_vendida_sigue_vacia_hasta_reponer() -> void:  # AC-STK-055
	var producto := Catalogo.de(Producto.Id.ZUCARACHAS)
	var inventario := Inventario.new([producto], {producto.id: 2})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 8)
	inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, 2)
	var estante := Estante.new(inventario, [producto])
	var unidad := estante.agarrar(producto, 0)
	assert_bool(inventario.vender_unidades([unidad])).is_true()
	assert_bool(estante.completada()).is_false()
	assert_array(estante.casilleros_vacios(producto)).contains_exactly([0])
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(8)
	var repuesto := estante.retirar(producto)
	assert_int(estante.colocar_unidad(repuesto, producto, 0)).is_equal(Estante.Rechazo.NINGUNO)
	assert_bool(estante.completada()).is_true()


func test_un_lote_invalido_no_retira_ninguna_identidad() -> void:  # AC-STK-054
	var producto := Catalogo.de(Producto.Id.MAROLINI)
	var inventario := Inventario.new([producto])
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 8)
	var unidad := Estante.new(inventario, [producto]).retirar(producto)
	assert_bool(inventario.vender_unidades([unidad, unidad])).is_false()
	assert_bool(inventario.vender_unidades([unidad, UnidadDeProducto.new(producto)])).is_false()
	assert_bool(inventario.esta_afuera(unidad)).is_true()
	assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(8)
