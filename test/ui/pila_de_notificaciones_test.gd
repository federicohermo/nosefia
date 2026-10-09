extends GdUnitTestSuite

const ESCENA := "res://src/ui/pila_de_notificaciones.tscn"


func after_test() -> void:
	get_tree().paused = false


func _pila() -> PilaDeNotificaciones:
	var pila: PilaDeNotificaciones = auto_free(load(ESCENA).instantiate())
	add_child(pila)
	return pila


func test_la_salida_tiene_el_texto_y_simbolo_de_figma_y_respeta_pausa() -> void:  # AC-NTF-011
	var pila := _pila()
	pila.avisar_salida(Compradores.de_la_jornada(1)[0])
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
		textos.append(label.text.replace("\n", " "))
	return textos


func test_los_textos_se_pintan_en_el_orden_del_dominio() -> void:  # AC-NTF-009
	var pila := _pila()
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	pila.avisar_lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	assert_array(_textos(pila)).is_equal(["NO SE PUDO LEER", "¡HAY UN CLIENTE!"])
	var simbolos := pila.find_children("*", "TextureRect", true, false)
	assert_int(simbolos.size()).is_equal(2)
	assert_str((simbolos[0] as TextureRect).texture.resource_path).is_equal(
		"res://assets/ui/manada/notificacion_lectura.svg"
	)
	assert_str((simbolos[1] as TextureRect).texture.resource_path).is_equal(
		"res://assets/ui/manada/notificacion_cliente.svg"
	)


func test_los_dos_carteles_entran_en_la_esquina_en_dos_resoluciones() -> void:  # AC-NTF-009
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var pila: PilaDeNotificaciones = load(ESCENA).instantiate()
	viewport.add_child(pila)
	pila.set_process(false)
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	pila.avisar_lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		viewport.size = tamano
		await get_tree().process_frame
		await get_tree().process_frame
		var pantalla := Rect2(Vector2.ZERO, Vector2(tamano))
		var carteles := pila.get_node("Marco/Pila").get_children()
		assert_int(carteles.size()).is_equal(2)
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


func test_el_clic_sobre_el_cartel_llega_al_boton_de_notas() -> void:  # AC-NTF-010
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var pantalla: PantallaDeComputadora = (
		load("res://src/ui/diegetica/pantalla_de_computadora.tscn").instantiate()
	)
	viewport.add_child(pantalla)
	var pedidos: Array[Computadora.App] = []
	pantalla.app_pedida.connect(func(app: Computadora.App) -> void: pedidos.append(app))
	var pila: PilaDeNotificaciones = load(ESCENA).instantiate()
	viewport.add_child(pila)
	pila.set_process(false)
	pila.avisar_llegada(Comprador.new("Comprador", Venta.new(), 0))
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		viewport.size = tamano
		pantalla.mostrar(Computadora.App.CAJA)
		await get_tree().process_frame
		await get_tree().process_frame
		var notas: Button = pantalla.get_node("Fondo/Marco/Opciones").get_child(1)
		var centro := notas.get_global_rect().get_center()
		var cartel: Control = pila.get_node("Marco/Pila").get_child(0)
		assert_bool(cartel.get_global_rect().has_point(centro)).is_true()
		for apretado: bool in [true, false]:
			var clic := InputEventMouseButton.new()
			clic.button_index = MOUSE_BUTTON_LEFT
			clic.pressed = apretado
			clic.position = centro
			clic.global_position = centro
			viewport.push_input(clic)
			await get_tree().process_frame
	assert_array(pedidos).is_equal([Computadora.App.NOTAS, Computadora.App.NOTAS])
