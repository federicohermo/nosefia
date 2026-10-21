extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_de_computadora.tscn")


func test_el_bloqueo_deshabilita_ambos_botones_y_persiste_al_reabrir() -> void:  # AC-SHF-040
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var registro := RegistroDeVentas.new(
		Catalogo.todos(), TareaDeAtender.new([], Inventario.new([]))
	)
	var app := pantalla.caja()
	app.mostrar(registro)
	pantalla.mostrar()
	var fila := (app.get("_filas") as Container).get_child(0).get_child(0)
	var sumar: Button = fila.get_child(5)
	var restar: Button = fila.get_child(3)
	assert_bool(sumar.disabled).is_false()
	assert_bool(restar.disabled).is_false()
	registro.bloquear()
	app.mostrar(registro)
	assert_bool(sumar.disabled).is_true()
	assert_bool(restar.disabled).is_true()
	pantalla.ocultar()
	pantalla.mostrar()
	app.mostrar(registro)
	assert_bool(sumar.disabled).is_true()
	assert_bool(restar.disabled).is_true()
	var scroll: ScrollContainer = app.get("_scroll")
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	assert_int(scroll.scroll_vertical).is_greater(0)
	var nuevo := RegistroDeVentas.new(Catalogo.todos(), TareaDeAtender.new([], Inventario.new([])))
	app.mostrar(nuevo)
	for panel in (app.get("_filas") as Container).get_children():
		assert_bool((panel.get_child(0).get_child(3) as Button).disabled).is_false()
		assert_bool((panel.get_child(0).get_child(5) as Button).disabled).is_false()
	await get_tree().process_frame


func test_abrir_la_terminal_muestra_el_registro_y_cerrar_la_oculta() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	assert_bool(pantalla.visible).is_false()
	pantalla.mostrar()
	var titulo: Label = pantalla.get("_titulo")
	assert_bool(pantalla.visible).is_true()
	assert_bool(pantalla.caja().is_visible_in_tree()).is_true()
	assert_str(titulo.text).contains("REGISTRO")
	assert_int(titulo.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	pantalla.ocultar()
	assert_bool(pantalla.visible).is_false()
	pantalla.mostrar()
	assert_bool(pantalla.caja().is_visible_in_tree()).is_true()


func test_la_planilla_muestra_cada_producto_y_sigue_a_los_gestos() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var atender := TareaDeAtender.new(
		[], Apertura.inventario_de_la_jornada(1, [], {}, {}, RandomNumberGenerator.new())
	)
	var registro := RegistroDeVentas.new(Catalogo.todos(), atender)
	var app := pantalla.caja()
	app.suma_pedida.connect(func(producto: Producto) -> void: registro.sumar(producto))
	app.resta_pedida.connect(func(producto: Producto) -> void: registro.restar(producto))
	app.mostrar(registro)
	var filas: Container = app.get("_filas")
	assert_int(filas.get_child_count()).is_equal(Catalogo.todos().size())
	for panel: Node in filas.get_children():
		var imagen: TextureRect = panel.get_child(0).get_child(0).get_child(0)
		assert_object(imagen.texture).is_not_null()
	var primera := filas.get_child(0).get_child(0)
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
	pantalla.mostrar()
	var atender := TareaDeAtender.new(
		[], Apertura.inventario_de_la_jornada(1, [], {}, {}, RandomNumberGenerator.new())
	)
	var app := pantalla.caja()
	app.mostrar(RegistroDeVentas.new(Catalogo.todos(), atender))
	await get_tree().process_frame
	await get_tree().process_frame
	var desplazamiento: ScrollContainer = app.get("_scroll")
	var marco: Control = pantalla.get("_marco")
	assert_bool(marco.get_global_rect().encloses(desplazamiento.get_global_rect())).is_true()
	var barra := desplazamiento.get_v_scroll_bar()
	var ultima: Control = app.get("_filas").get_children().back()
	assert_float(barra.max_value).is_greater_equal(ultima.position.y + ultima.size.y)
	var boton: Button = ultima.get_child(0).get_child(5)
	assert_bool(boton.mouse_force_pass_scroll_events).is_true()
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_DOWN
	rueda.pressed = true
	rueda.position = desplazamiento.get_global_rect().get_center()
	rueda.global_position = rueda.position
	for vez in Catalogo.todos().size() * 4:
		get_viewport().push_input(rueda)
	assert_float(barra.value + barra.page).is_equal_approx(barra.max_value, 1.0)


func test_cada_click_habilitado_del_registro_emite_boton_pulsado() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var pulsados := [0]
	pantalla.boton_pulsado.connect(func() -> void: pulsados[0] += 1)
	# Las filas de la planilla se agregan después de `_ready()`, al mostrarla.
	var atender := TareaDeAtender.new(
		[], Apertura.inventario_de_la_jornada(1, [], {}, {}, RandomNumberGenerator.new())
	)
	pantalla.caja().mostrar(RegistroDeVentas.new(Catalogo.todos(), atender))
	var fila := (pantalla.caja().get("_filas") as Container).get_child(0).get_child(0)
	var sumar: Button = fila.get_child(5)
	var restar: Button = fila.get_child(3)
	sumar.pressed.emit()
	sumar.pressed.emit()
	restar.pressed.emit()
	assert_int(pulsados[0]).is_equal(3)
	sumar.disabled = true
	sumar.pressed.emit()
	assert_int(pulsados[0]).is_equal(3)
	await get_tree().process_frame
