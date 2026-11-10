## El nombre de cada acción reasignable dice las funciones de menú que esa acción hace: la entrada
## que la acción tiene es también la que cierra, vuelve o pulsa en una interfaz.
extends GdUnitTestSuite

const CERRAR := AsignacionDeControles.FuncionDeMenu.CERRAR
const VOLVER := AsignacionDeControles.FuncionDeMenu.VOLVER
const PULSAR := AsignacionDeControles.FuncionDeMenu.PULSAR

## Lo que la auditoría de quién lee cada acción encontró. Las demás acciones no hacen nada en una
## interfaz.
const AUDITORIA: Dictionary = {
	AsignacionDeControles.CELULAR: [CERRAR],
	AsignacionDeControles.AGARRAR: [PULSAR],
	AsignacionDeControles.INTERACTUAR: [CERRAR],
	AsignacionDeControles.PAUSA: [VOLVER],
}


func test_el_nombre_de_cada_accion_incluye_sus_funciones_de_menu() -> void:  # AC-CFG-042
	for accion: StringName in AUDITORIA:
		var nombre := AsignacionDeControles.nombre_de_la_accion(accion)
		var encontradas: Array = AUDITORIA[accion]
		for funcion: AsignacionDeControles.FuncionDeMenu in encontradas:
			assert_str(nombre).contains(AsignacionDeControles.texto_de_la_funcion(funcion))


func test_una_accion_dice_las_funciones_que_hace_y_ninguna_mas() -> void:  # AC-CFG-042
	for accion: StringName in AsignacionDeControles.ACCIONES:
		var esperadas: Array = AUDITORIA.get(accion, [])
		assert_array(AsignacionDeControles.funciones_de_menu(accion)).contains_exactly_in_any_order(
			esperadas
		)


func test_una_accion_sin_funcion_de_menu_conserva_su_nombre() -> void:  # AC-CFG-042
	for accion: StringName in AsignacionDeControles.ACCIONES:
		if AUDITORIA.has(accion):
			continue
		assert_str(AsignacionDeControles.nombre_de_la_accion(accion)).is_equal(
			AsignacionDeControles.NOMBRES[accion]
		)


func test_cada_funcion_de_menu_tiene_su_texto_y_no_se_repite() -> void:  # AC-CFG-042
	var vistos: Dictionary = {}
	for funcion: AsignacionDeControles.FuncionDeMenu in (
		AsignacionDeControles.FuncionDeMenu.values()
	):
		var texto := AsignacionDeControles.texto_de_la_funcion(funcion)
		assert_str(texto).is_not_empty()
		assert_bool(vistos.has(texto)).is_false()
		vistos[texto] = true
