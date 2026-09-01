## Cuántas unidades hay de cada producto y **dónde**: el depósito y la góndola son dos lugares
## distintos, y esa distinción es la que hace que reponer sea una tarea y no una animación.
##
## Los productos son inventados acá y no salen del catálogo a propósito: el día que el balance
## mueva un precio o un umbral, ninguno de estos AC cambia de resultado.
extends GdUnitTestSuite


func test_un_inventario_recien_construido_no_tiene_nada_en_ningun_lado() -> void:
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 4)
	var arroz := Producto.new(Producto.Id.ARROZ, "Arroz", 1100, 3)
	var productos: Array[Producto] = [yerba, arroz]
	var inventario := Inventario.new(productos)
	for producto in productos:
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(0)
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(0)


func test_ingresar_al_deposito_no_toca_la_gondola() -> void:
	# Las dos ubicaciones son dos números separados: si `ingresar` sumara a un total único, el
	# jugador no tendría nunca una góndola vacía con el depósito lleno, que es el estado que le
	# da la razón para ir al estante.
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 4)
	var productos: Array[Producto] = [yerba]
	var inventario := Inventario.new(productos)
	inventario.ingresar(yerba, Inventario.Ubicacion.DEPOSITO, 4)
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.DEPOSITO)).is_equal(4)
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.GONDOLA)).is_equal(0)


func test_mover_una_unidad_la_saca_del_deposito_y_la_pone_en_la_gondola() -> void:
	# Es la operación que la tarea de reponer hace unidad por unidad, y por eso `mover` devuelve
	# cuántas movió de verdad: sin ese número la escena tendría que preguntar el stock antes de
	# cada gesto.
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 4)
	var productos: Array[Producto] = [yerba]
	var inventario := Inventario.new(productos)
	inventario.ingresar(yerba, Inventario.Ubicacion.DEPOSITO, 4)
	var movidas := inventario.mover(
		yerba, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 1
	)
	assert_int(movidas).is_equal(1)
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.DEPOSITO)).is_equal(3)
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.GONDOLA)).is_equal(1)


func test_pedir_mas_de_lo_que_hay_mueve_lo_que_hay_y_nunca_deja_un_negativo() -> void:
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 4)
	var productos: Array[Producto] = [yerba]
	var inventario := Inventario.new(productos)
	inventario.ingresar(yerba, Inventario.Ubicacion.DEPOSITO, 2)
	var movidas := inventario.mover(
		yerba, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 5
	)
	assert_int(movidas).is_equal(2)
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.DEPOSITO)).is_equal(0)
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.GONDOLA)).is_equal(2)


func test_mover_desde_un_deposito_vacio_no_mueve_nada_y_no_cambia_nada() -> void:
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 4)
	var productos: Array[Producto] = [yerba]
	var inventario := Inventario.new(productos)
	var movidas := inventario.mover(
		yerba, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 3
	)
	assert_int(movidas).is_equal(0)
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.DEPOSITO)).is_equal(0)
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.GONDOLA)).is_equal(0)


func test_consultar_con_otra_instancia_del_mismo_producto_encuentra_lo_guardado() -> void:
	# `Catalogo.de()` construye un producto nuevo en cada llamada, así que las tres yerbas de
	# este test son objetos distintos. Un inventario indexado por instancia contestaría 0 acá,
	# sin error y sin que nada avise.
	var productos: Array[Producto] = [Catalogo.de(Producto.Id.YERBA)]
	var inventario := Inventario.new(productos)
	inventario.ingresar(Catalogo.de(Producto.Id.YERBA), Inventario.Ubicacion.GONDOLA, 2)
	var consultada := Catalogo.de(Producto.Id.YERBA)
	assert_int(inventario.unidades(consultada, Inventario.Ubicacion.GONDOLA)).is_equal(2)


func test_el_inventario_solo_conoce_los_productos_que_recibio() -> void:
	# Ingresar un producto que el inventario no recibió no lo agrega por la puerta de atrás: si
	# lo agregara, `faltantes()` empezaría a listar mercadería que el almacén no vende.
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 4)
	var jabon := Producto.new(Producto.Id.JABON, "Jabón", 1500, 2)
	var productos: Array[Producto] = [yerba]
	var inventario := Inventario.new(productos)
	assert_int(inventario.unidades(jabon, Inventario.Ubicacion.GONDOLA)).is_equal(0)
	inventario.ingresar(jabon, Inventario.Ubicacion.GONDOLA, 5)
	assert_int(inventario.unidades(jabon, Inventario.Ubicacion.GONDOLA)).is_equal(0)


func test_por_debajo_del_umbral_falta_aunque_todavia_quede_algo_para_vender() -> void:
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 5)
	var productos: Array[Producto] = [yerba]
	var inventario := Inventario.new(productos)
	inventario.ingresar(yerba, Inventario.Ubicacion.GONDOLA, 3)
	assert_array(inventario.faltantes()).contains([yerba])
	assert_bool(inventario.hay_stock(yerba)).is_true()


