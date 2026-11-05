## La pantalla de final: su encabezado, su título y un solo botón que pide volver al menú.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/pantalla_de_final.tscn"
const FINALES: Array[FinalConPantalla.Cual] = [
	FinalConPantalla.Cual.DESPEDIDO,
	FinalConPantalla.Cual.EMPLEADO_ESTRESADO,
	FinalConPantalla.Cual.JEFE_SABOTEADOR,
]

var _pedidos: int = 0


func before_test() -> void:
	_pedidos = 0


func _pantalla() -> PantallaDeFinal:
	var pantalla: PantallaDeFinal = auto_free(load(ESCENA).instantiate())
	pantalla.volver_al_menu_pedido.connect(func() -> void: _pedidos += 1)
	add_child(pantalla)
	return pantalla


func _botones(pantalla: PantallaDeFinal) -> Array[Button]:
	var botones: Array[Button] = []
	for boton: Button in pantalla.find_children("*", "Button", true, false):
		botones.append(boton)
	return botones


func test_arranca_oculta() -> void:
	assert_bool(_pantalla().visible).is_false()


func test_cada_final_dibuja_su_encabezado_y_titulo() -> void:  # AC-SHF-063 AC-SHF-064 AC-SHF-111
	var pantalla := _pantalla()
	var titulos: Array[String] = []
	for final: FinalConPantalla.Cual in FINALES:
		pantalla.mostrar(final)
		assert_bool(pantalla.visible).is_true()
		assert_str(pantalla.encabezado()).is_equal(PantallaDeFinal.ENCABEZADOS[final])
		assert_str(pantalla.titulo()).is_equal(PantallaDeFinal.TITULOS[final])
		assert_str(pantalla.encabezado()).is_not_empty()
		titulos.append(pantalla.titulo())
	assert_int(titulos.size()).is_equal(FINALES.size())
	for titulo: String in titulos:
		assert_int(titulos.count(titulo)).is_equal(1)


func test_tiene_un_solo_boton_y_es_el_de_volver() -> void:  # AC-SHF-063 AC-SHF-064 AC-SHF-111
	var pantalla := _pantalla()
	for final: FinalConPantalla.Cual in FINALES:
		pantalla.mostrar(final)
		var botones := _botones(pantalla)
		assert_int(botones.size()).is_equal(1)
		assert_str(botones[0].text).is_equal(MenuDePausa.TEXTO_DE_VOLVER_AL_MENU)


func test_pulsar_el_boton_dos_veces_pide_el_menu_una_sola_vez() -> void:  # AC-SHF-067
	var pantalla := _pantalla()
	pantalla.mostrar(FinalConPantalla.Cual.DESPEDIDO)
	assert_int(_pedidos).is_zero()
	pantalla.boton().pressed.emit()
	pantalla.boton().pressed.emit()
	assert_int(_pedidos).is_equal(1)


func test_el_boton_recibe_el_foco_al_mostrarse() -> void:
	var pantalla := _pantalla()
	pantalla.mostrar(FinalConPantalla.Cual.EMPLEADO_ESTRESADO)
	assert_bool(pantalla.boton().has_focus()).is_true()


func test_un_final_sin_pantalla_no_se_dibuja() -> void:
	var pantalla := _pantalla()
	var intentar := func() -> void: pantalla.mostrar(FinalConPantalla.Cual.NINGUNO)
	await assert_error(intentar).is_push_error("Este final no tiene pantalla")
	assert_bool(pantalla.visible).is_false()
