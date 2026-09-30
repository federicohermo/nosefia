## Cuántas unidades hay de cada producto y **dónde**: el depósito y la góndola son dos lugares
## distintos, y esa distinción es la que hace que reponer sea una tarea y no una animación.
##
## Los productos y sus casilleros son inventados acá a propósito, y no leídos del catálogo ni del
## local: el día que el balance mueva un precio o el modelo una fila, ninguno de estos AC cambia
## de resultado. La
## única excepción es el AC de la identidad por `id`, que necesita **dos instancias distintas del
## mismo producto** y por eso sí llama a `Catalogo.de()` — pero sólo compara unidades, así que
## tampoco se entera de un cambio de balance.
extends GdUnitTestSuite


func test_un_inventario_recien_construido_no_tiene_nada_en_ningun_lado() -> void:
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var laysntt := Producto.new(Producto.Id.LAYSNTT, "Laysntt", 1100)
	var productos: Array[Producto] = [actroncito, laysntt]
	var inventario := Inventario.new(productos)
	for producto in productos:
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(0)
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(0)


func test_el_mismo_producto_repetido_en_la_construccion_entra_una_sola_vez() -> void:
	# Dos productos con el mismo `id` en la lista de construcción son uno, no dos: si el segundo
	# pisara al primero, `faltantes()` devolvería el duplicado y la lista de reposición mostraría
	# la misma línea dos veces.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var otro_actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var productos: Array[Producto] = [actroncito, otro_actroncito]
	var inventario := Inventario.new(productos, {Producto.Id.ACTRONCITO: 4})
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, 1)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(1)
	assert_array(inventario.faltantes()).has_size(1)


func test_ingresar_al_deposito_no_toca_la_gondola() -> void:  # AC-STK-003
	# Las dos ubicaciones son dos números separados: si `ingresar` sumara a un total único, el
	# jugador no tendría nunca una góndola vacía con el depósito lleno, que es el estado que le
	# da la razón para ir al estante.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, 4)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.DEPOSITO)).is_equal(4)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(0)


func test_ingresar_una_cantidad_negativa_no_deja_la_gondola_bajo_cero() -> void:  # AC-STK-005
	# `ingresar` es la puerta por la que **entra** mercadería; la única que resta es la interna
	# que usan `mover` y `cobrar`. Sin el corte, un `-5` de quien reponga mal deja la góndola en
	# un número imposible que `faltantes()` lee como una góndola vacía cualquiera.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, 3)
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, -5)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(3)


func test_mover_una_unidad_la_saca_del_deposito_y_la_pone_en_la_gondola() -> void:
	# Es la operación que la tarea de reponer hace unidad por unidad, y por eso `mover` devuelve
	# cuántas movió de verdad: sin ese número la escena tendría que preguntar el stock antes de
	# cada gesto.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
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
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
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
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
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
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var malbardo := Producto.new(Producto.Id.MALBARDO, "Malbardo", 1500)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	assert_int(inventario.unidades(malbardo, Inventario.Ubicacion.GONDOLA)).is_equal(0)
	inventario.ingresar(malbardo, Inventario.Ubicacion.GONDOLA, 5)
	assert_int(inventario.unidades(malbardo, Inventario.Ubicacion.GONDOLA)).is_equal(0)


func test_con_un_casillero_vacio_falta_aunque_la_gondola_tenga_algo() -> void:  # AC-STK-007
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos, {Producto.Id.ACTRONCITO: 3})
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, 2)
	assert_array(inventario.faltantes()).contains([actroncito])


func test_con_la_fila_completa_no_falta() -> void:  # AC-STK-007
	# El corte es `<`, no `<=`: con la fila completa la góndola está abastecida y reponer no
	# sería una tarea sino un trámite que nunca se termina.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos, {Producto.Id.ACTRONCITO: 3})
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, 3)
	assert_array(inventario.faltantes()).not_contains([actroncito])


