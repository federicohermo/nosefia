extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/programa_de_tickets.tscn")


func _selector() -> SelectorDeRenglon:
	var pantalla: SubViewport = auto_free(SubViewport.new())
	pantalla.size = Vector2i(1920, 1080)
	add_child(pantalla)
	var vista: ProgramaDeTickets = ESCENA.instantiate()
	pantalla.add_child(vista)
	vista.mostrar(GeneradorDeTickets.para_la_jornada(6))
	return vista.selectores[0]


func _cabecera(selector: SelectorDeRenglon) -> Button:
	return selector.find_child("Cabecera", true, false) as Button


func _foco_del(selector: SelectorDeRenglon) -> Control:
	return selector.get_viewport().gui_get_focus_owner()


func test_abrir_la_lista_pone_el_foco_en_un_producto_sin_dibujarlo() -> void:  # AC-CFG-028
	var selector := _selector()
	_cabecera(selector).pressed.emit()
	await selector.animacion_terminada
	var foco := _foco_del(selector)
	assert_object(foco).is_not_null()
	assert_bool(foco != null and foco != _cabecera(selector)).is_true()
	assert_bool(foco != null and foco.has_focus()).is_true()
	assert_bool(foco != null and foco.has_focus(true)).is_false()


func test_cerrar_la_lista_devuelve_el_foco_a_la_cabecera_sin_dibujarlo() -> void:  # AC-CFG-028
	var selector := _selector()
	_cabecera(selector).pressed.emit()
	await selector.animacion_terminada
	selector.cerrar()
	var cabecera := _cabecera(selector)
	assert_object(_foco_del(selector)).is_same(cabecera)
	assert_bool(cabecera.has_focus()).is_true()
	assert_bool(cabecera.has_focus(true)).is_false()
