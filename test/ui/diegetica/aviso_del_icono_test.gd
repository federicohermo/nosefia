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
