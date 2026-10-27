extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/programa_de_tickets.tscn")
const RESOLUCIONES: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720),
]


func test_siempre_presenta_tres_filas_y_repinta_sin_restos() -> void:  # AC-CTR-021, AC-CTR-023
	var vista: ProgramaDeTickets = auto_free(ESCENA.instantiate())
	add_child(vista)
	assert_bool(vista.visible).is_false()
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	var coracola := Catalogo.de(Producto.Id.PURA_COLA)
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


func test_cada_renglon_ofrece_vacio_y_despues_el_catalogo_en_mayusculas() -> void:  # AC-CTR-030
	var vista := _abrir(6)
	assert_int(vista.selectores.size()).is_equal(GeneradorDeTickets.RENGLONES)
	var catalogo := Catalogo.todos()
	for selector in vista.selectores:
		assert_bool(selector.is_visible_in_tree()).is_true()
		var nombres := _nombres_de_la_lista(selector)
		assert_int(nombres.size()).is_equal(catalogo.size() + 1)
		for indice in catalogo.size():
			assert_str(nombres[indice + 1]).is_equal(catalogo[indice].nombre.to_upper())
		for producto in catalogo:
			assert_str(nombres[0]).is_not_equal(producto.nombre.to_upper())
	for fila in vista.filas:
		assert_bool(fila.is_visible_in_tree()).is_false()
	for flecha in vista.flechas:
		assert_bool(flecha.is_visible_in_tree()).is_false()
	vista.mostrar(GeneradorDeTickets.para_la_jornada(5))
	for selector in vista.selectores:
		assert_bool(selector.is_visible_in_tree()).is_false()
	for fila in vista.filas:
		assert_bool(fila.is_visible_in_tree()).is_true()
	for flecha in vista.flechas:
		assert_bool(flecha.is_visible_in_tree()).is_true()


func test_solo_dos_o_tres_conserva_su_posicion_al_repintar() -> void:  # AC-CTR-028, AC-CTR-030
	var vista := _abrir(6)
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	var elecciones: Array[int] = []
	vista.eleccion_pedida.connect(
		func(indice: int, _producto: Producto) -> void: elecciones.append(indice)
	)
	for elegido: int in [1, 2]:
		var generador := GeneradorDeTickets.para_la_jornada(6)
		generador.elegir(elegido, marolini)
		for _repintado in 2:
			vista.mostrar(generador)
			for indice in vista.selectores.size():
				_afirmar_producto(vista.selectores[indice], marolini if indice == elegido else null)
		assert_array(elecciones).is_empty()
		var papel := generador.imprimir()
		assert_object(papel).is_not_null()
		vista.ocultar()
		vista.mostrar(generador)
		_afirmar_producto(vista.selectores[elegido], marolini)
		if papel != null:
			assert_array(papel.renglones()).contains_exactly([marolini])
		generador.borrar()
		vista.mostrar(generador)
		for selector in vista.selectores:
			_afirmar_producto(selector, null)
		assert_array(elecciones).is_empty()


func test_elegir_un_producto_o_vacio_publica_la_eleccion() -> void:  # AC-CTR-030
	var vista := _abrir(6)
	var generador := GeneradorDeTickets.para_la_jornada(6)
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
	var selector := vista.selectores[2]
	_boton(selector, "Cabecera").pressed.emit()
	assert_bool(selector.esta_abierta()).is_true()
	_botones_de_la_lista(selector)[1 + _posicion_en_el_catalogo(marolini)].pressed.emit()
	assert_array(indices).contains_exactly([2])
	assert_bool(selector.esta_abierta()).is_false()
	assert_object(generador.en_el_renglon(0)).is_null()
	assert_object(generador.en_el_renglon(1)).is_null()
	var elegido := generador.en_el_renglon(2)
	assert_object(elegido).is_not_null()
	if elegido != null:
		assert_int(elegido.id).is_equal(marolini.id)
	_afirmar_producto(selector, marolini)
	_boton(selector, "Cabecera").pressed.emit()
	_botones_de_la_lista(selector)[0].pressed.emit()
	assert_array(indices).contains_exactly([2, 2])
	assert_int(productos.size()).is_equal(2)
	if productos.size() == 2:
		assert_object(productos[1]).is_null()
	assert_object(generador.en_el_renglon(2)).is_null()
	assert_bool(selector.esta_abierta()).is_false()
	_afirmar_producto(selector, null)


func test_la_x_del_renglon_no_lo_vacia_y_abre_la_lista() -> void:
	var vista := _abrir(6)
	var marolini := Catalogo.de(Producto.Id.MAROLINI)
	var selector := vista.selectores[0]
	selector.mostrar_producto(marolini)
	var equis := selector.find_child("Equis", true, false) as Control
	var publicadas: Array[Producto] = []
	vista.eleccion_pedida.connect(
		func(_indice: int, producto: Producto) -> void: publicadas.append(producto)
	)
	_clic(selector, equis.get_global_transform_with_canvas() * (equis.size / 2.0))
	assert_bool(selector.esta_abierta()).is_true()
	assert_array(publicadas).is_empty()
	_afirmar_producto(selector, marolini)


