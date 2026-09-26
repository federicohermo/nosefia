## La obligatoria de atender: quién sigue, cuántos van despachados y cuánto se desvió la caja.
##
## **Ningún caso arma la lista con la constante del balance.** Se arma con uno o con tres, y eso
## es exactamente lo que el contrato pide: la tarea recibe la lista y no sabe cuántos
## compradores pide una jornada.
extends GdUnitTestSuite

const TAREA := "res://src/dominio/almacen/tarea_de_atender.gd"

const VENDIBLES := 9


func _productos() -> Array[Producto]:
	return [Catalogo.de(Producto.Id.ACTRONCITO)]


func _pedido(unidades: int = 1) -> Venta:
	var venta := Venta.new()
	venta.agregar(Catalogo.de(Producto.Id.ACTRONCITO), unidades)
	return venta


## La góndola llena, así que todo el depósito es vendible.
func _inventario(vendibles: int = VENDIBLES) -> Inventario:
	var productos := _productos()
	var inventario := Inventario.new(productos)
	for producto in productos:
		inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, producto.umbral)
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, vendibles)
	return inventario


func _compradores(cuantos: int, de_mas: int = 0) -> Array[Comprador]:
	var lista: Array[Comprador] = []
	for indice in range(cuantos):
		var pedido := _pedido()
		lista.append(Comprador.new("Comprador %d" % indice, pedido, pedido.total() + de_mas))
	return lista


func test_atender_devuelve_los_compradores_en_orden_y_despues_nada() -> void:
	var tarea := TareaDeAtender.new(_compradores(3), _inventario())
	assert_str(tarea.atender().nombre()).is_equal("Comprador 0")
	assert_str(tarea.atender().nombre()).is_equal("Comprador 1")
	assert_str(tarea.atender().nombre()).is_equal("Comprador 2")
	assert_object(tarea.atender()).is_null()


func test_la_atencion_en_curso_es_la_del_ultimo_que_llego() -> void:
	var tarea := TareaDeAtender.new(_compradores(2), _inventario())
	assert_object(tarea.atencion()).is_null()
	var primero := tarea.atender()
	assert_object(tarea.atencion().comprador()).is_same(primero)
	var segundo := tarea.atender()
	assert_object(tarea.atencion().comprador()).is_same(segundo)


func test_despachados_cuenta_las_dos_formas_de_despachar() -> void:  # AC-CTR-009
	# Vender y despachar sin vender cuentan igual para el jefe: la tarea es atender, no vender.
	var tarea := TareaDeAtender.new(_compradores(2), _inventario())
	tarea.atender()
	tarea.atencion().cobrar()
	assert_int(tarea.despachados()).is_equal(1)
	tarea.atender()
	tarea.atencion().despachar_sin_vender()
	assert_int(tarea.despachados()).is_equal(2)


func test_un_comprador_que_llego_y_no_se_despacho_no_cuenta() -> void:
	var tarea := TareaDeAtender.new(_compradores(2), _inventario())
	tarea.atender()
	assert_int(tarea.despachados()).is_equal(0)
	assert_bool(tarea.completada()).is_false()


# AC-CTR-009
func test_la_tarea_se_completa_con_todos_despachados_se_les_haya_vendido_o_no() -> void:
	var tarea := TareaDeAtender.new(_compradores(2), _inventario())
	tarea.atender()
	tarea.atencion().cobrar()
	assert_bool(tarea.completada()).is_false()
	tarea.atender()
	tarea.atencion().despachar_sin_vender()
	assert_bool(tarea.completada()).is_true()


func test_la_diferencia_acumulada_suma_solo_las_cobradas() -> void:  # AC-CTR-010
	# Al que se despachó sin vender no se le cobró nada, así que su diferencia no es plata que
	# falte en la caja: sumarla haría que despachar sin vender pareciera un robo.
	var tarea := TareaDeAtender.new(_compradores(2, 500), _inventario())
	tarea.atender()
	tarea.atencion().cobrar()
	assert_int(tarea.diferencia_acumulada()).is_equal(500)
	tarea.atender()
	tarea.atencion().despachar_sin_vender()
	assert_int(tarea.diferencia_acumulada()).is_equal(500)


func test_la_diferencia_acumulada_conserva_los_signos() -> void:  # AC-CTR-011
	# Uno paga 500 de más y el otro 500 de menos: con un `abs()` en el camino esto daría 1000.
	var compradores := _compradores(1, 500)
	compradores.append_array(_compradores(1, -500))
	var tarea := TareaDeAtender.new(compradores, _inventario())
	for _comprador in compradores:
		tarea.atender()
		tarea.atencion().cobrar()
	assert_int(tarea.diferencia_acumulada()).is_equal(0)