func test_el_deposito_lleno_no_salva_a_la_gondola_vacia() -> void:  # AC-STK-007
	# Un `faltantes()` que sumara las dos ubicaciones leería como abastecida la góndola vacía con
	# el depósito lleno, que es el estado que le da al jugador la razón para ir al estante.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos, {Producto.Id.ACTRONCITO: 5})
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, 100)
	assert_array(inventario.faltantes()).contains([actroncito])


func test_sin_casilleros_la_gondola_no_pide_nada() -> void:
	# Un producto sin casilleros declarados no tiene dónde ir en la góndola: no falta nunca y todo
	# su depósito se vende. Uno que el inventario no conoce tampoco tiene casilleros.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var malbardo := Producto.new(Producto.Id.MALBARDO, "Malbardo", 1500)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, 6)
	assert_int(inventario.casilleros(actroncito)).is_zero()
	assert_int(inventario.casilleros(malbardo)).is_zero()
	assert_array(inventario.faltantes()).is_empty()
	assert_int(inventario.vendibles(actroncito)).is_equal(6)


func test_faltantes_devuelve_los_que_faltan_y_solo_esos_en_el_orden_de_construccion() -> void:
	# Con tres productos y el del medio abastecido, un `faltantes()` que devolviera todos, o que
	# devolviera otro orden, se pone en rojo. Con dos productos los dos errores pasarían.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var durextra := Producto.new(Producto.Id.DUREXTRA, "Durextra", 1200)
	var laysntt := Producto.new(Producto.Id.LAYSNTT, "Laysntt", 1100)
	var productos: Array[Producto] = [actroncito, durextra, laysntt]
	var casilleros: Dictionary[Producto.Id, int] = {
		Producto.Id.ACTRONCITO: 5, Producto.Id.DUREXTRA: 2, Producto.Id.LAYSNTT: 3
	}
	var inventario := Inventario.new(productos, casilleros)
	inventario.ingresar(durextra, Inventario.Ubicacion.GONDOLA, 2)
	assert_array(inventario.faltantes()).contains_exactly([actroncito, laysntt])


## El producto de los criterios de vendibles. Se inventa acá y no se lee del catálogo, y su fila
## de 8 casilleros la declara `_inventario_con()`: el día que el modelo mueva una fila, las filas
## de los criterios no cambian de resultado.
func _de_ocho_casilleros() -> Producto:
	return Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)


## El inventario del producto de los criterios, con esas unidades en cada lugar y esas afuera de
## su caja, que siguen contadas en el depósito.
func _inventario_con(en_gondola: int, en_deposito: int, afuera: int = 0) -> Inventario:
	var productos: Array[Producto] = [_de_ocho_casilleros()]
	var inventario := Inventario.new(productos, {Producto.Id.ACTRONCITO: 8})
	inventario.ingresar(productos[0], Inventario.Ubicacion.GONDOLA, en_gondola)
	inventario.ingresar(productos[0], Inventario.Ubicacion.DEPOSITO, en_deposito)
	for _unidad in afuera:
		inventario.anotar_afuera(UnidadDeProducto.new(productos[0]))
	return inventario


func test_los_vendibles_descuentan_el_mayor_entre_vacios_y_afuera() -> void:  # AC-STK-018
	# Cada fila es `[góndola, depósito, afuera, vendibles]`. La de `0, 5` es la que pide el «nunca
	# menos de cero»: sin el corte daría `-3`, y un pedido de cero unidades pasaría el control. Las
	# de `5, 8` separan el mayor de la suma: con 1 afuera la espera un vacío, y con 4 no alcanzan.
	var filas := [
		[8, 2, 0, 2],
		[0, 10, 0, 2],
		[7, 3, 0, 2],
		[8, 0, 0, 0],
		[0, 5, 0, 0],
		[8, 8, 0, 8],
		[8, 8, 3, 5],
		[5, 8, 1, 5],
		[5, 8, 4, 4],
		[0, 8, 8, 0],
		[8, 8, 8, 0],
	]
	for fila: Array in filas:
		var inventario := _inventario_con(fila[0], fila[1], fila[2])
		(
			assert_int(inventario.vendibles(_de_ocho_casilleros()))
			. override_failure_message("fila %s" % [fila])
			. is_equal(fila[3])
		)


