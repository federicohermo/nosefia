## Lo que un comprador se lleva por la ventanilla, y cuánto suma.
##
## Los productos de las cuentas son inventados acá y no leídos del catálogo: así el día que el
## balance mueva un precio, ningún total de estos cambia de resultado. El único que llama a
## `Catalogo.de()` es el de la identidad por `id`, que necesita dos instancias distintas del
## mismo producto y no mira ni el precio ni el umbral.
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


func test_dos_instancias_del_mismo_producto_son_una_sola_linea() -> void:
	# El gemelo del AC de identidad del inventario, y sin él la acumulación por `id` que promete
	# el comentario de `venta.gd` no se puede ver fallar: con una sola instancia, una venta
	# indexada por objeto pasa el AC de arriba igual. `Catalogo.de()` construye una yerba nueva
	# en cada llamada, así que acá hay dos objetos distintos del mismo producto.
	var una := Catalogo.de(Producto.Id.YERBA)
	var otra := Catalogo.de(Producto.Id.YERBA)
	var venta := Venta.new()
	venta.agregar(una, 1)
	venta.agregar(otra, 2)
	assert_int(venta.unidades_de(Catalogo.de(Producto.Id.YERBA))).is_equal(3)
	assert_array(venta.productos()).has_size(1)


func test_preguntar_por_un_producto_que_no_esta_en_la_venta_devuelve_cero() -> void:
	# Es la rama de la que depende `Inventario.cobrar()` para no reventar con un ticket flaco.
	var arroz := Producto.new(Producto.Id.ARROZ, "Arroz", 900, 2)
	var venta := Venta.new()
	assert_int(venta.unidades_de(arroz)).is_equal(0)


func test_agregar_una_cantidad_que_no_es_positiva_no_deja_linea_ni_resta() -> void:
	# Un `agregar` negativo pasaba el control de stock de `cobrar()` —`-3 > 0` es falso— y el
	# cobro terminaba **sumando** tres unidades a la góndola: mercadería fabricada por la caja.
	# Y un `agregar(p, 0)` dejaba una línea vacía en el ticket.
	var arroz := Producto.new(Producto.Id.ARROZ, "Arroz", 900, 2)
	var venta := Venta.new()
	venta.agregar(arroz, -3)
	venta.agregar(arroz, 0)
	assert_int(venta.unidades_de(arroz)).is_equal(0)
	assert_array(venta.productos()).is_empty()
	assert_int(venta.total()).is_equal(0)
