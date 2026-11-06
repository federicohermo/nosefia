## El círculo naranja del ícono del celular en el HUD y su vibración.
extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")

var _tamano_de_ventana: Vector2i


func before_test() -> void:
	_tamano_de_ventana = get_window().size
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame


func after_test() -> void:
	get_window().size = _tamano_de_ventana
	await get_tree().process_frame
	await get_tree().process_frame


func _pantalla() -> PantallaDelCelular:
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	return pantalla


func _circulo(pantalla: PantallaDelCelular) -> Control:
	return pantalla.get("_aviso")


func _recordatorio(pantalla: PantallaDelCelular) -> Control:
	return pantalla.get("_recordatorio")


func test_el_circulo_muestra_el_total_y_se_oculta_en_cero() -> void:  # AC-INV-180
	var pantalla := _pantalla()
	pantalla.mostrar_recordatorio(true)
	pantalla.soltar_los_no_leidos()
	var circulo := _circulo(pantalla)
	assert_bool(circulo.visible).is_false()
	pantalla.mostrar_no_leidos(3)
	assert_bool(circulo.visible).is_true()
	assert_str((circulo.get_node("Numero") as Label).text).is_equal("3")
	pantalla.mostrar_no_leidos(1)
	assert_str((circulo.get_node("Numero") as Label).text).is_equal("1")
	pantalla.mostrar_no_leidos(0)
	assert_bool(circulo.visible).is_false()


func test_el_circulo_es_naranja_y_va_en_la_esquina_superior_derecha() -> void:  # AC-INV-180
	var pantalla := _pantalla()
	var icono: Control = _recordatorio(pantalla).get_node("Icono")
	var circulo := _circulo(pantalla)
	var estilo := circulo.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(estilo).is_not_null()
	assert_that(estilo.bg_color).is_equal(PantallaDelCelular.NARANJA_DEL_AVISO)
	assert_bool(circulo.get_parent() == icono).is_true()
	var centro := circulo.position + circulo.size / 2.0
	assert_float(centro.x).is_equal_approx(icono.custom_minimum_size.x, 0.5)
	assert_float(centro.y).is_equal_approx(0.0, 0.5)


func _rectangulo_en_pantalla(control: Control) -> Rect2:
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)


func _pantalla_con_aviso_en(ventana: Vector2i) -> PantallaDelCelular:
	get_window().size = ventana
	await get_tree().process_frame
	assert_vector(get_viewport().get_visible_rect().size).is_equal(Vector2(ventana))
	var pantalla := _pantalla()
	pantalla.mostrar_recordatorio(true)
	pantalla.soltar_los_no_leidos()
	pantalla.mostrar_no_leidos(9)
	await get_tree().process_frame
	return pantalla


func _cabe_en_pantalla(control: Control) -> bool:
	var visible := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	return visible.encloses(_rectangulo_en_pantalla(control))


func test_el_icono_y_el_circulo_no_se_cortan_a_1920x1080() -> void:
	var pantalla := await _pantalla_con_aviso_en(Vector2i(1920, 1080))
	assert_bool(_circulo(pantalla).is_visible_in_tree()).is_true()
	assert_bool(_cabe_en_pantalla(_recordatorio(pantalla).get_node("Icono"))).is_true()
	assert_bool(_cabe_en_pantalla(_circulo(pantalla))).is_true()


func test_el_icono_y_el_circulo_no_se_cortan_a_1280x720() -> void:
	var pantalla := await _pantalla_con_aviso_en(Vector2i(1280, 720))
	assert_bool(_circulo(pantalla).is_visible_in_tree()).is_true()
	assert_bool(_cabe_en_pantalla(_recordatorio(pantalla).get_node("Icono"))).is_true()
	assert_bool(_cabe_en_pantalla(_circulo(pantalla))).is_true()


func test_el_icono_sigue_adentro_de_la_pantalla_si_crece_su_alto() -> void:
	var pantalla := await _pantalla_con_aviso_en(Vector2i(1920, 1080))
	var icono: Control = _recordatorio(pantalla).get_node("Icono")
	var alto := icono.custom_minimum_size.y
	icono.custom_minimum_size.y = alto * 2.0
	await get_tree().process_frame
	pantalla.call("_ajustar")
	await get_tree().process_frame
	assert_float(icono.size.y).is_greater_equal(alto * 2.0)
	assert_bool(_cabe_en_pantalla(icono)).is_true()


