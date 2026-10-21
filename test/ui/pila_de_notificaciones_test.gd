extends GdUnitTestSuite

const ESCENA := "res://src/ui/pila_de_notificaciones.tscn"
const COMPUTADORA := "res://src/ui/diegetica/pantalla_de_computadora.tscn"


func after_test() -> void:
	get_tree().paused = false


func _pila() -> PilaDeNotificaciones:
	var pila: PilaDeNotificaciones = auto_free(load(ESCENA).instantiate())
	add_child(pila)
	return pila


func test_tareas_terminadas_entra_completo_y_deja_pasarlo_al_clic() -> void:  # AC-NTF-027
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var pila: PilaDeNotificaciones = load(ESCENA).instantiate()
	viewport.add_child(pila)
	pila.set_process(false)
	pila.avisar_pista()
	pila.avisar_tareas_terminadas()
	assert_str(_textos(pila)[0]).is_equal("YA TERMINASTE TUS TAREAS Y PODÉS IRTE")
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		viewport.size = tamano
		await get_tree().process_frame
		await get_tree().process_frame
		var carteles := pila.get_node("Marco/Pila").get_children()
		var cartel: PanelContainer = carteles[0]
		var fila: HBoxContainer = cartel.get_child(0)
		var simbolo: TextureRect = fila.get_child(0)
		var texto: Label = fila.get_child(1)
		assert_int(texto.get_line_count()).is_equal(1)
		assert_float(texto.size.x).is_greater_equal(texto.get_minimum_size().x)
		(
			assert_bool(Rect2(Vector2.ZERO, Vector2(tamano)).encloses(cartel.get_global_rect()))
			. is_true()
		)
		assert_float(cartel.size.x).is_equal_approx(
			fila.get_combined_minimum_size().x + pila._estilo.get_minimum_size().x, 1.0
		)
		assert_float(cartel.get_global_rect().end.x).is_equal_approx(
			(carteles[1] as Control).get_global_rect().end.x, 0.1
		)
		assert_float(simbolo.get_global_rect().end.x).is_less(texto.get_global_rect().position.x)
		assert_object(texto.get_theme_font("font")).is_same(pila._marco.get_theme_font("font"))
		for control: Control in pila.find_children("*", "Control", true, false):
			assert_int(control.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_tareas_terminadas_conserva_su_resto_en_pausa() -> void:  # AC-NTF-026
	var pila := _pila()
	pila.set_process(false)
	pila.avisar_tareas_terminadas()
	pila._process(2.0)
	get_tree().paused = true
	await get_tree().process_frame
	assert_bool(pila.can_process()).is_false()
	assert_array(_textos(pila)).has_size(1)
	get_tree().paused = false
	pila._process(0.9)
	assert_array(_textos(pila)).has_size(1)
	pila._process(0.1)
	assert_array(_textos(pila)).is_empty()


func test_la_salida_tiene_el_texto_y_simbolo_de_figma_y_respeta_pausa() -> void:  # AC-NTF-011
	var pila := _pila()
	pila.avisar_salida(Compradores.de_la_jornada(4)[0])
	assert_array(_textos(pila)).is_equal(["EL CLIENTE SE CANSÓ DE ESPERAR."])
	var simbolo := pila.find_children("*", "TextureRect", true, false)[0] as TextureRect
	assert_str(simbolo.texture.resource_path).ends_with("/notificacion_salida.svg")
	pila._process(2.9)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(pila.can_process()).is_false()
	assert_array(_textos(pila)).has_size(1)
	get_tree().paused = false
	pila._process(0.1)
	assert_array(_textos(pila)).is_empty()


func _textos(pila: PilaDeNotificaciones) -> Array[String]:
	var textos: Array[String] = []
	for label: Label in pila.find_children("*", "Label", true, false):
		textos.append(label.text)
	return textos


func test_los_textos_se_pintan_en_el_orden_del_dominio() -> void:  # AC-NTF-009
	var pila := _pila()
	pila.avisar_pista()
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	pila.avisar_lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	assert_array(_textos(pila)).is_equal(["NO SE PUDO LEER", "¡HAY UN CLIENTE!", "¡NUEVA PISTA!"])
	var simbolos := pila.find_children("*", "TextureRect", true, false)
	assert_int(simbolos.size()).is_equal(3)
	assert_str((simbolos[0] as TextureRect).texture.resource_path).is_equal(
		"res://assets/ui/manada/notificacion_lectura.svg"
	)
	assert_str((simbolos[1] as TextureRect).texture.resource_path).is_equal(
		"res://assets/ui/manada/notificacion_cliente.svg"
	)
	assert_str((simbolos[2] as TextureRect).texture.resource_path).is_equal(
		"res://assets/ui/manada/notificacion_pista.svg"
	)


func test_los_tres_carteles_entran_en_la_esquina_en_dos_resoluciones() -> void:  # AC-NTF-009
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var pila: PilaDeNotificaciones = load(ESCENA).instantiate()
	viewport.add_child(pila)
	pila.set_process(false)
	pila.avisar_pista()
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	pila.avisar_lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		viewport.size = tamano
		await get_tree().process_frame
		await get_tree().process_frame
		var pantalla := Rect2(Vector2.ZERO, Vector2(tamano))
		var carteles := pila.get_node("Marco/Pila").get_children()
		assert_int(carteles.size()).is_equal(3)
		for cartel: Control in carteles:
			var rect := cartel.get_global_rect()
			assert_bool(pantalla.encloses(rect)).is_true()
			assert_bool(rect.get_center().x > pantalla.size.x / 2.0).is_true()
			assert_bool(rect.get_center().y < pantalla.size.y / 2.0).is_true()
			var fila: HBoxContainer = cartel.get_child(0)
			var simbolo: TextureRect = fila.get_child(0)
			var texto: Label = fila.get_child(1)
			(
				assert_bool(simbolo.get_global_rect().end.x <= texto.get_global_rect().position.x)
				. is_true()
			)


func test_vaciar_retira_los_carteles_del_arbol() -> void:  # AC-NTF-006
	var pila := _pila()
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	pila.avisar_lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	assert_int(_textos(pila).size()).is_equal(2)
	pila.vaciar()
	assert_array(_textos(pila)).is_empty()


func test_pausar_suspende_el_procesamiento_sin_borrar_el_aviso() -> void:  # AC-NTF-008
	var pila := _pila()
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	pila._process(2.0)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(pila.can_process()).is_false()
	assert_array(_textos(pila)).is_equal(["¡HAY UN CLIENTE!"])
	get_tree().paused = false
	pila.set_process(false)
	pila._process(0.9)
	assert_int(_textos(pila).size()).is_equal(1)
	pila._process(0.1)
	assert_array(_textos(pila)).is_empty()


func test_ningun_control_de_la_pila_intercepta_el_mouse() -> void:  # AC-NTF-010
	var pila := _pila()
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	pila.avisar_lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	var controles := pila.find_children("*", "Control", true, false)
	assert_int(controles.size()).is_greater(2)
	for control: Control in controles:
		assert_int(control.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_el_clic_sobre_el_cartel_llega_a_la_computadora() -> void:  # AC-NTF-010
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var pantalla: PantallaDeComputadora = load(COMPUTADORA).instantiate()
	viewport.add_child(pantalla)
	var pedidos: Array[bool] = []
	pantalla.boton_pulsado.connect(func() -> void: pedidos.append(true))
	var boton := Button.new()
	boton.size = Vector2(64, 64)
	pantalla.add_child(boton)
	var pila: PilaDeNotificaciones = load(ESCENA).instantiate()
	viewport.add_child(pila)
	pila.set_process(false)
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		viewport.size = tamano
		pantalla.mostrar()
		await get_tree().process_frame
		await get_tree().process_frame
		var cartel: Control = pila.get_node("Marco/Pila").get_child(0)
		boton.position = cartel.get_global_rect().get_center() - boton.size / 2.0
		var centro := boton.get_global_rect().get_center()
		assert_bool(pantalla.visible).is_true()
		assert_bool(cartel.get_global_rect().has_point(centro)).is_true()
		for apretado: bool in [true, false]:
			var clic := InputEventMouseButton.new()
			clic.button_index = MOUSE_BUTTON_LEFT
			clic.pressed = apretado
			clic.position = centro
			clic.global_position = centro
			viewport.push_input(clic)
			await get_tree().process_frame
	assert_array(pedidos).is_equal([true, true])


func test_todos_los_avisos_usan_una_linea_y_el_ancho_de_su_contenido() -> void:  # AC-NTF-013
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var pila: PilaDeNotificaciones = load(ESCENA).instantiate()
	viewport.add_child(pila)
	pila.set_process(false)
	pila.avisar_pista()
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	pila.avisar_lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	pila.avisar_salida(Comprador.new("Otro", Venta.new(), 0))
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		viewport.size = tamano
		await get_tree().process_frame
		await get_tree().process_frame
		var carteles := pila.get_node("Marco/Pila").get_children()
		assert_int(carteles.size()).is_equal(4)
		var derecha: float = carteles[0].get_global_rect().end.x
		for cartel: PanelContainer in carteles:
			var fila: HBoxContainer = cartel.get_child(0)
			var simbolo: TextureRect = fila.get_child(0)
			var texto: Label = fila.get_child(1)
			assert_int(texto.get_line_count()).is_equal(1)
			assert_int(texto.get_theme_font_size("font_size")).is_equal(
				texto.get_theme_default_font_size()
			)
			assert_float(cartel.size.x).is_equal_approx(
				fila.get_combined_minimum_size().x + pila._estilo.get_minimum_size().x, 1.0
			)
			assert_float(cartel.get_global_rect().end.x).is_equal_approx(derecha, 0.1)
			(
				assert_bool(Rect2(Vector2.ZERO, Vector2(tamano)).encloses(cartel.get_global_rect()))
				. is_true()
			)
			assert_float(simbolo.get_global_rect().get_center().y).is_equal_approx(
				texto.get_global_rect().get_center().y, 1.0
			)
		assert_float((carteles[0] as Control).size.x).is_greater((carteles[2] as Control).size.x)


func test_el_aviso_de_una_hora_conserva_su_resto_en_pausa() -> void:  # AC-NTF-023
	var pila := _pila()
	pila.set_process(false)
	pila.actualizar_tiempo(3600.0)
	pila._process(2.0)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(pila.can_process()).is_false()
	assert_array(_textos(pila)).is_equal(["QUEDA UNA HORA DE JORNADA"])
	get_tree().paused = false
	pila._process(0.9)
	assert_array(_textos(pila)).has_size(1)
	pila._process(0.1)
	assert_array(_textos(pila)).is_empty()
	pila.actualizar_tiempo(3500.0)
	assert_array(_textos(pila)).is_empty()


func test_una_hora_comparte_esquina_y_su_texto_entra_en_ambas_resoluciones() -> void:  # AC-NTF-024
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var pila: PilaDeNotificaciones = load(ESCENA).instantiate()
	viewport.add_child(pila)
	pila.set_process(false)
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	pila.avisar_salida(Comprador.new("Otro", Venta.new(), 0))
	pila.avisar_lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	pila.actualizar_tiempo(3600.0)
	assert_str(_textos(pila)[0]).is_equal("QUEDA UNA HORA DE JORNADA")
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		viewport.size = tamano
		await get_tree().process_frame
		await get_tree().process_frame
		var carteles := pila.get_node("Marco/Pila").get_children()
		assert_int(carteles.size()).is_equal(4)
		var derecha: float = carteles[0].get_global_rect().end.x
		for cartel: PanelContainer in carteles:
			var fila: HBoxContainer = cartel.get_child(0)
			var simbolo: TextureRect = fila.get_child(0)
			var texto: Label = fila.get_child(1)
			assert_int(texto.get_line_count()).is_equal(1)
			assert_float(texto.size.x).is_greater_equal(texto.get_minimum_size().x)
			assert_object(texto.get_theme_font("font")).is_same(pila._marco.get_theme_font("font"))
			assert_float(cartel.get_global_rect().end.x).is_equal_approx(derecha, 0.1)
			(
				assert_bool(Rect2(Vector2.ZERO, Vector2(tamano)).encloses(cartel.get_global_rect()))
				. is_true()
			)
			assert_float(cartel.size.x).is_equal_approx(
				fila.get_combined_minimum_size().x + pila._estilo.get_minimum_size().x, 1.0
			)
			assert_float(simbolo.get_global_rect().end.x).is_less(
				texto.get_global_rect().position.x
			)
		for control: Control in pila.find_children("*", "Control", true, false):
			assert_int(control.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_el_aviso_de_una_hora_deja_pasar_el_clic_hacia_la_computadora() -> void:  # AC-NTF-024
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var pantalla: PantallaDeComputadora = load(COMPUTADORA).instantiate()
	viewport.add_child(pantalla)
	var pedidos: Array[bool] = []
	pantalla.boton_pulsado.connect(func() -> void: pedidos.append(true))
	var boton := Button.new()
	boton.size = Vector2(64, 64)
	pantalla.add_child(boton)
	var pila: PilaDeNotificaciones = load(ESCENA).instantiate()
	viewport.add_child(pila)
	pila.set_process(false)
	pila.actualizar_tiempo(3600.0)
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		viewport.size = tamano
		pantalla.mostrar()
		await get_tree().process_frame
		await get_tree().process_frame
		var cartel: Control = pila.get_node("Marco/Pila").get_child(0)
		boton.position = cartel.get_global_rect().get_center() - boton.size / 2.0
		var centro := boton.get_global_rect().get_center()
		assert_bool(pantalla.visible).is_true()
		assert_bool(cartel.get_global_rect().has_point(centro)).is_true()
		for apretado: bool in [true, false]:
			var clic := InputEventMouseButton.new()
			clic.button_index = MOUSE_BUTTON_LEFT
			clic.pressed = apretado
			clic.position = centro
			clic.global_position = centro
			viewport.push_input(clic)
			await get_tree().process_frame
	assert_array(pedidos).is_equal([true, true])


# AC-NTF-014, AC-NTF-016
func test_la_pista_tiene_su_simbolo_y_la_pausa_conserva_su_tiempo() -> void:
	var pila := _pila()
	pila.set_process(false)
	get_tree().paused = true
	pila.avisar_pista()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(pila.can_process()).is_false()
	assert_array(_textos(pila)).is_equal(["¡NUEVA PISTA!"])
	var fila: HBoxContainer = pila.get_node("Marco/Pila").get_child(0).get_child(0)
	assert_str((fila.get_child(0) as TextureRect).texture.resource_path).is_equal(
		"res://assets/ui/manada/notificacion_pista.svg"
	)
	assert_object(fila.get_child(1)).is_instanceof(Label)
	get_tree().paused = false
	pila._process(2.9)
	assert_array(_textos(pila)).has_size(1)
	pila._process(0.1)
	assert_array(_textos(pila)).is_empty()
	pila.avisar_pista()
	pila.vaciar()
	assert_array(_textos(pila)).is_empty()