func test_la_tarea_se_arma_con_uno_solo_y_funciona_igual() -> void:
	var tarea := TareaDeAtender.new(_compradores(1), _inventario())
	tarea.atender()
	tarea.atencion().despachar_sin_vender()
	assert_bool(tarea.completada()).is_true()
	assert_int(tarea.despachados()).is_equal(1)


func test_la_tarea_no_nombra_cuantos_compradores_pide_la_jornada() -> void:
	# Sin esto, un test no se podría armar con tres, y el balance de la ventanilla quedaría
	# atado a la aritmética de la tarea: mover el número rompería casos que no hablan de él.
	var texto := FileAccess.get_file_as_string(TAREA)
	assert_str(texto).is_not_empty()
	(
		assert_bool(texto.contains("COMPRADORES_POR_JORNADA"))
		. override_failure_message("`tarea_de_atender.gd` nombra la constante del balance")
		. is_false()
	)


func test_en_la_ventanilla_esta_el_que_llego_y_todavia_no_se_despacho() -> void:
	# Es la pregunta con la que la ventanilla decide si sigue con el que está o llama al
	# siguiente. Si contestara al despachado, cerrar y reabrir el panel llamaría a uno de más y
	# el último se iría sin atender: la obligatoria quedaría imposible sin un solo error.
	var tarea := TareaDeAtender.new(_compradores(2), _inventario())
	assert_object(tarea.en_ventanilla()).is_null()
	var primero := tarea.atender()
	assert_object(tarea.en_ventanilla()).is_same(primero)
	tarea.atencion().despachar_sin_vender()
	assert_object(tarea.en_ventanilla()).is_null()


func test_el_segundo_comprador_ve_los_vendibles_que_dejo_el_primero() -> void:  # AC-CTR-017
	# Los dos compradores comparten el inventario. Si cada atención mirara una copia, el segundo
	# vería los vendibles del principio de la noche y se llevaría lo que el estante necesita.
	var producto := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 2500, 8)
	var productos: Array[Producto] = [producto]
	var inventario := Inventario.new(productos)
	inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, 8)
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 2)
	var compradores: Array[Comprador] = []
	for unidades: int in [1, 2]:
		var pedido := Venta.new()
		pedido.agregar(producto, unidades)
		compradores.append(Comprador.new("Pide %d" % unidades, pedido, pedido.total()))
	var tarea := TareaDeAtender.new(compradores, inventario)
	tarea.atender()
	assert_int(tarea.atencion().cobrar()).is_equal(Atencion.Resultado.COBRADA)
	tarea.atender()
	assert_int(tarea.atencion().cobrar()).is_equal(Atencion.Resultado.SIN_STOCK)
	assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(8)


func _compradores_que_piden(unidades: Array[int]) -> Array[Comprador]:
	var lista: Array[Comprador] = []
	for cuantas in unidades:
		var pedido := _pedido(cuantas)
		lista.append(Comprador.new("Pide %d" % cuantas, pedido, pedido.total()))
	return lista


func test_lo_vendido_suma_los_pedidos_cobrados_del_mismo_producto() -> void:  # AC-CTR-018
	var tarea := TareaDeAtender.new(_compradores_que_piden([2, 1]), _inventario())
	for _vez in 2:
		tarea.atender()
		tarea.atencion().cobrar()
	assert_int(tarea.vendidas_de(Catalogo.de(Producto.Id.ACTRONCITO))).is_equal(3)


func test_despachar_sin_vender_no_suma_a_lo_vendido() -> void:  # AC-CTR-019
	var tarea := TareaDeAtender.new(_compradores_que_piden([2]), _inventario())
	tarea.atender()
	tarea.atencion().despachar_sin_vender()
	assert_int(tarea.vendidas_de(Catalogo.de(Producto.Id.ACTRONCITO))).is_equal(0)


func test_un_cobro_rechazado_no_suma_a_lo_vendido() -> void:  # AC-CTR-019
	var tarea := TareaDeAtender.new(_compradores_que_piden([2]), _inventario(1))
	tarea.atender()
	assert_int(tarea.atencion().cobrar()).is_equal(Atencion.Resultado.SIN_STOCK)
	assert_int(tarea.vendidas_de(Catalogo.de(Producto.Id.ACTRONCITO))).is_equal(0)


func test_un_producto_que_nadie_compro_contesta_cero() -> void:  # AC-CTR-020
	var tarea := TareaDeAtender.new(_compradores_que_piden([2, 1]), _inventario())
	for _vez in 2:
		tarea.atender()
		tarea.atencion().cobrar()
	assert_int(tarea.vendidas_de(Catalogo.de(Producto.Id.DUREXTRA))).is_equal(0)
	assert_int(tarea.vendidas_de(null)).is_equal(0)
