extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/programa_de_tickets.tscn")


func test_siempre_presenta_tres_filas_y_repinta_sin_restos() -> void:  # AC-CTR-021, AC-CTR-023
	var vista: ProgramaDeTickets = auto_free(ESCENA.instantiate())
	add_child(vista)
	assert_bool(vista.visible).is_false()
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	var coracola := Catalogo.de(Producto.Id.CORACOLA)
	vista.mostrar(_automatico([marolini, marolini, coracola]))
	assert_bool(vista.visible).is_true()
	assert_int(vista.filas.size()).is_equal(GeneradorDeTickets.RENGLONES)
	for indice in vista.filas.size():
		assert_str(vista.filas[indice].text).is_equal(
			[marolini.nombre, marolini.nombre, coracola.nombre][indice]
		)
		assert_bool(vista.filas[indice].is_visible_in_tree()).is_true()
	vista.mostrar(_automatico([coracola]))
	assert_str(vista.filas[0].text).is_equal(coracola.nombre)
	for indice in range(1, vista.filas.size()):
		assert_str(vista.filas[indice].text).is_empty()
		assert_bool(vista.filas[indice].is_visible_in_tree()).is_true()
	vista.mostrar(_automatico([]))
	for fila in vista.filas:
		assert_str(fila.text).is_empty()
	assert_str(vista.salida.text).is_equal(LienzoDeManada.TEXTO_DE_SALIDA)
	vista.ocultar()
	assert_bool(vista.visible).is_false()


func test_cada_boton_publica_su_pedido_y_un_sonido() -> void:  # AC-CTR-023, AC-CTR-024
	var vista: ProgramaDeTickets = auto_free(ESCENA.instantiate())
	add_child(vista)
	var pedidos: Array[String] = []
	vista.boton_pulsado.connect(func() -> void: pedidos.append("boton"))
	vista.borrado_pedido.connect(func() -> void: pedidos.append("borrar"))
	vista.impresion_pedida.connect(func() -> void: pedidos.append("imprimir"))
	vista.mostrar(_automatico([]))
	vista.borrar.pressed.emit()
	vista.imprimir.pressed.emit()
	assert_array(pedidos).contains_exactly(["boton", "borrar", "boton", "imprimir"])


func test_el_lienzo_mantiene_los_tres_renglones_y_botones_al_redimensionar() -> void:  # AC-PLY-072
	var vista: ProgramaDeTickets = auto_free(ESCENA.instantiate())
	add_child(vista)
	vista.mostrar(_automatico([Catalogo.de(Producto.Id.MAROLINI)]))
	for pantalla: Vector2 in [Vector2(1920, 1080), Vector2(1280, 720)]:
		LienzoDeManada.ajustar(vista.marco, pantalla)
		for control: Control in [
			vista.filas[0], vista.filas[1], vista.filas[2], vista.borrar, vista.imprimir
		]:
			var rectangulo := control.get_global_rect()
			assert_bool(Rect2(Vector2.ZERO, pantalla).encloses(rectangulo)).is_true()


func _automatico(productos: Array[Producto]) -> GeneradorDeTickets:
	var generador := GeneradorDeTickets.new()
	for producto in productos:
		generador.anotar(UnidadDeProducto.new(producto))
	return generador


func test_los_selectores_manuales_ofrecen_vacio_y_catalogo_ordenado() -> void:  # AC-CTR-030
	var vista: ProgramaDeTickets = auto_free(ESCENA.instantiate())
	add_child(vista)
	vista.mostrar(GeneradorDeTickets.para_la_jornada(3))
	assert_int(vista.selectores.size()).is_equal(GeneradorDeTickets.RENGLONES)
	var catalogo := Catalogo.todos()
	for selector in vista.selectores:
		assert_bool(selector.is_visible_in_tree()).is_true()
		assert_int(selector.item_count).is_equal(catalogo.size() + 1)
		assert_str(selector.get_item_text(0)).is_empty()
		for indice in catalogo.size():
			assert_str(selector.get_item_text(indice + 1)).is_equal(catalogo[indice].nombre)
	for fila in vista.filas:
		assert_bool(fila.is_visible_in_tree()).is_false()
	vista.mostrar(GeneradorDeTickets.para_la_jornada(2))
	for selector in vista.selectores:
		assert_bool(selector.is_visible_in_tree()).is_false()
	for fila in vista.filas:
		assert_bool(fila.is_visible_in_tree()).is_true()


