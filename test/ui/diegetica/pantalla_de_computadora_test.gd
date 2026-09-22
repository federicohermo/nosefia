extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_de_computadora.tscn")


func test_la_navegacion_ofrece_registro_y_notas_sin_chats() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	pantalla.mostrar(Computadora.App.CAJA)
	var pestanas: HBoxContainer = pantalla.get("_pestanas")
	assert_int(pestanas.get_child_count()).is_equal(2)
	var pedidos: Array[int] = []
	pantalla.app_pedida.connect(func(app: int) -> void: pedidos.append(app))
	for boton: Button in pestanas.get_children():
		boton.pressed.emit()
	assert_array(pedidos).is_equal([Computadora.App.CAJA, Computadora.App.NOTAS])


func test_registrar_conserva_el_producto_y_refleja_el_estado_real() -> void:
	var pantalla: PantallaDeComputadora = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var productos := CajaRegistradora.productos_del_dia()
	var caja := CajaRegistradora.new(Apertura.inventario_de_la_jornada(), productos)
	var app := pantalla.caja()
	app.registro_pedido.connect(func(producto: Producto) -> void: caja.registrar(producto))
	app.mostrar(caja)
	var botones: Container = app.get("_botones")
	var boton: Button = botones.get_child(0)
	boton.pressed.emit()
	app.mostrar(caja)
	assert_bool(caja.esta_registrado(productos[0])).is_true()
	assert_int(caja.registrados()).is_equal(1)
	assert_bool((botones.get_child(0) as Button).disabled).is_true()
	assert_bool((botones.get_child(1) as Button).disabled).is_false()
	await get_tree().process_frame


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
