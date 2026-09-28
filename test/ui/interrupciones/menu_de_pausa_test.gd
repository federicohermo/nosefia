## El menú de pausa: cuatro botones, y cada uno emite su pedido aun con el árbol en pausa.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/menu_de_pausa.tscn"
const SCRIPT := "res://src/ui/interrupciones/menu_de_pausa.gd"
const TEXTOS: Array[String] = ["REANUDAR", "CONFIGURACIONES", "LOGROS", "VOLVER AL MENÚ"]
const HABILITADOS: Array[String] = ["REANUDAR", "VOLVER AL MENÚ"]

var _reanudar: int = 0
var _volver: int = 0


func before_test() -> void:
	_reanudar = 0
	_volver = 0


func after_test() -> void:
	get_tree().paused = false


func _menu() -> MenuDePausa:
	var menu: MenuDePausa = auto_free(load(ESCENA).instantiate())
	menu.reanudar_pedido.connect(func() -> void: _reanudar += 1)
	menu.volver_al_menu_pedido.connect(func() -> void: _volver += 1)
	add_child(menu)
	return menu


func _botones(menu: MenuDePausa) -> Array[Button]:
	var botones: Array[Button] = []
	for boton: Button in menu.find_children("*", "Button", true, false):
		botones.append(boton)
	return botones


func test_arranca_oculto_y_corre_solo_en_pausa() -> void:
	var menu := _menu()
	assert_bool(menu.visible).is_false()
	assert_int(menu.process_mode).is_equal(Node.PROCESS_MODE_WHEN_PAUSED)


func test_muestra_los_cuatro_botones_en_orden_y_habilita_dos() -> void:  # AC-SAV-019
	var menu := _menu()
	var textos: Array[String] = []
	var habilitados: Array[String] = []
	for boton in _botones(menu):
		textos.append(boton.text)
		if not boton.disabled:
			habilitados.append(boton.text)
	assert_array(textos).is_equal(TEXTOS)
	assert_array(habilitados).is_equal(HABILITADOS)


func test_no_ofrece_salir() -> void:  # AC-SAV-019
	for boton in _botones(_menu()):
		assert_str(boton.text).not_contains("SALIR")


func test_volver_al_menu_emite_su_pedido() -> void:  # AC-SAV-020
	var menu := _menu()
	(menu.get_node("Fondo/Panel/Opciones/VolverAlMenu") as Button).pressed.emit()
	assert_int(_volver).is_equal(1)
	assert_int(_reanudar).is_zero()


func test_con_el_arbol_en_pausa_el_clic_en_reanudar_llega() -> void:
	var menu := _menu()
	get_tree().paused = true
	menu.mostrar()
	await get_tree().process_frame
	await get_tree().process_frame
	var boton: Button = menu.get_node("Fondo/Panel/Opciones/Reanudar")
	var centro := boton.get_global_rect().get_center()
	for apretado: bool in [true, false]:
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = apretado
		clic.position = centro
		clic.global_position = centro
		get_viewport().push_input(clic)
		await get_tree().process_frame
	assert_int(_reanudar).is_equal(1)


func test_mostrar_deja_el_foco_en_reanudar() -> void:
	var menu := _menu()
	menu.mostrar()
	assert_bool(menu.visible).is_true()
	assert_bool((menu.get_node("Fondo/Panel/Opciones/Reanudar") as Button).has_focus()).is_true()
	menu.ocultar()
	assert_bool(menu.visible).is_false()


func test_el_menu_usa_el_tema_y_no_declara_estilos() -> void:
	var texto := FileAccess.get_file_as_string(ESCENA)
	assert_str(texto).contains("res://assets/ui/manada/tema.tres")
	assert_str(texto).not_contains("theme_override_")


func test_el_menu_no_decide() -> void:
	var texto := FileAccess.get_file_as_string(SCRIPT)
	var condicion := RegEx.create_from_string("\\b(if|elif|match)\\b")
	for linea in texto.split("\n"):
		assert_array(condicion.search_all(linea.split("#")[0])).is_empty()


func test_escala_con_el_lienzo_de_manada() -> void:
	var menu := _menu()
	var marco: Control = menu.get_node("Fondo/Panel")
	var visible := menu.get_viewport().get_visible_rect().size
	var esperado := minf(
		visible.x / LienzoDeManada.TAMANO_DEL_DISENO.x,
		visible.y / LienzoDeManada.TAMANO_DEL_DISENO.y
	)
	assert_vector(marco.scale).is_equal_approx(Vector2.ONE * esperado, Vector2.ONE * 1e-4)
