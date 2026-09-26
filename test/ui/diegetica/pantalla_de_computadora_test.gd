extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_de_computadora.tscn")


func test_las_opciones_permanecen_visibles_y_el_titulo_indica_la_pantalla() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	pantalla.mostrar(Computadora.App.CAJA)
	var titulo: Label = pantalla.get("_titulo")
	var opciones: HBoxContainer = pantalla.get("_opciones")
	assert_object(opciones).is_not_null()
	if opciones == null:
		return
	assert_int(opciones.get_child_count()).is_equal(2)
	var registro: Button = opciones.get_child(0)
	var notas: Button = opciones.get_child(1)
	assert_str(titulo.text).is_equal("/ REGISTRO:")
	assert_int(titulo.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var pedidos: Array[int] = []
	pantalla.app_pedida.connect(func(app: int) -> void: pedidos.append(app))
	pantalla.app_pedida.connect(pantalla.cambiar_a)
	notas.pressed.emit()
	assert_bool(pantalla.notas().visible).is_true()
	assert_bool(pantalla.caja().visible).is_false()
	assert_str(titulo.text).is_equal("/ NOTAS:")
	assert_bool(registro.is_visible_in_tree()).is_true()
	assert_bool(notas.is_visible_in_tree()).is_true()
	assert_bool(notas.button_pressed).is_true()
	registro.pressed.emit()
	assert_bool(pantalla.caja().visible).is_true()
	assert_bool(pantalla.notas().visible).is_false()
	assert_str(titulo.text).is_equal("/ REGISTRO:")
	assert_bool(registro.is_visible_in_tree()).is_true()
	assert_bool(notas.is_visible_in_tree()).is_true()
	assert_bool(registro.button_pressed).is_true()
	assert_bool(notas.button_pressed).is_false()
	assert_array(pedidos).is_equal([Computadora.App.NOTAS, Computadora.App.CAJA])


func test_la_planilla_muestra_cada_producto_y_sigue_a_los_gestos() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var atender := TareaDeAtender.new([], Apertura.inventario_de_la_jornada())
	var registro := RegistroDeVentas.new(Catalogo.todos(), atender)
	var app := pantalla.caja()
	app.suma_pedida.connect(func(producto: Producto) -> void: registro.sumar(producto))
	app.resta_pedida.connect(func(producto: Producto) -> void: registro.restar(producto))
	app.mostrar(registro)
	var filas: Container = app.get("_filas")
	assert_int(filas.get_child_count()).is_equal(Catalogo.todos().size())
	for fila: Node in filas.get_children():
		var imagen: TextureRect = fila.get_child(0)
		assert_object(imagen.texture).is_not_null()
	var primera := filas.get_child(0)
	(primera.get_child(5) as Button).pressed.emit()
	(primera.get_child(5) as Button).pressed.emit()
	(primera.get_child(3) as Button).pressed.emit()
	app.mostrar(registro)
	var producto: Producto = registro.productos()[0]
	assert_str((primera.get_child(1) as Label).text).is_equal(producto.nombre.to_upper())
	assert_str((primera.get_child(4) as Label).text).is_equal("01")
	assert_str((app.get("_total") as Label).text).is_equal("$%d" % producto.precio)
	await get_tree().process_frame


func test_todas_las_filas_se_alcanzan_con_la_rueda_dentro_de_la_pantalla() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	pantalla.mostrar(Computadora.App.CAJA)
	var atender := TareaDeAtender.new([], Apertura.inventario_de_la_jornada())
	var app := pantalla.caja()
	app.mostrar(RegistroDeVentas.new(Catalogo.todos(), atender))
	await get_tree().process_frame
	await get_tree().process_frame
	var desplazamiento: ScrollContainer = app.get_node("Desplazamiento")
	var marco: Control = pantalla.get("_marco")
	assert_bool(marco.get_global_rect().encloses(desplazamiento.get_global_rect())).is_true()
	var barra := desplazamiento.get_v_scroll_bar()
	var ultima: Control = app.get("_filas").get_children().back()
	assert_float(barra.max_value).is_greater_equal(ultima.position.y + ultima.size.y)
	var boton: Button = ultima.get_child(5)
	assert_int(boton.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_DOWN
	rueda.pressed = true
	rueda.position = desplazamiento.get_global_rect().get_center()
	rueda.global_position = rueda.position
	for vez in Catalogo.todos().size() * 4:
		get_viewport().push_input(rueda)
	assert_float(barra.value + barra.page).is_equal_approx(barra.max_value, 1.0)


func test_anotar_limpia_solo_si_el_cuaderno_acepta_y_muestra_la_nota_nueva() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var app := pantalla.notas()
	var cuaderno := Cuaderno.new()
	cuaderno.escribir("Anterior", "Ya estaba anotado.")
	app.mostrar(cuaderno.notas())
	app.escritura_pedida.connect(
		func(titulo: String, texto: String) -> void:
			if cuaderno.escribir(titulo, texto) != null:
				app.limpiar_campos()
				app.mostrar(cuaderno.notas())
	)
	var titulo: LineEdit = app.get("_campo_titulo")
	var cuerpo: TextEdit = app.get("_campo_texto")
	var anotar: Button = app.get("_anotar")
	cuerpo.text = "Texto que todavía no tiene título."
	anotar.pressed.emit()
	assert_str(cuerpo.text).is_equal("Texto que todavía no tiene título.")
	assert_int(cuaderno.notas().size()).is_equal(1)
	titulo.text = "Nota nueva"
	anotar.pressed.emit()
	assert_str(titulo.text).is_empty()
	assert_str(cuerpo.text).is_empty()
	assert_int(cuaderno.notas().size()).is_equal(2)
	assert_str((app.get("_detalle_titulo") as Label).text).is_equal("Nota nueva")
	assert_str((app.get("_detalle_texto") as Label).text).is_equal(
		"Texto que todavía no tiene título."
	)
	await get_tree().process_frame


func test_leer_notas_y_cambiar_de_app_conserva_el_borrador() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var app := pantalla.notas()
	var cuaderno := Cuaderno.new()
	cuaderno.escribir("Primera", "Lo que vi en el local.")
	cuaderno.escribir("Segunda", "Otra observación.")
	app.mostrar(cuaderno.notas())
	var titulo: LineEdit = app.get("_campo_titulo")
	var cuerpo: TextEdit = app.get("_campo_texto")
	titulo.text = "Sin terminar"
	cuerpo.text = "Todavía estoy escribiendo."
	var lista: Container = app.get("_lista")
	(lista.get_child(1) as Button).pressed.emit()
	var detalle: Label = app.get("_detalle_texto")
	assert_str(detalle.text).is_equal("Otra observación.")
	pantalla.cambiar_a(Computadora.App.CAJA)
	pantalla.cambiar_a(Computadora.App.NOTAS)
	app.mostrar(cuaderno.notas())
	assert_str(titulo.text).is_equal("Sin terminar")
	assert_str(cuerpo.text).is_equal("Todavía estoy escribiendo.")
	assert_int(cuaderno.notas().size()).is_equal(2)
	await get_tree().process_frame


func test_cada_click_en_un_boton_de_cualquier_app_emite_boton_pulsado() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var pulsados := [0]
	pantalla.boton_pulsado.connect(func() -> void: pulsados[0] += 1)
	var anotar: Button = pantalla.notas().get("_anotar")
	anotar.pressed.emit()
	assert_int(pulsados[0]).is_equal(1)
	# Los productos de la caja se agregan después de `_ready()`, al mostrarla.
	var caja := CajaRegistradora.new(
		Apertura.inventario_de_la_jornada(), CajaRegistradora.productos_del_dia()
	)
	pantalla.caja().mostrar(caja)
	var producto: Button = (pantalla.caja().get("_botones") as Container).get_child(0)
	producto.pressed.emit()
	producto.pressed.emit()
	assert_int(pulsados[0]).is_equal(3)
	producto.disabled = true
	producto.pressed.emit()
	assert_int(pulsados[0]).is_equal(3)
	await get_tree().process_frame
