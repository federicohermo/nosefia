extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/programa_de_tickets.tscn")


func test_siempre_presenta_tres_filas_y_repinta_sin_restos() -> void:  # AC-CTR-021, AC-CTR-023
	var vista: ProgramaDeTickets = auto_free(ESCENA.instantiate())
	add_child(vista)
	assert_bool(vista.visible).is_false()
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	var coracola := Catalogo.de(Producto.Id.CORACOLA)
	vista.mostrar([marolini, marolini, coracola])
	assert_bool(vista.visible).is_true()
	assert_int(vista.filas.size()).is_equal(GeneradorDeTickets.RENGLONES)
	for indice in vista.filas.size():
		assert_str(vista.filas[indice].text).is_equal(
			[marolini.nombre, marolini.nombre, coracola.nombre][indice]
		)
		assert_bool(vista.filas[indice].is_visible_in_tree()).is_true()
	vista.mostrar([coracola])
	assert_str(vista.filas[0].text).is_equal(coracola.nombre)
	for indice in range(1, vista.filas.size()):
		assert_str(vista.filas[indice].text).is_empty()
		assert_bool(vista.filas[indice].is_visible_in_tree()).is_true()
	vista.mostrar([])
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
	vista.mostrar([])
	vista.borrar.pressed.emit()
	vista.imprimir.pressed.emit()
	assert_array(pedidos).contains_exactly(["boton", "borrar", "boton", "imprimir"])


func test_el_lienzo_mantiene_los_tres_renglones_y_botones_al_redimensionar() -> void:  # AC-PLY-072
	var vista: ProgramaDeTickets = auto_free(ESCENA.instantiate())
	add_child(vista)
	vista.mostrar([Catalogo.de(Producto.Id.MAROLINI)])
	for pantalla: Vector2 in [Vector2(1920, 1080), Vector2(1280, 720)]:
		LienzoDeManada.ajustar(vista.marco, pantalla)
		for control: Control in [
			vista.filas[0], vista.filas[1], vista.filas[2], vista.borrar, vista.imprimir
		]:
			var rectangulo := control.get_global_rect()
			assert_bool(Rect2(Vector2.ZERO, pantalla).encloses(rectangulo)).is_true()
