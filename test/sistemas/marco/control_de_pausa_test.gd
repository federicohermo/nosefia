## El nodo de la pausa: traduce Esc y el cursor a la pregunta del dominio, y pausa el árbol.
extends GdUnitTestSuite

const CONTROL := "res://src/sistemas/marco/control_de_pausa.gd"

var _pausas: int = 0
var _reanudaciones: int = 0
var _menus: int = 0


func before_test() -> void:
	_pausas = 0
	_reanudaciones = 0
	_menus = 0


func after_test() -> void:
	get_tree().paused = false


func _control(placa: CanvasLayer = null) -> ControlDePausa:
	var control: ControlDePausa = auto_free(ControlDePausa.new())
	control.placa = placa
	control.pausado.connect(func() -> void: _pausas += 1)
	control.reanudado.connect(func() -> void: _reanudaciones += 1)
	control.volver_al_menu_pedido.connect(func() -> void: _menus += 1)
	add_child(control)
	return control


func _esc() -> InputEventAction:
	var evento := InputEventAction.new()
	evento.action = &"ui_cancel"
	evento.pressed = true
	return evento


func test_esc_pausa_el_arbol_y_otro_esc_lo_reanuda() -> void:  # AC-SAV-018
	var control := _control()
	control._input(_esc())
	assert_bool(get_tree().paused).is_true()
	assert_int(_pausas).is_equal(1)
	control._input(_esc())
	assert_bool(get_tree().paused).is_false()
	assert_int(_reanudaciones).is_equal(1)
	assert_int(_pausas).is_equal(1)


func test_el_nodo_corre_tambien_en_pausa() -> void:
	var control := _control()
	assert_int(control.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_con_la_placa_en_pantalla_esc_no_hace_nada() -> void:  # AC-SAV-018
	var placa: CanvasLayer = auto_free(CanvasLayer.new())
	placa.visible = true
	var control := _control(placa)
	control._input(_esc())
	assert_bool(get_tree().paused).is_false()
	assert_int(_pausas).is_zero()


func test_perder_el_cursor_que_el_juego_tenia_tomado_pausa() -> void:  # AC-SAV-018
	# En headless el motor nunca tiene el cursor tomado: lo de antes se escribe a mano, y lo de
	# ahora es lo que contesta el motor, suelto.
	var control := _control()
	control.set("_cursor_antes", true)
	control.call("_mirar_el_cursor")
	assert_bool(get_tree().paused).is_true()
	assert_int(_pausas).is_equal(1)


func test_el_cursor_que_suelta_el_juego_no_pausa() -> void:  # AC-SAV-018
	# Lo de antes se mide después de que el juego escribe: si el juego lo soltó, ya estaba suelto.
	var control := _control()
	control._physics_process(0.0)
	control.call("_mirar_el_cursor")
	assert_bool(get_tree().paused).is_false()
	assert_int(_pausas).is_zero()


func test_volver_al_menu_sale_de_la_pausa_y_pide_el_menu_una_vez() -> void:  # AC-SAV-020
	var control := _control()
	control._input(_esc())
	control.pedir_volver_al_menu()
	control.pedir_volver_al_menu()
	assert_bool(get_tree().paused).is_false()
	assert_int(_menus).is_equal(1)


func test_volver_al_menu_no_guarda_nada() -> void:  # AC-SAV-020
	var texto := FileAccess.get_file_as_string(CONTROL).to_lower()
	assert_str(texto).is_not_empty()
	assert_str(texto).not_contains("guardad")
	assert_str(texto).not_contains("fileaccess")


func test_reanudar_fuera_de_la_pausa_no_avisa() -> void:
	var control := _control()
	control.reanudar()
	assert_int(_reanudaciones).is_zero()
