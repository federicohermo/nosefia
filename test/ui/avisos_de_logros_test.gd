## El aviso de un logro en la pila: su nombre en mayúsculas, en un renglón, con el trofeo a la
## izquierda, dentro de la esquina y sin tomar el clic.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/pila_de_notificaciones.tscn"
const L := Logros.Logro


func after_test() -> void:
	get_tree().paused = false


func _pila_en(viewport: SubViewport) -> PilaDeNotificaciones:
	var pila: PilaDeNotificaciones = load(ESCENA).instantiate()
	viewport.add_child(pila)
	pila.set_process(false)
	return pila


func _textos(pila: PilaDeNotificaciones) -> Array[String]:
	var textos: Array[String] = []
	for label: Label in pila.get_node("Marco/Pila").find_children("*", "Label", true, false):
		textos.append(label.text)
	return textos


func _aviso_de(logro: L) -> String:
	return PilaDeNotificaciones.PREFIJO_DEL_LOGRO + Logros.nombre(logro).to_upper()


func test_el_nombre_va_en_mayusculas_y_dos_logros_son_dos_carteles() -> void:  # AC-NTF-046
	var pila: PilaDeNotificaciones = auto_free(load(ESCENA).instantiate())
	add_child(pila)
	pila.set_process(false)
	pila.avisar_logro(L.REBELDE)
	pila.avisar_logro(L.ESTAMOS_AL_PEDO)
	assert_array(_textos(pila)).is_equal([_aviso_de(L.ESTAMOS_AL_PEDO), _aviso_de(L.REBELDE)])
	pila._process(Notificaciones.DURACION)
	assert_array(_textos(pila)).is_empty()


func test_el_aviso_dice_nuevo_logro_antes_del_nombre() -> void:  # AC-NTF-046
	var pila: PilaDeNotificaciones = auto_free(load(ESCENA).instantiate())
	add_child(pila)
	pila.set_process(false)
	pila.avisar_logro(L.REBELDE)
	var textos := _textos(pila)
	assert_int(textos.size()).is_equal(1)
	assert_str(textos[0]).starts_with(PilaDeNotificaciones.PREFIJO_DEL_LOGRO)
	assert_str(textos[0]).ends_with(Logros.nombre(L.REBELDE).to_upper())
	assert_str(PilaDeNotificaciones.PREFIJO_DEL_LOGRO).is_not_empty()


func test_el_cartel_lleva_el_trofeo_a_la_izquierda_en_un_renglon() -> void:  # AC-NTF-046
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var pila := _pila_en(viewport)
	pila.avisar_logro(L.Y_SE_MARCHO)
	pila.avisar_logro(L.ESTAMOS_AL_PEDO)
	pila._process(1.0)
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		viewport.size = tamano
		await get_tree().process_frame
		await get_tree().process_frame
		var carteles := pila.get_node("Marco/Pila").get_children()
		assert_int(carteles.size()).is_equal(2)
		for cartel: PanelContainer in carteles:
			var fila: HBoxContainer = cartel.get_child(0)
			var simbolo: TextureRect = fila.get_child(0)
			var texto: Label = fila.get_child(1)
			assert_str(simbolo.texture.resource_path).ends_with("/notificacion_logro.svg")
			assert_int(texto.get_line_count()).is_equal(1)
			assert_float(simbolo.get_global_rect().end.x).is_less(
				texto.get_global_rect().position.x
			)
			(
				assert_bool(Rect2(Vector2.ZERO, Vector2(tamano)).encloses(cartel.get_global_rect()))
				. is_true()
			)
		assert_float((carteles[0] as Control).get_global_rect().end.x).is_equal_approx(
			(carteles[1] as Control).get_global_rect().end.x, 0.1
		)
	for control: Control in pila.find_children("*", "Control", true, false):
		assert_int(control.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_la_fuente_del_tema_dibuja_los_signos_de_los_nombres() -> void:  # AC-NTF-046
	var pila: PilaDeNotificaciones = auto_free(load(ESCENA).instantiate())
	add_child(pila)
	var fuente := pila._marco.get_theme_font("font")
	for logro: L in L.values():
		for letra: String in Logros.nombre(logro).to_upper():
			assert_bool(fuente.has_char(letra.unicode_at(0))).is_true()


func test_un_logro_del_cierre_aparece_despues_de_vaciar_la_noche() -> void:  # AC-NTF-046
	var pila: PilaDeNotificaciones = auto_free(load(ESCENA).instantiate())
	add_child(pila)
	pila.set_process(false)
	pila.avisar_pista()
	pila.vaciar()
	pila.avisar_logro(L.EMPLEADO_EJEMPLAR)
	assert_array(_textos(pila)).is_equal([_aviso_de(L.EMPLEADO_EJEMPLAR)])


func test_ningun_aviso_de_logro_se_sale_del_cartel() -> void:  # AC-NTF-046
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var pila := _pila_en(viewport)
	for logro: L in L.values():
		pila.avisar_logro(logro)
	pila._process(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var carteles := pila.get_node("Marco/Pila").get_children()
	assert_int(carteles.size()).is_equal(L.values().size())
	for cartel: PanelContainer in carteles:
		var texto: Label = cartel.get_child(0).get_child(1)
		(
			assert_bool(
				Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(cartel.get_global_rect())
			)
			. is_true()
		)
		assert_float(texto.get_global_rect().end.x).is_less_equal(cartel.get_global_rect().end.x)
