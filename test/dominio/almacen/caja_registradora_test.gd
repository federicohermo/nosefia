## La mitad *registrar* de la caja: qué productos hay que pasar hoy y cuáles ya se pasaron.
##
## **Los del día son tres y no los seis del catálogo**, y es lo que hace de la caja una tarea y
## no un panel: con los seis, registrar sería recorrer la lista entera y no habría nada que
## elegir.
extends GdUnitTestSuite


func _del_dia() -> Array[Producto]:
	return CajaRegistradora.productos_del_dia()


func _inventario() -> Inventario:
	return Apertura.inventario_de_la_jornada()


func _caja() -> CajaRegistradora:
	return CajaRegistradora.new(_inventario(), _del_dia())


func test_los_productos_del_dia_son_menos_que_el_catalogo_entero() -> void:  # 009-AC6
	assert_int(CajaRegistradora.PRODUCTOS_DEL_DIA.size()).is_greater(0)
	(
		assert_int(CajaRegistradora.PRODUCTOS_DEL_DIA.size())
		. override_failure_message("registrar el catálogo entero no es elegir nada")
		. is_less(Catalogo.todos().size())
	)


func test_los_productos_del_dia_existen_en_el_catalogo() -> void:  # 009-AC6
	# Un `id` sin fila resuelve `null`, y un `null` en la lista dejaría una tarea imposible de
	# terminar: el jugador registraría todo lo que puede tocar y la caja seguiría diciendo que no.
	assert_int(_del_dia().size()).is_equal(CajaRegistradora.PRODUCTOS_DEL_DIA.size())
	for producto in _del_dia():
		assert_object(producto).is_not_null()


func test_registrar_devuelve_true_la_primera_vez_y_false_la_segunda() -> void:  # 009-AC6
	var caja := _caja()
	var primero := _del_dia()[0]
	assert_bool(caja.registrar(primero)).is_true()
	assert_bool(caja.registrar(primero)).is_false()
	assert_int(caja.registrados()).is_equal(1)


func test_registrar_indexa_por_id_y_no_por_instancia() -> void:  # 009-AC6
	# `Catalogo.de()` construye un producto nuevo en cada llamada, así que dos yerbas son objetos
	# distintos: por instancia, pasar dos veces la misma yerba contaría dos y la tarea se
	# cumpliría con un solo producto.
	var caja := _caja()
	var primero := _del_dia()[0]
	assert_bool(caja.registrar(primero)).is_true()
	assert_bool(caja.registrar(Catalogo.de(primero.id))).is_false()
	assert_int(caja.registrados()).is_equal(1)


func test_un_producto_ajeno_al_dia_no_se_registra() -> void:  # 009-AC6
	var caja := _caja()
	var ajeno: Producto = null
	for producto in Catalogo.todos():
		if not CajaRegistradora.PRODUCTOS_DEL_DIA.has(producto.id):
			ajeno = producto
			break
	assert_object(ajeno).is_not_null()
	assert_bool(caja.registrar(ajeno)).is_false()
	assert_int(caja.registrados()).is_equal(0)


func test_un_producto_nulo_se_rechaza_en_vez_de_reventar() -> void:  # 009-AC6
	assert_bool(_caja().registrar(null)).is_false()


func test_la_caja_se_completa_recien_con_el_ultimo_del_dia() -> void:  # 009-AC7
	var caja := _caja()
	var del_dia := _del_dia()
	for indice in range(del_dia.size() - 1):
		caja.registrar(del_dia[indice])
		(
			assert_bool(caja.completada())
			. override_failure_message(
				"la caja se completó con %d de %d" % [indice + 1, del_dia.size()]
			)
			. is_false()
		)
	caja.registrar(del_dia[-1])
	assert_bool(caja.completada()).is_true()


func test_los_faltantes_son_los_mismos_que_dice_el_inventario() -> void:  # 009-AC8
	# Se compara contra `Inventario.faltantes()` y no contra una cuenta propia: el umbral de
	# reposición es del 005, y copiarlo acá daría dos listas que se separan sin que nada avise.
	var inventario := _inventario()
	var caja := CajaRegistradora.new(inventario, _del_dia())
	var del_inventario := inventario.faltantes()
	var de_la_caja := caja.faltantes()
	assert_int(de_la_caja.size()).is_equal(del_inventario.size())
	for indice in range(del_inventario.size()):
		assert_int(de_la_caja[indice].id).is_equal(del_inventario[indice].id)


func test_reponer_cambia_lo_que_la_caja_lista_como_faltante() -> void:  # 009-AC8
	# La caja pregunta, no guarda: si llevara su propia lista, el jugador repondría la góndola y
	# la pantalla seguiría pidiéndole lo mismo.
	var inventario := _inventario()
	var caja := CajaRegistradora.new(inventario, _del_dia())
	var antes := caja.faltantes().size()
	var yerba := Catalogo.de(Producto.Id.YERBA)
	inventario.mover(
		yerba, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, yerba.umbral
	)
	assert_int(caja.faltantes().size()).is_equal(antes - 1)
