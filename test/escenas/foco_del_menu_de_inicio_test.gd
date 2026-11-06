## El foco del menú de inicio queda puesto para la cruceta, y no se dibuja hasta que el jugador
## navega.
extends GdUnitTestSuite

const ESCENA_DEL_MENU := "res://src/escenas/menu_de_inicio.tscn"

var _ruta: String


func before_test() -> void:
	_ruta = create_temp_dir("menu").path_join("partida.guardado")


func after_test() -> void:
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	ajuste.aplicar(Preferencias.new())


func _menu() -> Control:
	var menu: Control = auto_free(load(ESCENA_DEL_MENU).instantiate())
	(menu.get("_guardado") as Guardado).ruta = _ruta
	add_child(menu)
	return menu


func _boton(menu: Control, texto: String) -> Button:
	for boton: Button in menu.find_children("*", "Button", true, false):
		if boton.text == texto:
			return boton
	return null


func test_el_menu_abre_con_un_boton_elegido_que_no_se_dibuja() -> void:  # AC-CFG-028
	var menu := _menu()
	await await_idle_frame()
	var foco := menu.get_viewport().gui_get_focus_owner()
	assert_object(foco).is_not_null()
	assert_bool(foco != null and menu.is_ancestor_of(foco) and foco.has_focus()).is_true()
	assert_bool(foco != null and foco.has_focus(true)).is_false()


func test_al_cerrar_configuraciones_el_foco_vuelve_sin_dibujarse() -> void:  # AC-CFG-028
	var menu := _menu()
	await await_idle_frame()
	_boton(menu, "CONFIGURACIONES").pressed.emit()
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	(menu.get("_configuraciones") as PantallaDeConfiguraciones)._unhandled_input(esc)
	var boton := _boton(menu, "CONFIGURACIONES")
	assert_bool(boton.has_focus()).is_true()
	assert_bool(boton.has_focus(true)).is_false()
