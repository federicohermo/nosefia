## Cuántas unidades hay de cada producto y **dónde**: el depósito y la góndola son dos lugares
## distintos, y esa distinción es la que hace que reponer sea una tarea y no una animación.
##
## Los productos son inventados acá con sus valores a propósito, y no leídos del catálogo: el
## día que el balance mueva un precio o un umbral, ninguno de estos AC cambia de resultado. La
## única excepción es el AC de la identidad por `id`, que necesita **dos instancias distintas del
## mismo producto** y por eso sí llama a `Catalogo.de()` — pero sólo compara unidades, así que
## tampoco se entera de un cambio de balance.
extends GdUnitTestSuite


func test_un_inventario_recien_construido_no_tiene_nada_en_ningun_lado() -> void:
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 4)
	var laysntt := Producto.new(Producto.Id.LAYSNTT, "Laysntt", 1100, 3)
	var productos: Array[Producto] = [actroncito, laysntt]
	var inventario := Inventario.new(productos)
	for producto in productos:
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(0)
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(0)


func test_el_mismo_producto_repetido_en_la_construccion_entra_una_sola_vez() -> void:
	# Dos productos con el mismo `id` en la lista de construcción son uno, no dos: si el segundo
	# pisara al primero, `faltantes()` devolvería el duplicado y la lista de reposición mostraría
	# la misma línea dos veces.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 4)
	var otro_actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 4)
	var productos: Array[Producto] = [actroncito, otro_actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, 1)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(1)
	assert_array(inventario.faltantes()).has_size(1)


func test_ingresar_al_deposito_no_toca_la_gondola() -> void:  # AC-STK-003
	# Las dos ubicaciones son dos números separados: si `ingresar` sumara a un total único, el
	# jugador no tendría nunca una góndola vacía con el depósito lleno, que es el estado que le
	# da la razón para ir al estante.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 4)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, 4)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.DEPOSITO)).is_equal(4)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(0)


func test_ingresar_una_cantidad_negativa_no_deja_la_gondola_bajo_cero() -> void:  # AC-STK-005
	# `ingresar` es la puerta por la que **entra** mercadería; la única que resta es la interna
	# que usan `mover` y `cobrar`. Sin el corte, un `-5` de quien reponga mal deja la góndola en
	# un número imposible que `faltantes()` lee como una góndola vacía cualquiera.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 4)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, 3)
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, -5)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(3)


func test_mover_una_unidad_la_saca_del_deposito_y_la_pone_en_la_gondola() -> void:
	# Es la operación que la tarea de reponer hace unidad por unidad, y por eso `mover` devuelve
	# cuántas movió de verdad: sin ese número la escena tendría que preguntar el stock antes de
	# cada gesto.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 4)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, 4)
	var movidas := inventario.mover(
		actroncito, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 1
	)
	assert_int(movidas).is_equal(1)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.DEPOSITO)).is_equal(3)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(1)


func test_pedir_mas_de_lo_que_hay_mueve_lo_que_hay_y_nunca_deja_un_negativo() -> void:  # AC-STK-006
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 4)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, 2)
	var movidas := inventario.mover(
		actroncito, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 5
	)
	assert_int(movidas).is_equal(2)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.DEPOSITO)).is_equal(0)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(2)


func test_mover_desde_un_deposito_vacio_no_mueve_nada_y_no_cambia_nada() -> void:  # AC-STK-006
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 4)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	var movidas := inventario.mover(
		actroncito, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 3
	)
	assert_int(movidas).is_equal(0)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.DEPOSITO)).is_equal(0)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(0)


# AC-STK-001
func test_consultar_con_otra_instancia_del_mismo_producto_encuentra_lo_guardado() -> void:
	# `Catalogo.de()` construye un producto nuevo en cada llamada, así que las tres instancias de
	# este test son objetos distintos. Un inventario indexado por instancia contestaría 0 acá,
	# sin error y sin que nada avise.
	var productos: Array[Producto] = [Catalogo.de(Producto.Id.ACTRONCITO)]
	var inventario := Inventario.new(productos)
	inventario.ingresar(Catalogo.de(Producto.Id.ACTRONCITO), Inventario.Ubicacion.GONDOLA, 2)
	var consultada := Catalogo.de(Producto.Id.ACTRONCITO)
	assert_int(inventario.unidades(consultada, Inventario.Ubicacion.GONDOLA)).is_equal(2)


func test_el_inventario_solo_conoce_los_productos_que_recibio() -> void:
	# Ingresar un producto que el inventario no recibió no lo agrega por la puerta de atrás: si
	# lo agregara, `faltantes()` empezaría a listar mercadería que el almacén no vende.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 4)
	var malbardo := Producto.new(Producto.Id.MALBARDO, "Malbardo", 1500, 2)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	assert_int(inventario.unidades(malbardo, Inventario.Ubicacion.GONDOLA)).is_equal(0)
	inventario.ingresar(malbardo, Inventario.Ubicacion.GONDOLA, 5)
	assert_int(inventario.unidades(malbardo, Inventario.Ubicacion.GONDOLA)).is_equal(0)


func test_por_debajo_del_umbral_falta_aunque_la_gondola_tenga_algo() -> void:  # AC-STK-007
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 5)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, 3)
	assert_array(inventario.faltantes()).contains([actroncito])


func test_justo_en_el_umbral_no_falta() -> void:  # AC-STK-007
	# El corte es `<`, no `<=`: con el umbral pisado la góndola está abastecida y reponer no
	# sería una tarea sino un trámite que nunca se termina.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 5)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, 5)
	assert_array(inventario.faltantes()).not_contains([actroncito])


