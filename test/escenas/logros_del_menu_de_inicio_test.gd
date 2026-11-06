## El botón Logros del menú de inicio abre la pantalla de logros, y Esc la cierra y deja el menú.
##
## Ningún caso aprieta un botón que entra al almacén: cambiar de escena se llevaría la corrida.
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


func _esc() -> InputEventAction:
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	return esc


func test_logros_se_abre_y_esc_la_cierra_y_deja_el_menu() -> void:  # AC-ACH-014, AC-SAV-037
	var menu := _menu()
	var pantalla: PantallaDeLogros = menu.get("_logros_pantalla")
	assert_bool(pantalla.visible).is_false()
	assert_bool(_boton(menu, "LOGROS").disabled).is_false()
	_boton(menu, "LOGROS").pressed.emit()
	assert_bool(pantalla.visible).is_true()
	assert_bool((menu.get("_marco") as Control).visible).is_false()
	pantalla._unhandled_input(_esc())
	assert_bool(pantalla.visible).is_false()
	assert_bool((menu.get("_marco") as Control).visible).is_true()
	assert_bool(_boton(menu, "LOGROS").has_focus()).is_true()
	assert_object(menu.get("_espera")).is_null()
	assert_bool(menu.get("_fundiendo")).is_false()
