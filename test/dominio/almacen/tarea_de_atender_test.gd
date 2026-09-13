## La obligatoria de atender: quién sigue, cuántos van despachados y cuánto se desvió la caja.
##
## **Ningún caso arma la lista con la constante del balance.** Se arma con uno o con tres, y eso
## es exactamente lo que el AC8 pide: la tarea recibe la lista y no sabe cuántos compradores pide
## una jornada.
extends GdUnitTestSuite

const TAREA := "res://src/dominio/almacen/tarea_de_atender.gd"

const EN_GONDOLA := 9


func _productos() -> Array[Producto]:
	return [Catalogo.de(Producto.Id.YERBA)]


func _pedido(unidades: int = 1) -> Venta:
	var venta := Venta.new()
	venta.agregar(Catalogo.de(Producto.Id.YERBA), unidades)
	return venta


func _inventario(en_gondola: int = EN_GONDOLA) -> Inventario:
	var productos := _productos()
	var inventario := Inventario.new(productos)
	for producto in productos:
		inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, en_gondola)
	return inventario


func _compradores(cuantos: int, de_mas: int = 0) -> Array[Comprador]:
	var lista: Array[Comprador] = []
	for indice in range(cuantos):
		var pedido := _pedido()
		lista.append(Comprador.new("Comprador %d" % indice, pedido, pedido.total() + de_mas))
	return lista


func test_atender_devuelve_los_compradores_en_orden_y_despues_nada() -> void:  # 013-AC6
	var tarea := TareaDeAtender.new(_compradores(3), _inventario())
	assert_str(tarea.atender().nombre()).is_equal("Comprador 0")
	assert_str(tarea.atender().nombre()).is_equal("Comprador 1")
	assert_str(tarea.atender().nombre()).is_equal("Comprador 2")
	assert_object(tarea.atender()).is_null()


func test_la_atencion_en_curso_es_la_del_ultimo_que_llego() -> void:  # 013-AC6
	var tarea := TareaDeAtender.new(_compradores(2), _inventario())
	assert_object(tarea.atencion()).is_null()
	var primero := tarea.atender()
	assert_object(tarea.atencion().comprador()).is_same(primero)
	var segundo := tarea.atender()
	assert_object(tarea.atencion().comprador()).is_same(segundo)


func test_despachados_cuenta_las_dos_formas_de_despachar() -> void:  # 013-AC6
	# Vender y despachar sin vender cuentan igual para el jefe: la tarea es atender, no vender.
	var tarea := TareaDeAtender.new(_compradores(2), _inventario())
	tarea.atender()
	tarea.atencion().cobrar()
	assert_int(tarea.despachados()).is_equal(1)
	tarea.atender()
	tarea.atencion().despachar_sin_vender()
	assert_int(tarea.despachados()).is_equal(2)


func test_un_comprador_que_llego_y_no_se_despacho_no_cuenta() -> void:  # 013-AC6
	var tarea := TareaDeAtender.new(_compradores(2), _inventario())
	tarea.atender()
	assert_int(tarea.despachados()).is_equal(0)
	assert_bool(tarea.completada()).is_false()


func test_la_tarea_se_completa_con_todos_despachados_se_les_haya_vendido_o_no() -> void:
	# 013-AC7
	var tarea := TareaDeAtender.new(_compradores(2), _inventario())
	tarea.atender()
	tarea.atencion().cobrar()
	assert_bool(tarea.completada()).is_false()
	tarea.atender()
	tarea.atencion().despachar_sin_vender()
	assert_bool(tarea.completada()).is_true()


func test_la_diferencia_acumulada_suma_solo_las_cobradas() -> void:  # 013-AC7
	# Al que se despachó sin vender no se le cobró nada, así que su diferencia no es plata que
	# falte en la caja: sumarla haría que despachar sin vender pareciera un robo.
	var tarea := TareaDeAtender.new(_compradores(2, 500), _inventario())
	tarea.atender()
	tarea.atencion().cobrar()
	assert_int(tarea.diferencia_acumulada()).is_equal(500)
	tarea.atender()
	tarea.atencion().despachar_sin_vender()
	assert_int(tarea.diferencia_acumulada()).is_equal(500)


func test_la_diferencia_acumulada_conserva_los_signos() -> void:  # 013-AC7
	# Uno paga 500 de más y el otro 500 de menos: con un `abs()` en el camino esto daría 1000.
	var compradores := _compradores(1, 500)
	compradores.append_array(_compradores(1, -500))
	var tarea := TareaDeAtender.new(compradores, _inventario())
	for _comprador in compradores:
		tarea.atender()
		tarea.atencion().cobrar()
	assert_int(tarea.diferencia_acumulada()).is_equal(0)


func test_la_tarea_se_arma_con_uno_solo_y_funciona_igual() -> void:  # 013-AC8
	var tarea := TareaDeAtender.new(_compradores(1), _inventario())
	tarea.atender()
	tarea.atencion().despachar_sin_vender()
	assert_bool(tarea.completada()).is_true()
	assert_int(tarea.despachados()).is_equal(1)


func test_la_tarea_no_nombra_cuantos_compradores_pide_la_jornada() -> void:  # 013-AC8
	# Sin esto, un test no se podría armar con tres, y el balance de la ventanilla quedaría
	# atado a la aritmética de la tarea: mover el número rompería casos que no hablan de él.
	var texto := FileAccess.get_file_as_string(TAREA)
	assert_str(texto).is_not_empty()
	(
		assert_bool(texto.contains("COMPRADORES_POR_JORNADA"))
		. override_failure_message("`tarea_de_atender.gd` nombra la constante del balance")
		. is_false()
	)


func test_en_la_ventanilla_esta_el_que_llego_y_todavia_no_se_despacho() -> void:  # 013-AC6
	# Es la pregunta con la que la ventanilla decide si sigue con el que está o llama al
	# siguiente. Si contestara al despachado, cerrar y reabrir el panel llamaría a uno de más y
	# el último se iría sin atender: la obligatoria quedaría imposible sin un solo error.
	var tarea := TareaDeAtender.new(_compradores(2), _inventario())
	assert_object(tarea.en_ventanilla()).is_null()
	var primero := tarea.atender()
	assert_object(tarea.en_ventanilla()).is_same(primero)
	tarea.atencion().despachar_sin_vender()
	assert_object(tarea.en_ventanilla()).is_null()