func test_lo_de_afuera_se_anota_una_vez_y_no_sale_del_deposito() -> void:
	# Afuera es una marca sobre el depósito y no un tercer lugar: anotarla y quitarla no mueven una
	# unidad. La misma unidad anotada dos veces le restaría dos a la caja por una sola que salió.
	var actroncito := _de_ocho_casilleros()
	var inventario := _inventario_con(0, 3)
	var unidad := UnidadDeProducto.new(actroncito)
	assert_bool(inventario.esta_afuera(unidad)).is_false()
	assert_bool(inventario.anotar_afuera(unidad)).is_true()
	assert_bool(inventario.anotar_afuera(unidad)).is_false()
	assert_bool(inventario.esta_afuera(unidad)).is_true()
	assert_int(inventario.afuera(Catalogo.de(Producto.Id.ACTRONCITO))).is_equal(1)
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.DEPOSITO)).is_equal(3)
	# Lo que el inventario no conoce no se anota, y nada se cuenta afuera por un producto nulo.
	var malbardo := Producto.new(Producto.Id.MALBARDO, "Malbardo", 1500)
	assert_bool(inventario.anotar_afuera(UnidadDeProducto.new(malbardo))).is_false()
	assert_bool(inventario.anotar_afuera(null)).is_false()
	assert_int(inventario.afuera(malbardo)).is_zero()
	assert_int(inventario.afuera(null)).is_zero()
	assert_bool(inventario.quitar_de_afuera(unidad)).is_true()
	assert_bool(inventario.quitar_de_afuera(unidad)).is_false()
	assert_int(inventario.afuera(actroncito)).is_zero()
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.DEPOSITO)).is_equal(3)


func test_un_producto_que_el_inventario_no_conoce_no_tiene_vendibles() -> void:  # AC-STK-018
	var inventario := _inventario_con(0, 10)
	var malbardo := Producto.new(Producto.Id.MALBARDO, "Malbardo", 1500)
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
		venta.agregar(_de_ocho_casilleros(), fila[2])
		var mensaje := "fila %s" % [fila]
		assert_bool(inventario.cobrar(venta)).override_failure_message(mensaje).is_equal(fila[3])
		(
			assert_int(inventario.unidades(_de_ocho_casilleros(), Inventario.Ubicacion.GONDOLA))
			. override_failure_message(mensaje)
			. is_equal(fila[4])
		)
		(
			assert_int(inventario.unidades(_de_ocho_casilleros(), Inventario.Ubicacion.DEPOSITO))
			. override_failure_message(mensaje)
			. is_equal(fila[5])
		)


func test_un_cobro_que_supera_los_vendibles_no_mueve_una_sola_unidad() -> void:  # AC-CTR-006
	# Todo o nada: la línea que sí entraba tampoco se descuenta. Un cobro a medias deja un
	# estado que el jugador no puede distinguir de una venta completa.
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var laysntt := Producto.new(Producto.Id.LAYSNTT, "Laysntt", 1100)
	var productos: Array[Producto] = [actroncito, laysntt]
	var inventario := Inventario.new(productos, {Producto.Id.ACTRONCITO: 4, Producto.Id.LAYSNTT: 3})
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
	var actroncito := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500)
	var malbardo := Producto.new(Producto.Id.MALBARDO, "Malbardo", 1500)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos)
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, 10)
	var venta := Venta.new()
	venta.agregar(actroncito, 1)
	venta.agregar(malbardo, 1)
	assert_bool(inventario.cobrar(venta)).is_false()
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.DEPOSITO)).is_equal(10)
