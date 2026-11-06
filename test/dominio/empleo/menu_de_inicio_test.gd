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


func test_nuevo_juego_configuraciones_y_salir_estan_habilitadas() -> void:  # AC-CFG-010
	var menu := MenuDeInicio.new(false)
	assert_bool(menu.habilitada(MenuDeInicio.Opcion.NUEVO_JUEGO)).is_true()
	assert_bool(menu.habilitada(MenuDeInicio.Opcion.CONFIGURACIONES)).is_true()
	assert_bool(menu.habilitada(MenuDeInicio.Opcion.SALIR)).is_true()


func test_con_guardado_continuar_se_habilita() -> void:
	assert_bool(MenuDeInicio.new(false, true).habilitada(MenuDeInicio.Opcion.CONTINUAR)).is_true()


func test_sin_guardado_continuar_se_ve_deshabilitada() -> void:
	var menu := MenuDeInicio.new(false)
	assert_bool(menu.opciones().has(MenuDeInicio.Opcion.CONTINUAR)).is_true()
	assert_bool(menu.habilitada(MenuDeInicio.Opcion.CONTINUAR)).is_false()


func test_logros_se_habilita_con_o_sin_guardado() -> void:  # AC-ACH-014
	for hay_guardado: bool in [false, true]:
		var menu := MenuDeInicio.new(false, hay_guardado)
		assert_bool(menu.opciones().has(MenuDeInicio.Opcion.LOGROS)).is_true()
		assert_bool(menu.habilitada(MenuDeInicio.Opcion.LOGROS)).is_true()
