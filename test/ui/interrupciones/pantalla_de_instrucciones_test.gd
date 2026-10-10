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


func test_catorce_pasos_con_fotos_y_botones_al_final() -> void:  # AC-EMP-045, AC-EMP-046
	var pantalla := _pantalla()
	pantalla.mostrar(GUION.mensajes)
	var lista: VBoxContainer = pantalla.get("_contenido")
	var botones: HBoxContainer = pantalla.get("_botones")
	var siguiente := _boton(pantalla, "_siguiente")
	var volver := _boton(pantalla, "_volver")
	var pasos := InstruccionesDelJefe.pasos_de(GUION.mensajes)
	assert_int(pasos.size()).is_equal(14)
	assert_bool(volver.visible).is_false()
	for indice in 14:
		await get_tree().process_frame
		await get_tree().process_frame
		assert_int(lista.get_child_count()).is_equal(indice + 2)
		assert_object(lista.get_child(-1)).is_same(botones)
		var ultimo: VBoxContainer = lista.get_child(indice)
		var cuerpo: RichTextLabel = ultimo.get_child(-1)
		assert_str(cuerpo.text).is_equal(pasos[indice].texto.texto)
		assert_bool(cuerpo.bbcode_enabled).is_true()
		if pasos[indice].foto != null:
			assert_int(ultimo.get_child_count()).is_equal(2)
			var foto: TextureRect = ultimo.get_child(0)
			assert_object(foto.texture).is_same(pasos[indice].foto.foto)
		else:
			assert_int(ultimo.get_child_count()).is_equal(1)
		assert_float(botones.get_global_rect().position.y).is_greater_equal(
			ultimo.get_global_rect().end.y
		)
		if indice < 13:
			assert_str(siguiente.text).is_equal("Siguiente")
			siguiente.pressed.emit()
	assert_bool(volver.visible).is_true()
	assert_str(siguiente.text).is_equal("Comenzar")
	volver.pressed.emit()
	assert_int(lista.get_child_count()).is_equal(14)
	assert_str(siguiente.text).is_equal("Siguiente")
	var comienzos: Array[int] = [0]
	pantalla.comenzar_pedido.connect(func() -> void: comienzos[0] += 1)
	siguiente.pressed.emit()
	siguiente.pressed.emit()
	siguiente.pressed.emit()
	assert_int(comienzos[0]).is_equal(1)
	assert_bool(pantalla.visible).is_false()


func test_volver_tres_veces_deja_intro_uno_y_no_permite_quitarlo() -> void:  # AC-EMP-045
	var pantalla := _pantalla()
	pantalla.mostrar(GUION.mensajes)
	var siguiente := _boton(pantalla, "_siguiente")
	var volver := _boton(pantalla, "_volver")
	for _paso in 3:
		siguiente.pressed.emit()
	for _paso in 3:
		volver.pressed.emit()
	volver.pressed.emit()
	var lista: VBoxContainer = pantalla.get("_contenido")
	assert_int(lista.get_child_count()).is_equal(2)
	assert_bool(volver.visible).is_false()
	var cuerpo: RichTextLabel = lista.get_child(0).get_child(0)
	assert_str(cuerpo.text).is_equal(GUION.mensajes[0].texto)


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
