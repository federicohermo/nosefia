## Lo que un comprador se lleva por la ventanilla, y cuánto suma.
##
## Los productos son inventados acá y no salen del catálogo: así el día que el balance mueva un
## precio, ninguna de estas cuentas cambia de resultado.
extends GdUnitTestSuite


func test_una_venta_sin_lineas_no_suma_nada_y_no_tiene_productos() -> void:
	var venta := Venta.new()
	assert_int(venta.total()).is_equal(0)
	assert_array(venta.productos()).is_empty()


func test_el_total_multiplica_el_precio_por_las_unidades_de_cada_linea() -> void:
	var gaseosa := Producto.new(Producto.Id.GASEOSA, "Gaseosa", 150, 3)
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 400, 4)
	var venta := Venta.new()
	venta.agregar(gaseosa, 2)
	venta.agregar(yerba, 1)
	assert_int(venta.total()).is_equal(700)


func test_agregar_dos_veces_el_mismo_producto_acumula_en_una_sola_linea() -> void:
	# Una línea por llamada haría que el mismo producto apareciera dos veces en el ticket: un
	# bug de pantalla nacido en el dominio.
	var arroz := Producto.new(Producto.Id.ARROZ, "Arroz", 900, 2)
	var venta := Venta.new()
	venta.agregar(arroz, 1)
	venta.agregar(arroz, 2)
	assert_int(venta.unidades_de(arroz)).is_equal(3)
	assert_array(venta.productos()).has_size(1)