func test_la_tecla_queda_a_la_derecha_del_icono_sin_que_el_circulo_la_tape() -> void:
	var pantalla := _pantalla()
	pantalla.mostrar_recordatorio(true)
	await get_tree().process_frame
	var recordatorio := _recordatorio(pantalla)
	var icono: Control = recordatorio.get_node("Icono")
	var tecla: Control = recordatorio.get_node("Tecla")
	var circulo := _rectangulo_en_pantalla(_circulo(pantalla))
	var rect_de_la_tecla := _rectangulo_en_pantalla(tecla)
	assert_float(rect_de_la_tecla.position.x).is_greater_equal(_rectangulo_en_pantalla(icono).end.x)
	assert_float(rect_de_la_tecla.position.x).is_greater_equal(circulo.end.x)


func test_el_circulo_no_se_ve_con_el_icono_oculto_o_cubierto() -> void:  # AC-INV-180
	var pantalla := _pantalla()
	pantalla.soltar_los_no_leidos()
	pantalla.mostrar_recordatorio(true)
	pantalla.mostrar_no_leidos(3)
	var circulo := _circulo(pantalla)
	assert_bool(circulo.is_visible_in_tree()).is_true()
	pantalla.cubrir_recordatorio(true)
	assert_bool(circulo.is_visible_in_tree()).is_false()
	pantalla.cubrir_recordatorio(false)
	assert_bool(circulo.is_visible_in_tree()).is_true()
	pantalla.mostrar_recordatorio(false)
	assert_bool(circulo.is_visible_in_tree()).is_false()


func test_el_icono_vibra_al_subir_y_vuelve_a_su_lugar() -> void:  # AC-INV-181
	var pantalla := _pantalla()
	pantalla.soltar_los_no_leidos()
	pantalla.mostrar_recordatorio(true)
	var recordatorio := _recordatorio(pantalla)
	var escala := recordatorio.scale
	var base := recordatorio.position
	pantalla.mostrar_no_leidos(1)
	assert_bool(pantalla.vibrando()).is_true()
	pantalla.call("_pintar_la_vibracion", 0.01)
	assert_vector(recordatorio.position).is_not_equal(base)
	assert_vector(recordatorio.scale).is_equal(escala)
	pantalla.call("_terminar_la_vibracion")
	assert_bool(pantalla.vibrando()).is_false()
	assert_vector(recordatorio.position).is_equal(base)
	assert_vector(recordatorio.scale).is_equal(escala)


func test_una_segunda_subida_reinicia_la_vibracion_sin_superponerla() -> void:  # AC-INV-181
	var pantalla := _pantalla()
	pantalla.soltar_los_no_leidos()
	pantalla.mostrar_recordatorio(true)
	pantalla.mostrar_no_leidos(1)
	var primera: Tween = pantalla.get("_vibracion")
	pantalla.mostrar_no_leidos(2)
	var segunda: Tween = pantalla.get("_vibracion")
	assert_bool(primera == segunda).is_false()
	assert_bool(primera.is_valid()).is_false()
	assert_bool(segunda.is_valid()).is_true()


func test_el_icono_no_vibra_al_bajar_ni_oculto() -> void:  # AC-INV-181
	var pantalla := _pantalla()
	pantalla.soltar_los_no_leidos()
	pantalla.mostrar_recordatorio(true)
	pantalla.mostrar_no_leidos(2)
	pantalla.call("_terminar_la_vibracion")
	pantalla.mostrar_no_leidos(1)
	assert_bool(pantalla.vibrando()).is_false()
	pantalla.cubrir_recordatorio(true)
	pantalla.mostrar_no_leidos(5)
	assert_bool(pantalla.vibrando()).is_false()
	pantalla.cubrir_recordatorio(false)
	assert_bool(pantalla.vibrando()).is_false()


func test_la_persiana_retiene_el_circulo_hasta_que_sube() -> void:  # AC-INV-182
	var pantalla := _pantalla()
	pantalla.mostrar_recordatorio(true)
	pantalla.mostrar_no_leidos(2)
	assert_bool(_circulo(pantalla).visible).is_false()
	assert_bool(pantalla.vibrando()).is_false()
	pantalla.soltar_los_no_leidos()
	assert_bool(_circulo(pantalla).visible).is_true()
	assert_bool(pantalla.vibrando()).is_true()
	pantalla.call("_terminar_la_vibracion")
	pantalla.retener_los_no_leidos()
	pantalla.mostrar_no_leidos(2)
	pantalla.soltar_los_no_leidos()
	assert_bool(pantalla.vibrando()).is_false()