func test_solo_dos_o_tres_conserva_su_posicion_al_repintar() -> void:  # AC-CTR-028, AC-CTR-030
	var vista: ProgramaDeTickets = auto_free(ESCENA.instantiate())
	add_child(vista)
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	var opcion := _opcion_de(marolini)
	assert_int(opcion).is_greater(0)
	var elecciones: Array[int] = []
	vista.eleccion_pedida.connect(
		func(indice: int, _producto: Producto) -> void: elecciones.append(indice)
	)
	for elegido: int in [1, 2]:
		var generador := GeneradorDeTickets.para_la_jornada(3)
		generador.elegir(elegido, marolini)
		for _repintado in 2:
			vista.mostrar(generador)
			for indice in vista.selectores.size():
				assert_int(vista.selectores[indice].selected).is_equal(
					opcion if indice == elegido else 0
				)
		assert_array(elecciones).is_empty()
		var papel := generador.imprimir()
		assert_object(papel).is_not_null()
		vista.ocultar()
		vista.mostrar(generador)
		assert_int(vista.selectores[elegido].selected).is_equal(opcion)
		if papel != null:
			assert_array(papel.renglones()).contains_exactly([marolini])
		generador.borrar()
		vista.mostrar(generador)
		for selector in vista.selectores:
			assert_int(selector.selected).is_equal(0)
		assert_array(elecciones).is_empty()


func test_seleccionar_publica_el_indice_y_producto_y_vacio_publica_null() -> void:  # AC-CTR-030
	var vista: ProgramaDeTickets = auto_free(ESCENA.instantiate())
	add_child(vista)
	var generador := GeneradorDeTickets.para_la_jornada(3)
	vista.mostrar(generador)
	var indices: Array[int] = []
	var productos: Array[Producto] = []
	vista.eleccion_pedida.connect(
		func(indice: int, producto: Producto) -> void:
			indices.append(indice)
			productos.append(producto)
			generador.elegir(indice, producto)
			vista.mostrar(generador)
	)
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	var opcion := _opcion_de(marolini)
	assert_int(opcion).is_greater(0)
	vista.selectores[2].item_selected.emit(opcion)
	assert_array(indices).contains_exactly([2])
	assert_int(productos.size()).is_equal(1)
	if productos.size() == 1 and productos[0] != null:
		assert_int(productos[0].id).is_equal(marolini.id)
	assert_object(generador.en_el_renglon(0)).is_null()
	assert_object(generador.en_el_renglon(1)).is_null()
	var elegido := generador.en_el_renglon(2)
	assert_object(elegido).is_not_null()
	if elegido != null:
		assert_int(elegido.id).is_equal(marolini.id)
	vista.selectores[2].item_selected.emit(0)
	assert_array(indices).contains_exactly([2, 2])
	assert_int(productos.size()).is_equal(2)
	if productos.size() == 2:
		assert_object(productos[0]).is_not_null()
		if productos[0] != null:
			assert_int(productos[0].id).is_equal(marolini.id)
		assert_object(productos[1]).is_null()
	assert_object(generador.en_el_renglon(2)).is_null()


func _opcion_de(producto: Producto) -> int:
	var catalogo := Catalogo.todos()
	for indice in catalogo.size():
		if catalogo[indice].id == producto.id:
			return indice + 1
	return -1
