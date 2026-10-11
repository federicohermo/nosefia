extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/interrupciones/pantalla_de_instrucciones.tscn")
const GUION := preload("res://src/dominio/investigacion/conversacion_con_el_jefe.tres")


func after_test() -> void:
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame


func _pantalla() -> PantallaDeInstrucciones:
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(viewport)
	var pantalla: PantallaDeInstrucciones = ESCENA.instantiate()
	viewport.add_child(pantalla)
	return pantalla


func _boton(pantalla: PantallaDeInstrucciones, nombre: String) -> Button:
	return pantalla.get(nombre)


func test_subida_llega_en_trescientos_milisegundos_reales() -> void:  # AC-EMP-049
	var pantalla := _pantalla()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.mostrar(GUION.mensajes)
	var marco: Control = pantalla.get("_marco")
	assert_float(marco.position.y).is_equal(1080.0)
	ahora[0] = 150000
	pantalla._process(10.0)
	assert_float(marco.position.y).is_equal(540.0)
	ahora[0] = 299999
	pantalla._process(10.0)
	assert_float(marco.position.y).is_greater(0.0)
	assert_bool(pantalla.is_processing()).is_true()
	ahora[0] = 300000
	pantalla._process(0.0)
	assert_float(marco.position.y).is_zero()
	assert_bool(pantalla.is_processing()).is_false()


func _sin_formato(texto: String) -> String:
	return texto.replace("[b]", "").replace("[/b]", "")


func _comprobar_pantalla(pantalla: PantallaDeInstrucciones, numero: int) -> void:
	var contenido: Control = pantalla.get("_contenido")
	var pasos := InstruccionesDelJefe.pasos_de(GUION.mensajes)
	var paso: InstruccionesDelJefe.Paso = pasos[numero - 1]
	var cuerpos: Array[Node] = contenido.find_children("*", "RichTextLabel", false, false)
	for indice in paso.textos.size():
		var cuerpo: RichTextLabel = cuerpos[indice]
		assert_str(cuerpo.get_parsed_text()).is_equal(_sin_formato(paso.textos[indice].texto))
	if numero == 13:
		assert_int(cuerpos.size()).is_equal(paso.textos.size())
	var fotos: Array[Node] = contenido.find_children("*", "TextureRect", false, false)
	var cantidad := (
		1 + (1 if paso.foto != null else 0) + (2 if numero == 5 else (1 if numero == 4 else 0))
	)
	assert_int(fotos.size()).is_equal(cantidad)
	if paso.foto != null:
		var foto: TextureRect = fotos[1]
		assert_object(foto.texture).is_same(paso.foto.foto)
	var contador: Label = pantalla.get("_contador")
	assert_str(contador.text).is_equal("%d/13" % numero)
	var retrato: Control = pantalla.get("_retrato")
	assert_bool(retrato.visible).is_true()
	var volver := _boton(pantalla, "_volver")
	assert_bool(volver.visible).is_true()
	assert_bool(volver.disabled).is_equal(numero == 1)
	assert_str(_boton(pantalla, "_siguiente").text).is_equal("OK" if numero == 13 else "Siguiente")
	assert_int(pantalla.find_children("*", "ScrollContainer", true, false).size()).is_zero()


func test_trece_pantallas_y_ok_idempotente() -> void:  # AC-EMP-045, AC-EMP-046
	var pantalla := _pantalla()
	pantalla.mostrar(GUION.mensajes)
	var botones: Control = pantalla.get("_botones")
	var posicion := botones.position
	var siguiente := _boton(pantalla, "_siguiente")
	for numero in range(1, 14):
		await get_tree().process_frame
		await get_tree().process_frame
		_comprobar_pantalla(pantalla, numero)
		assert_vector(botones.position).is_equal(posicion)
		if numero < 13:
			siguiente.pressed.emit()
	var volver := _boton(pantalla, "_volver")
	volver.pressed.emit()
	await get_tree().process_frame
	_comprobar_pantalla(pantalla, 12)
	var comienzos: Array[int] = [0]
	pantalla.comenzar_pedido.connect(func() -> void: comienzos[0] += 1)
	siguiente.pressed.emit()
	siguiente.pressed.emit()
	siguiente.pressed.emit()
	assert_int(comienzos[0]).is_equal(1)
	assert_bool(pantalla.visible).is_false()


func test_volver_tres_veces_recupera_solo_la_primera_pantalla() -> void:  # AC-EMP-045
	var pantalla := _pantalla()
	pantalla.mostrar(GUION.mensajes)
	for _paso in 3:
		_boton(pantalla, "_siguiente").pressed.emit()
	for _paso in 4:
		_boton(pantalla, "_volver").pressed.emit()
	await get_tree().process_frame
	_comprobar_pantalla(pantalla, 1)
	var contenido: Control = pantalla.get("_contenido")
	assert_int(contenido.get_child_count()).is_equal(2)


func test_pantallas_sin_scroll_en_ambos_viewports() -> void:  # AC-EMP-045, AC-EMP-046
	for resolucion: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		var pantalla := _pantalla()
		var viewport: SubViewport = pantalla.get_viewport()
		viewport.size = resolucion
		pantalla.mostrar(GUION.mensajes)
		pantalla.set("_avance", 1.0)
		pantalla.call("_ajustar")
		for numero in range(1, 14):
			await get_tree().process_frame
			await get_tree().process_frame
			var botones: Control = pantalla.get("_botones")
			var posicion := botones.global_position
			var contenido: Control = pantalla.get("_contenido")
			for hijo: Control in contenido.get_children():
				assert_float(hijo.get_global_rect().end.y).is_less(
					botones.get_global_rect().position.y
				)
				assert_float(hijo.get_global_rect().end.x).is_less_equal(float(resolucion.x))
			var rueda := InputEventMouseButton.new()
			rueda.button_index = MOUSE_BUTTON_WHEEL_DOWN
			rueda.pressed = true
			rueda.position = contenido.get_global_rect().get_center()
			viewport.push_input(rueda)
			await get_tree().process_frame
			assert_vector(botones.global_position).is_equal(posicion)
			_comprobar_pantalla(pantalla, numero)
			if numero < 13:
				_boton(pantalla, "_siguiente").pressed.emit()


func test_pausa_conserva_la_subida_y_no_cobra_el_tiempo_pausado() -> void:  # AC-EMP-049
	var pantalla := _pantalla()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.mostrar(GUION.mensajes)
	ahora[0] = 150000
	pantalla._process(0.0)
	var marco: Control = pantalla.get("_marco")
	var posicion := marco.position
	get_tree().paused = true
	ahora[0] += 120000000
	for _cuadro in 4:
		await get_tree().process_frame
	assert_vector(marco.position).is_equal(posicion)
	get_tree().paused = false
	ahora[0] += 150000
	pantalla._process(0.0)
	assert_float(marco.position.y).is_zero()
