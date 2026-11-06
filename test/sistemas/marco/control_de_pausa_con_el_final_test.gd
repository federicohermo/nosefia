## Con la pantalla del final a la vista, ni Esc ni perder el cursor abren la pausa.
extends GdUnitTestSuite


func after_test() -> void:
	get_tree().paused = false


func _control(pantalla: CanvasLayer) -> ControlDePausa:
	var control: ControlDePausa = auto_free(ControlDePausa.new())
	control.pantalla_del_final = pantalla
	add_child(control)
	return control


func _esc() -> InputEventAction:
	var evento := InputEventAction.new()
	evento.action = &"ui_cancel"
	evento.pressed = true
	return evento


func test_con_la_pantalla_del_final_visible_esc_y_cursor_suelto_no_pausan() -> void:  # AC-SAV-052
	var pantalla: CanvasLayer = auto_free(CanvasLayer.new())
	pantalla.visible = true
	var control := _control(pantalla)
	control._input(_esc())
	control.set("_cursor_antes", true)
	control.call("_mirar_el_cursor")
	assert_bool(get_tree().paused).is_false()


func test_con_la_pantalla_del_final_oculta_esc_pausa() -> void:
	var pantalla: CanvasLayer = auto_free(CanvasLayer.new())
	pantalla.visible = false
	var control := _control(pantalla)
	control._input(_esc())
	assert_bool(get_tree().paused).is_true()
