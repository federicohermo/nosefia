extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_de_computadora.tscn")

const IMAGEN := 0
const MARCA := 1
const RUBRO := 2
const PRECIO := 3
const RESTAR := 4
const UNIDADES := 5
const SUMAR := 6
const TOTAL := 7


func _planilla(pantalla: PantallaDeComputadora) -> RegistroDeVentas:
	var atender := TareaDeAtender.new(
		[], Apertura.inventario_de_la_jornada(1, [], {}, {}, RandomNumberGenerator.new())
	)
	var registro := RegistroDeVentas.new(Catalogo.todos(), atender)
	var app := pantalla.caja()
	app.suma_pedida.connect(func(producto: Producto) -> void: registro.sumar(producto))
	app.resta_pedida.connect(func(producto: Producto) -> void: registro.restar(producto))
	app.mostrar(registro)
	return registro


func _fila_de(app: AppCaja, id: Producto.Id) -> Node:
	var indice := 0
	for producto in (app.get("_registro") as RegistroDeVentas).productos():
		if producto.id == id:
			return (app.get("_filas") as Container).get_child(indice).get_child(0)
		indice += 1
	return null


func _ancho_del_texto(etiqueta: Label) -> float:
	var fuente := etiqueta.get_theme_font(&"font")
	var tamano := etiqueta.get_theme_font_size(&"font_size")
	return fuente.get_string_size(etiqueta.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x


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
	var registro := _planilla(pantalla)
	var app := pantalla.caja()
	var filas: Container = app.get("_filas")
	assert_int(filas.get_child_count()).is_equal(Catalogo.todos().size())
	for panel: Node in filas.get_children():
		var imagen: TextureRect = panel.get_child(0).get_child(IMAGEN).get_child(0)
		assert_object(imagen.texture).is_not_null()
	var producto: Producto = registro.productos()[0]
	var primera := filas.get_child(0).get_child(0)
	assert_str((primera.get_child(MARCA) as Label).text).is_equal(producto.nombre.to_upper())
	assert_str((primera.get_child(RUBRO) as Label).text).is_equal(
		Catalogo.rubro_de(producto.id).to_upper()
	)
	assert_str((primera.get_child(PRECIO) as Label).text).is_equal(
		AppCaja.texto_de_pesos(producto.precio)
	)
	for _vez in 3:
		(primera.get_child(SUMAR) as Button).pressed.emit()
	app.mostrar(registro)
	assert_str((primera.get_child(UNIDADES) as Label).text).is_equal("3")
	assert_str((primera.get_child(TOTAL) as Label).text).is_equal(
		AppCaja.texto_de_pesos(producto.precio * 3)
	)
	(primera.get_child(RESTAR) as Button).pressed.emit()
	app.mostrar(registro)
	assert_str((primera.get_child(UNIDADES) as Label).text).is_equal("2")
	assert_str((primera.get_child(TOTAL) as Label).text).is_equal(
		AppCaja.texto_de_pesos(producto.precio * 2)
	)
	assert_str((app.get("_total") as Label).text).is_equal(
		AppCaja.texto_de_pesos(producto.precio * 2)
	)
	await get_tree().process_frame


func test_el_encabezado_tiene_las_seis_columnas_en_orden() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var textos: Array[String] = []
	var anterior := -1
	for nombre: String in [
		"_columna_imagen",
		"_columna_marca",
		"_columna_producto",
		"_columna_precio",
		"_columna_vendido",
		"_columna_total",
	]:
		var columna: Label = pantalla.caja().get(nombre)
		textos.append(columna.text)
		assert_int(columna.get_index()).is_greater(anterior)
		anterior = columna.get_index()
	assert_array(textos).is_equal(
		["IMAGEN", "MARCA", "PRODUCTO", "PRECIO", "VENDIDO", "TOTAL"] as Array[String]
	)


func test_los_montos_llevan_signo_espacio_y_punto_de_miles() -> void:
	var esperados := {
		0: "$ 0",
		600: "$ 600",
		999: "$ 999",
		1000: "$ 1.000",
		10000: "$ 10.000",
		999999: "$ 999.999",
		1000000: "$ 1.000.000",
		1234567: "$ 1.234.567",
	}
	for monto: int in esperados:
		assert_str(AppCaja.texto_de_pesos(monto)).is_equal(esperados[monto])


func test_una_fila_en_el_tope_no_cambia_con_un_mas_rechazado() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var registro := _planilla(pantalla)
	var app := pantalla.caja()
	var fila := _fila_de(app, Producto.Id.FERNET_GOD)
	var fernet := Catalogo.de(Producto.Id.FERNET_GOD)
	var sumar: Button = fila.get_child(SUMAR)
	for _vez in RegistroDeVentas.TOPE_POR_FILA + 1:
		sumar.pressed.emit()
	app.mostrar(registro)
	assert_str((fila.get_child(UNIDADES) as Label).text).is_equal(
		str(RegistroDeVentas.TOPE_POR_FILA)
	)
	assert_str((fila.get_child(TOTAL) as Label).text).is_equal(
		AppCaja.texto_de_pesos(fernet.precio * RegistroDeVentas.TOPE_POR_FILA)
	)
	var sin_anotar := _fila_de(app, Producto.Id.ACTRONCITO)
	(sin_anotar.get_child(RESTAR) as Button).pressed.emit()
	app.mostrar(registro)
	assert_str((sin_anotar.get_child(UNIDADES) as Label).text).is_equal("0")
	assert_str((sin_anotar.get_child(TOTAL) as Label).text).is_equal(AppCaja.texto_de_pesos(0))


func test_el_total_de_la_noche_entra_entero_y_queda_bajo_la_columna_total() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	pantalla.mostrar()
	var registro := _planilla(pantalla)
	var app := pantalla.caja()
	for producto in registro.productos():
		for _vez in RegistroDeVentas.TOPE_POR_FILA:
			registro.sumar(producto)
	app.mostrar(registro)
	await get_tree().process_frame
	await get_tree().process_frame
	var total: Label = app.get("_total")
	assert_str(total.text).is_equal(AppCaja.texto_de_pesos(registro.total()))
	assert_int(total.text.count(".")).is_equal(2)
	assert_float(_ancho_del_texto(total)).is_less_equal(total.size.x)
	var escala := total.get_global_transform().get_scale().x
	var centro := total.get_global_rect().end.x - _ancho_del_texto(total) * escala / 2.0
	var columna: Label = app.get("_columna_total")
	var cabecera := columna.get_global_rect()
	assert_float(centro).is_between(cabecera.position.x, cabecera.end.x)


func test_el_total_de_la_fila_mas_larga_entra_entero_sin_margen_sobrante() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	pantalla.mostrar()
	var registro := _planilla(pantalla)
	for producto in registro.productos():
		for _vez in RegistroDeVentas.TOPE_POR_FILA:
			registro.sumar(producto)
	pantalla.caja().mostrar(registro)
	await get_tree().process_frame
	await get_tree().process_frame
	var mayor := 0.0
	for panel: Node in (pantalla.caja().get("_filas") as Container).get_children():
		var total := panel.get_child(0).get_child(TOTAL) as Label
		assert_float(_ancho_del_texto(total)).is_less_equal(total.size.x)
		mayor = maxf(mayor, _ancho_del_texto(total))
	assert_float(AppCaja.ANCHO_DEL_TOTAL).is_less_equal(mayor * 1.1)


func test_la_imagen_dibujada_ocupa_todo_el_ancho_de_su_columna_y_el_alto_de_la_fila() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	pantalla.mostrar()
	_planilla(pantalla)
	await get_tree().process_frame
	await get_tree().process_frame
	var app := pantalla.caja()
	var columna: Label = app.get("_columna_imagen")
	for panel: Control in (app.get("_filas") as Container).get_children():
		var imagen: TextureRect = panel.get_child(0).get_child(IMAGEN).get_child(0)
		assert_int(imagen.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		var lado := minf(
			imagen.size.x / imagen.texture.get_width(), imagen.size.y / imagen.texture.get_height()
		)
		assert_float(imagen.texture.get_width() * lado).is_equal_approx(columna.size.x, 1.0)
		assert_float(imagen.texture.get_height() * lado).is_equal_approx(panel.size.y, 1.0)


func test_la_marca_y_el_rubro_mas_largos_entran_en_su_columna_sin_puntos_suspensivos() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	pantalla.mostrar()
	_planilla(pantalla)
	await get_tree().process_frame
	await get_tree().process_frame
	for panel: Node in (pantalla.caja().get("_filas") as Container).get_children():
		for columna: int in [MARCA, RUBRO]:
			var etiqueta := panel.get_child(0).get_child(columna) as Label
			assert_float(_ancho_del_texto(etiqueta)).is_less_equal(etiqueta.size.x)


func test_cada_columna_del_encabezado_arranca_en_la_misma_x_que_las_de_las_filas() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	pantalla.mostrar()
	_planilla(pantalla)
	await get_tree().process_frame
	await get_tree().process_frame
	var app := pantalla.caja()
	var encabezados := {
		IMAGEN: "_columna_imagen",
		MARCA: "_columna_marca",
		RUBRO: "_columna_producto",
		PRECIO: "_columna_precio",
		RESTAR: "_columna_vendido",
		TOTAL: "_columna_total",
	}
	for panel: Node in (app.get("_filas") as Container).get_children():
		for indice: int in encabezados:
			var celda := panel.get_child(0).get_child(indice) as Control
			var encabezado: Label = app.get(encabezados[indice])
			assert_float(celda.get_global_rect().position.x).is_equal_approx(
				encabezado.get_global_rect().position.x, 1.0
			)


func test_ninguna_fila_es_mas_ancha_que_el_desplazamiento() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	pantalla.mostrar()
	_planilla(pantalla)
	await get_tree().process_frame
	await get_tree().process_frame
	var app := pantalla.caja()
	var desplazamiento: ScrollContainer = app.get("_scroll")
	var filas: Container = app.get("_filas")
	for fila: Control in filas.get_children():
		assert_float(fila.get_combined_minimum_size().x).is_less_equal(desplazamiento.size.x)
		assert_float(fila.size.x).is_less_equal(desplazamiento.size.x)


func test_reabrir_la_planilla_no_rehace_las_filas_ni_sube_el_desplazamiento() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	pantalla.mostrar()
	var registro := _planilla(pantalla)
	await get_tree().process_frame
	await get_tree().process_frame
	var app := pantalla.caja()
	var filas: Container = app.get("_filas")
	var primera := filas.get_child(0)
	var desplazamiento: ScrollContainer = app.get("_scroll")
	desplazamiento.scroll_vertical = 200
	app.mostrar(registro)
	assert_int(filas.get_child_count()).is_equal(Catalogo.todos().size())
	assert_object(filas.get_child(0)).is_same(primera)
	assert_int(desplazamiento.scroll_vertical).is_equal(200)


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
	var boton: Button = ultima.get_child(0).get_child(SUMAR)
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
	var sumar: Button = fila.get_child(SUMAR)
	var restar: Button = fila.get_child(RESTAR)
	sumar.pressed.emit()
	sumar.pressed.emit()
	restar.pressed.emit()
	assert_int(pulsados[0]).is_equal(3)
	sumar.disabled = true
	sumar.pressed.emit()
	assert_int(pulsados[0]).is_equal(3)
	await get_tree().process_frame