func test_abrir_la_lista_de_un_renglon_cierra_la_de_otro() -> void:
	var vista := _abrir(6)
	_boton(vista.selectores[0], "Cabecera").pressed.emit()
	assert_bool(vista.selectores[0].esta_abierta()).is_true()
	_boton(vista.selectores[1], "Cabecera").pressed.emit()
	assert_bool(vista.selectores[0].esta_abierta()).is_false()
	assert_bool(vista.selectores[1].esta_abierta()).is_true()
	_boton(vista.selectores[1], "Cabecera").pressed.emit()
	assert_bool(vista.selectores[1].esta_abierta()).is_false()


func test_un_clic_izquierdo_afuera_cierra_la_lista_y_no_el_programa() -> void:  # AC-PLY-072
	var vista := _abrir(6)
	var selector := vista.selectores[0]
	_boton(selector, "Cabecera").pressed.emit()
	var lista := selector.find_child("Lista", true, false) as Control
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	clic.position = lista.get_global_transform_with_canvas() * Vector2(30.0, 30.0)
	selector.call("_input", clic)
	assert_bool(selector.esta_abierta()).is_true()
	clic.position = Vector2(-1000.0, -1000.0)
	selector.call("_input", clic)
	assert_bool(selector.esta_abierta()).is_false()
	assert_bool(vista.visible).is_true()
	_boton(selector, "Cabecera").pressed.emit()
	vista.ocultar()
	assert_bool(selector.esta_abierta()).is_false()


func test_el_clic_que_cierra_la_lista_no_activa_el_boton_de_debajo() -> void:  # AC-PLY-072
	var vista := _abrir(6)
	var selector := vista.selectores[0]
	var lista := selector.find_child("Lista", true, false) as Control
	var borrados: Array[bool] = []
	vista.borrado_pedido.connect(func() -> void: borrados.append(true))
	var arriba := vista.borrar.get_global_transform_with_canvas() * Vector2.ZERO
	var abajo := vista.borrar.get_global_transform_with_canvas() * vista.borrar.size
	var punto := Vector2((arriba.x + abajo.x) / 2.0, (_borde_inferior(lista) + abajo.y) / 2.0)
	_clic(vista, punto)
	assert_array(borrados).has_size(1)
	_boton(selector, "Cabecera").pressed.emit()
	assert_float(_borde_inferior(lista)).is_between(arriba.y, abajo.y)
	_clic(selector, punto)
	assert_bool(selector.esta_abierta()).is_false()
	assert_array(borrados).has_size(1)


func test_el_nombre_mas_largo_del_catalogo_entra_antes_de_la_x() -> void:
	var selector := _abrir(6).selectores[0]
	var nombre := selector.find_child("Nombre", true, false) as Label
	var equis := selector.find_child("Equis", true, false) as Control
	for producto in Catalogo.todos():
		selector.mostrar_producto(producto)
		assert_float(nombre.position.x + nombre.get_minimum_size().x).is_less_equal(
			equis.position.x
		)


func test_la_lista_completa_puede_recorrerse() -> void:
	var selector := _abrir(6).selectores[0]
	_boton(selector, "Cabecera").pressed.emit()
	var desplazamiento := selector.find_child("Desplazamiento", true, false) as ScrollContainer
	var items := selector.find_child("Items", true, false) as Control
	assert_float(items.get_combined_minimum_size().y).is_greater(desplazamiento.size.y)
	assert_int(desplazamiento.vertical_scroll_mode).is_not_equal(
		ScrollContainer.SCROLL_MODE_DISABLED
	)


func test_un_clic_sobre_cada_linea_visible_elige_su_producto() -> void:
	for desplazado: bool in [false, true]:
		for renglon in 3:
			var vista := _abrir_en_pantalla(6)
			var selector := vista.selectores[renglon]
			var elegidos: Array[Producto] = []
			selector.producto_elegido.connect(
				func(producto: Producto) -> void: elegidos.append(producto)
			)
			var lineas := await _abrir_la_lista(selector, desplazado)
			var recorte := selector.find_child("Desplazamiento", true, false) as Control
			var visibles := 0
			for indice in lineas.size():
				var punto: Variant = _punto_visible(lineas[indice], recorte)
				if punto == null:
					continue
				visibles += 1
				elegidos.clear()
				_clic(selector, punto)
				assert_array(elegidos).has_size(1)
				if elegidos.size() == 1:
					_afirmar_la_linea(lineas[indice], indice, elegidos[0])
				assert_bool(selector.esta_abierta()).is_false()
				_boton(selector, "Cabecera").pressed.emit()
				await await_idle_frame()
			assert_int(visibles).is_greater(1)


