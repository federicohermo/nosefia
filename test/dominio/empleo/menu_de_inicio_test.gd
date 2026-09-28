## Qué opciones muestra el menú de inicio y cuáles se pueden elegir, sin levantar la escena.
extends GdUnitTestSuite

const TODAS: Array[MenuDeInicio.Opcion] = [
	MenuDeInicio.Opcion.CONTINUAR,
	MenuDeInicio.Opcion.NUEVO_JUEGO,
	MenuDeInicio.Opcion.LOGROS,
	MenuDeInicio.Opcion.CONFIGURACIONES,
	MenuDeInicio.Opcion.SALIR,
]


func test_fuera_de_la_web_muestra_las_cinco_opciones_en_orden() -> void:
	assert_array(MenuDeInicio.new(false).opciones()).is_equal(TODAS)


func test_la_web_no_ofrece_salir() -> void:  # AC-SAV-016
	var en_la_web := MenuDeInicio.new(true).opciones()
	var fuera := MenuDeInicio.new(false).opciones()
	fuera.erase(MenuDeInicio.Opcion.SALIR)
	assert_int(en_la_web.size()).is_equal(4)
	assert_array(en_la_web).is_equal(fuera)
	assert_array(en_la_web).not_contains([MenuDeInicio.Opcion.SALIR])


func test_nuevo_juego_y_salir_estan_habilitadas() -> void:
	var menu := MenuDeInicio.new(false)
	assert_bool(menu.habilitada(MenuDeInicio.Opcion.NUEVO_JUEGO)).is_true()
	assert_bool(menu.habilitada(MenuDeInicio.Opcion.SALIR)).is_true()


func test_con_guardado_continuar_se_habilita() -> void:
	assert_bool(MenuDeInicio.new(false, true).habilitada(MenuDeInicio.Opcion.CONTINUAR)).is_true()


func test_nuevo_juego_pide_confirmacion_solo_con_guardado() -> void:
	assert_bool(MenuDeInicio.new(false, true).nuevo_juego_pide_confirmacion()).is_true()
	assert_bool(MenuDeInicio.new(false, false).nuevo_juego_pide_confirmacion()).is_false()


func test_continuar_configuraciones_y_logros_se_ven_deshabilitadas() -> void:
	var menu := MenuDeInicio.new(false)
	for opcion: MenuDeInicio.Opcion in [
		MenuDeInicio.Opcion.CONTINUAR,
		MenuDeInicio.Opcion.CONFIGURACIONES,
		MenuDeInicio.Opcion.LOGROS,
	]:
		assert_bool(menu.opciones().has(opcion)).is_true()
		assert_bool(menu.habilitada(opcion)).is_false()