func test_el_deposito_lleno_no_salva_a_la_gondola_vacia() -> void:  # AC-STK-007
	# Un `faltantes()` que sumara las dos ubicaciones leería como abastecida la góndola vacía con
	# el depósito lleno, que es el estado que le da al jugador la razón para ir al estante.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 5)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, 100)
	assert_array(inventario.faltantes()).contains([actroncito])


func test_faltantes_devuelve_los_que_faltan_y_solo_esos_en_el_orden_de_construccion() -> void:
	# Con tres productos y el del medio abastecido, un `faltantes()` que devolviera todos, o que
	# devolviera otro orden, se pone en rojo. Con dos productos los dos errores pasarían.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 5)
	var durextra := Producto.new(Producto.Id.DUREXTRA, "Durextra", 1200, 2)
	var laysntt := Producto.new(Producto.Id.LAYSNTT, "Laysntt", 1100, 3)
	var productos: Array[Producto] = [actroncito, durextra, laysntt]
	var inventario := Inventario.new(productos)
	inventario.ingresar(durextra, Inventario.Ubicacion.GONDOLA, 2)
	assert_array(inventario.faltantes()).contains_exactly([actroncito, laysntt])


## Un producto de umbral 8, el del criterio. Se inventa acá y no se lee del catálogo: el día que
## el balance mueva el umbral, las filas de los criterios no cambian de resultado.
func _de_umbral_ocho() -> Producto:
	return Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 8)


func _inventario_con(en_gondola: int, en_deposito: int) -> Inventario:
	var productos: Array[Producto] = [_de_umbral_ocho()]
	var inventario := Inventario.new(productos)
	inventario.ingresar(productos[0], Inventario.Ubicacion.GONDOLA, en_gondola)
	inventario.ingresar(productos[0], Inventario.Ubicacion.DEPOSITO, en_deposito)
	return inventario


func test_los_vendibles_son_lo_que_el_estante_no_necesita() -> void:  # AC-STK-018
	# Cada fila es `[góndola, depósito, vendibles]`. La de `0, 5` es la que pide el «nunca menos
	# de cero»: sin el corte daría `-3`, y un pedido de cero unidades pasaría el control.
	var filas := [[8, 2, 2], [0, 10, 2], [7, 3, 2], [8, 0, 0], [0, 5, 0]]
	for fila: Array in filas:
		var inventario := _inventario_con(fila[0], fila[1])
		(
			assert_int(inventario.vendibles(_de_umbral_ocho()))
			. override_failure_message("fila %s" % [fila])
			. is_equal(fila[2])
		)


func test_un_producto_que_el_inventario_no_conoce_no_tiene_vendibles() -> void:  # AC-STK-018
	var inventario := _inventario_con(0, 10)
	var malbardo := Producto.new(Producto.Id.MALBARDO, "Malbardo", 1500, 2)
	assert_int(inventario.vendibles(malbardo)).is_equal(0)


func test_la_venta_sale_del_deposito_y_no_toca_la_gondola() -> void:  # AC-CTR-015
	# Cada fila es `[góndola, depósito, venta, se cobra, góndola después, depósito después]`.
	var filas := [
		[8, 2, 2, true, 8, 0],
		[0, 10, 2, true, 0, 8],
		[0, 10, 3, false, 0, 10],
		[8, 0, 1, false, 8, 0],
	]
	for fila: Array in filas:
		var inventario := _inventario_con(fila[0], fila[1])
		var venta := Venta.new()
		venta.agregar(_de_umbral_ocho(), fila[2])
		var mensaje := "fila %s" % [fila]
		assert_bool(inventario.cobrar(venta)).override_failure_message(mensaje).is_equal(fila[3])
		(
			assert_int(inventario.unidades(_de_umbral_ocho(), Inventario.Ubicacion.GONDOLA))
			. override_failure_message(mensaje)
			. is_equal(fila[4])
		)
		(
			assert_int(inventario.unidades(_de_umbral_ocho(), Inventario.Ubicacion.DEPOSITO))
			. override_failure_message(mensaje)
			. is_equal(fila[5])
		)


func test_un_cobro_que_supera_los_vendibles_no_mueve_una_sola_unidad() -> void:  # AC-CTR-006
	# Todo o nada: la línea que sí entraba tampoco se descuenta. Un cobro a medias deja un
	# estado que el jugador no puede distinguir de una venta completa.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 4)
	var laysntt := Producto.new(Producto.Id.LAYSNTT, "Laysntt", 1100, 3)
	var productos: Array[Producto] = [actroncito, laysntt]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, 4)
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, 6)
	inventario.ingresar(laysntt, Inventario.Ubicacion.GONDOLA, 3)
	var venta := Venta.new()
	venta.agregar(actroncito, 2)
	venta.agregar(laysntt, 1)
	assert_bool(inventario.cobrar(venta)).is_false()
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(4)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.DEPOSITO)).is_equal(6)
	assert_int(inventario.unidades(laysntt, Inventario.Ubicacion.GONDOLA)).is_equal(3)
	assert_int(inventario.unidades(laysntt, Inventario.Ubicacion.DEPOSITO)).is_equal(0)


func test_cobrar_un_producto_que_el_inventario_no_conoce_no_vende_ni_toca_nada() -> void:
	# El desconocido tiene cero vendibles y cae por el mismo camino que «no alcanza». Sin este
	# caso, un `cobrar` que lo tratara como infinito devolvería `true` sin que nadie se entere.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 4)
	var malbardo := Producto.new(Producto.Id.MALBARDO, "Malbardo", 1500, 2)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, 10)
	var venta := Venta.new()
	venta.agregar(actroncito, 1)
	venta.agregar(malbardo, 1)
	assert_bool(inventario.cobrar(venta)).is_false()
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.DEPOSITO)).is_equal(10)