func test_cada_producto_visible_tiene_su_separador_en_cada_resolucion() -> void:
	for pantalla: Vector2i in RESOLUCIONES:
		for desplazado: bool in [false, true]:
			var vista := _abrir_en_pantalla(6, pantalla)
			var selector := vista.selectores[0]
			var lineas := await _abrir_la_lista(selector, desplazado)
			var recorte := _rectangulo_global(selector.find_child("Desplazamiento", true, false))
			var anterior := -1.0
			var visibles := 0
			for linea in lineas:
				var separador := _rectangulo_global(linea.find_child("Linea", false, false))
				if not recorte.encloses(separador):
					continue
				visibles += 1
				var contexto := "%s, desplazado: %s" % [pantalla, desplazado]
				(
					assert_int(_filas_de_pixeles(separador))
					. override_failure_message(contexto)
					. is_equal(1)
				)
				assert_float(separador.position.y).is_equal_approx(
					roundf(separador.position.y), 0.01
				)
				assert_float(separador.position.y).is_greater(anterior)
				assert_float(separador.position.y).is_greater_equal(
					_rectangulo_global(linea).position.y
				)
				assert_float(separador.end.y).is_less_equal(_rectangulo_global(linea).end.y + 0.01)
				anterior = separador.position.y
			assert_int(visibles).is_greater(1)


func _abrir(jornada: int) -> ProgramaDeTickets:
	var vista: ProgramaDeTickets = auto_free(ESCENA.instantiate())
	add_child(vista)
	vista.mostrar(GeneradorDeTickets.para_la_jornada(jornada))
	return vista


func _abrir_la_lista(selector: SelectorDeRenglon, desplazada: bool) -> Array[Button]:
	_boton(selector, "Cabecera").pressed.emit()
	await await_idle_frame()
	var desplazamiento := selector.find_child("Desplazamiento", true, false) as ScrollContainer
	if desplazada:
		desplazamiento.scroll_vertical = int(desplazamiento.get_v_scroll_bar().max_value / 2.0)
		await await_idle_frame()
	return _botones_de_la_lista(selector)


## Un punto del renglón que se ve de verdad, o `null` si el recorte lo esconde.
func _punto_visible(linea: Button, recorte: Control) -> Variant:
	var rectangulo := _rectangulo_global(linea)
	var visible_de_la_linea := rectangulo.intersection(_rectangulo_global(recorte))
	if visible_de_la_linea.size.y < rectangulo.size.y / 2.0:
		return null
	return visible_de_la_linea.get_center()


func _rectangulo_global(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _afirmar_la_linea(linea: Button, indice: int, elegido: Producto) -> void:
	if indice == 0:
		assert_object(elegido).is_null()
		return
	assert_object(elegido).is_not_null()
	if elegido != null:
		assert_str(linea.text).is_equal(Catalogo.de(elegido.id).nombre.to_upper())


## La ventana del test mide 64 píxeles: a esa escala el clic se redondea sobre otra línea.
func _abrir_en_pantalla(jornada: int, tamano: Vector2i = Vector2i(1920, 1080)) -> ProgramaDeTickets:
	var pantalla: SubViewport = auto_free(SubViewport.new())
	pantalla.size = tamano
	add_child(pantalla)
	var vista: ProgramaDeTickets = ESCENA.instantiate()
	pantalla.add_child(vista)
	vista.mostrar(GeneradorDeTickets.para_la_jornada(jornada))
	return vista


## Las filas de píxeles cuyo centro cae adentro del rectángulo: las que el motor pinta.
func _filas_de_pixeles(rectangulo: Rect2) -> int:
	return ceili(rectangulo.end.y - 0.5) - ceili(rectangulo.position.y - 0.5)


func _boton(selector: SelectorDeRenglon, nombre: String) -> Button:
	return selector.find_child(nombre, true, false) as Button


func _botones_de_la_lista(selector: SelectorDeRenglon) -> Array[Button]:
	var botones: Array[Button] = []
	for hijo in selector.find_child("Items", true, false).get_children():
		if hijo is Button:
			botones.append(hijo as Button)
	return botones


func _nombres_de_la_lista(selector: SelectorDeRenglon) -> Array[String]:
	var nombres: Array[String] = []
	for boton in _botones_de_la_lista(selector):
		nombres.append(boton.text)
	return nombres


func _borde_inferior(control: Control) -> float:
	return (control.get_global_transform_with_canvas() * control.size).y


func _clic(nodo: Node, posicion: Vector2) -> void:
	for presionado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.position = posicion
		evento.global_position = posicion
		evento.pressed = presionado
		nodo.get_viewport().push_input(evento)


func _posicion_en_el_catalogo(producto: Producto) -> int:
	var catalogo := Catalogo.todos()
	for indice in catalogo.size():
		if catalogo[indice].id == producto.id:
			return indice
	return -1


func _afirmar_producto(selector: SelectorDeRenglon, esperado: Producto) -> void:
	var elegido := selector.elegido()
	if esperado == null:
		assert_object(elegido).is_null()
		return
	assert_object(elegido).is_not_null()
	if elegido != null:
		assert_int(elegido.id).is_equal(esperado.id)
