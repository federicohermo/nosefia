## El menú pide el almacén apenas aparece, y «Nuevo juego» siempre pasa por la pantalla de carga.
##
## Ningún caso deja correr un cuadro con «Nuevo juego» elegido: con el almacén listo, el menú
## cambiaría la escena de la corrida de tests.
extends GdUnitTestSuite

const ESCENA_DEL_MENU := "res://src/escenas/menu_de_inicio.tscn"
const PANTALLA_DE_CARGA := "res://src/ui/interrupciones/pantalla_de_carga.tscn"


func _menu() -> Control:
	var menu: Control = auto_free(load(ESCENA_DEL_MENU).instantiate())
	add_child(menu)
	return menu


func _carga_de(menu: Control) -> CargaEnSegundoPlano:
	return menu.find_children("*", "CargaEnSegundoPlano", true, false)[0]


func _pantallas_visibles(menu: Control) -> int:
	var visibles := 0
	for pantalla: PantallaDeCarga in menu.find_children("*", "PantallaDeCarga", true, false):
		if pantalla.visible:
			visibles += 1
	return visibles


func _elegir_nuevo_juego(menu: Control) -> void:
	var pedidos: PedidosDelMenu = menu.find_children("*", "PedidosDelMenu", true, false)[0]
	pedidos.elegir(MenuDeInicio.Opcion.NUEVO_JUEGO)


func test_cada_menu_nuevo_pide_el_almacen() -> void:
	var primero := _menu()
	assert_bool(_carga_de(primero).is_processing()).is_true()
	remove_child(primero)
	assert_bool(_carga_de(_menu()).is_processing()).is_true()


func test_el_menu_arranca_sin_pantalla_de_carga() -> void:
	assert_int(_pantallas_visibles(_menu())).is_equal(0)


func test_doble_clic_mientras_carga_muestra_una_sola_pantalla() -> void:
	var menu := _menu()
	_elegir_nuevo_juego(menu)
	_elegir_nuevo_juego(menu)
	assert_int(_pantallas_visibles(menu)).is_equal(1)


func test_con_el_almacen_ya_cargado_nuevo_juego_tambien_muestra_la_pantalla() -> void:
	var menu := _menu()
	_carga_de(menu).lista.emit(PackedScene.new())
	_elegir_nuevo_juego(menu)
	assert_int(_pantallas_visibles(menu)).is_equal(1)


func test_si_la_carga_falla_vuelve_al_menu_y_nuevo_juego_pide_otra_vez() -> void:
	var menu := _menu()
	_elegir_nuevo_juego(menu)
	_carga_de(menu).fallo.emit()
	assert_int(_pantallas_visibles(menu)).is_equal(0)
	_elegir_nuevo_juego(menu)
	assert_int(_pantallas_visibles(menu)).is_equal(1)
	assert_bool(_carga_de(menu).is_processing()).is_true()


func test_la_pantalla_de_carga_usa_el_tema_sin_estilos_propios() -> void:
	var texto := FileAccess.get_file_as_string(PANTALLA_DE_CARGA)
	assert_str(texto).contains("res://assets/ui/manada/tema.tres")
	assert_str(texto).not_contains("theme_override_")