func test_justo_en_el_umbral_no_falta() -> void:
	# El corte es `<`, no `<=`: con el umbral pisado la góndola está abastecida y reponer no
	# sería una tarea sino un trámite que nunca se termina.
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 5)
	var productos: Array[Producto] = [yerba]
	var inventario := Inventario.new(productos)
	inventario.ingresar(yerba, Inventario.Ubicacion.GONDOLA, 5)
	assert_array(inventario.faltantes()).not_contains([yerba])


func test_una_gondola_vacia_falta_y_no_tiene_con_que_vender() -> void:
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 5)
	var productos: Array[Producto] = [yerba]
	var inventario := Inventario.new(productos)
	assert_array(inventario.faltantes()).contains([yerba])
	assert_bool(inventario.hay_stock(yerba)).is_false()


func test_el_deposito_lleno_no_salva_a_la_gondola_vacia() -> void:
	# Las dos mitades importan. Un `hay_stock()` que sumara las dos ubicaciones pasa igual los
	# dos AC de arriba, y la góndola vacía con el depósito lleno —el estado que le da al
	# jugador la razón para ir al estante— se leería como «hay stock».
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 5)
	var productos: Array[Producto] = [yerba]
	var inventario := Inventario.new(productos)
	inventario.ingresar(yerba, Inventario.Ubicacion.DEPOSITO, 100)
	assert_array(inventario.faltantes()).contains([yerba])
	assert_bool(inventario.hay_stock(yerba)).is_false()


func test_faltantes_devuelve_los_que_faltan_y_solo_esos_en_el_orden_de_construccion() -> void:
	# Con tres productos y el del medio abastecido, un `faltantes()` que devolviera todos, o que
	# devolviera otro orden, se pone en rojo. Con dos productos los dos errores pasarían.
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 5)
	var fideos := Producto.new(Producto.Id.FIDEOS, "Fideos", 1200, 2)
	var arroz := Producto.new(Producto.Id.ARROZ, "Arroz", 1100, 3)
	var productos: Array[Producto] = [yerba, fideos, arroz]
	var inventario := Inventario.new(productos)
	inventario.ingresar(fideos, Inventario.Ubicacion.GONDOLA, 2)
	assert_array(inventario.faltantes()).contains_exactly([yerba, arroz])


func test_cobrar_descuenta_de_la_gondola_y_deja_el_deposito_intacto() -> void:
	# El depósito no se toca: lo que se vende por la ventanilla sale del estante, y si el cobro
	# pudiera tirar del fondo, reponer dejaría de ser necesario para vender.
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 4)
	var arroz := Producto.new(Producto.Id.ARROZ, "Arroz", 1100, 3)
	var productos: Array[Producto] = [yerba, arroz]
	var inventario := Inventario.new(productos)
	inventario.ingresar(yerba, Inventario.Ubicacion.GONDOLA, 5)
	inventario.ingresar(yerba, Inventario.Ubicacion.DEPOSITO, 7)
	inventario.ingresar(arroz, Inventario.Ubicacion.GONDOLA, 2)
	var venta := Venta.new()
	venta.agregar(yerba, 2)
	venta.agregar(arroz, 1)
	assert_bool(inventario.cobrar(venta)).is_true()
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.GONDOLA)).is_equal(3)
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.DEPOSITO)).is_equal(7)
	assert_int(inventario.unidades(arroz, Inventario.Ubicacion.GONDOLA)).is_equal(1)


func test_un_cobro_que_no_entra_en_el_stock_no_descuenta_una_sola_unidad() -> void:
	# Todo o nada: la línea que sí entraba tampoco se descuenta. Un cobro a medias deja un
	# estado que el jugador no puede distinguir de una venta completa.
	var yerba := Producto.new(Producto.Id.YERBA, "Yerba", 2500, 4)
	var arroz := Producto.new(Producto.Id.ARROZ, "Arroz", 1100, 3)
	var productos: Array[Producto] = [yerba, arroz]
	var inventario := Inventario.new(productos)
	inventario.ingresar(yerba, Inventario.Ubicacion.GONDOLA, 5)
	inventario.ingresar(arroz, Inventario.Ubicacion.GONDOLA, 1)
	var venta := Venta.new()
	venta.agregar(yerba, 2)
	venta.agregar(arroz, 3)
	assert_bool(inventario.cobrar(venta)).is_false()
	assert_int(inventario.unidades(yerba, Inventario.Ubicacion.GONDOLA)).is_equal(5)
	assert_int(inventario.unidades(arroz, Inventario.Ubicacion.GONDOLA)).is_equal(1)
