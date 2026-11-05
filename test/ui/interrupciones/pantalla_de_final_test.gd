## La pantalla de final: su encabezado, su título, su mensaje y dos botones que piden salir.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/pantalla_de_final.tscn"
const FINALES: Array[FinalConPantalla.Cual] = [
	FinalConPantalla.Cual.DESPEDIDO,
	FinalConPantalla.Cual.EMPLEADO_ESTRESADO,
	FinalConPantalla.Cual.LOCURA_PARANOICA,
	FinalConPantalla.Cual.JEFE_SABOTEADOR,
	FinalConPantalla.Cual.JEFE_INCOMPETENTE,
]

var _pedidos: int = 0
var _nuevas: int = 0


func before_test() -> void:
	_pedidos = 0
	_nuevas = 0


func _pantalla() -> PantallaDeFinal:
	var pantalla: PantallaDeFinal = auto_free(load(ESCENA).instantiate())
	pantalla.volver_al_menu_pedido.connect(func() -> void: _pedidos += 1)
	pantalla.nueva_partida_pedida.connect(func() -> void: _nuevas += 1)
	add_child(pantalla)
	return pantalla


func _botones(pantalla: PantallaDeFinal) -> Array[Button]:
	var botones: Array[Button] = []
	for boton: Button in pantalla.find_children("*", "Button", true, false):
		botones.append(boton)
	return botones


func test_arranca_oculta() -> void:
	assert_bool(_pantalla().visible).is_false()


func test_cada_final_tiene_texto() -> void:  # AC-SHF-063 AC-SHF-064 AC-SHF-066 AC-SHF-111
	# AC-SHF-113
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


func test_tiene_dos_botones_y_el_foco_esta_en_el_de_arriba() -> void:  # AC-SHF-127
	var pantalla := _pantalla()
	for final: FinalConPantalla.Cual in FINALES:
		pantalla.mostrar(final)
		var botones := _botones(pantalla)
		assert_int(botones.size()).is_equal(2)
		assert_object(botones[0]).is_same(pantalla.boton_de_nueva_partida())
		assert_object(botones[1]).is_same(pantalla.boton_de_volver())
		assert_str(botones[0].text).is_equal(PantallaDeFinal.TEXTO_DE_NUEVA_PARTIDA)
		assert_str(botones[1].text).is_equal(PantallaDeFinal.TEXTO_DE_VOLVER)
		assert_bool(pantalla.boton_de_nueva_partida().has_focus()).is_true()


func test_el_mensaje_del_despido_es_uno_de_los_tips() -> void:  # AC-SHF-124
	var pantalla := _pantalla()
	pantalla.mostrar(FinalConPantalla.Cual.DESPEDIDO)
	assert_array(FinalConPantalla.TIPS).contains([pantalla.mensaje()])
	var tip := pantalla.mensaje()
	await get_tree().process_frame
	assert_str(pantalla.mensaje()).is_equal(tip)


func test_los_finales_muestran_su_cierre_y_no_un_tip() -> void:  # AC-SHF-125 AC-SHF-126
	var pantalla := _pantalla()
	for final: FinalConPantalla.Cual in FINALES:
		if final == FinalConPantalla.Cual.DESPEDIDO:
			continue
		pantalla.mostrar(final)
		assert_str(pantalla.mensaje()).is_equal(FinalConPantalla.CIERRES.get(final, ""))
		assert_array(FinalConPantalla.TIPS).not_contains([pantalla.mensaje()])


func test_comenzar_nueva_partida_la_pide_una_sola_vez() -> void:  # AC-SHF-128 AC-SHF-130
	var pantalla := _pantalla()
	pantalla.mostrar(FinalConPantalla.Cual.DESPEDIDO)
	pantalla.boton_de_nueva_partida().pressed.emit()
	pantalla.boton_de_nueva_partida().pressed.emit()
	assert_int(_nuevas).is_equal(1)
	assert_int(_pedidos).is_zero()


func test_volver_al_menu_lo_pide_una_sola_vez_y_no_pide_otra_partida() -> void:  # AC-SHF-129
	var pantalla := _pantalla()
	pantalla.mostrar(FinalConPantalla.Cual.DESPEDIDO)
	assert_int(_pedidos).is_zero()
	pantalla.boton_de_volver().pressed.emit()
	pantalla.boton_de_volver().pressed.emit()
	assert_int(_pedidos).is_equal(1)
	assert_int(_nuevas).is_zero()


func test_un_boton_y_despues_el_otro_piden_una_sola_salida() -> void:  # AC-SHF-130
	var pantalla := _pantalla()
	pantalla.mostrar(FinalConPantalla.Cual.DESPEDIDO)
	pantalla.boton_de_nueva_partida().pressed.emit()
	pantalla.boton_de_volver().pressed.emit()
	assert_int(_nuevas).is_equal(1)
	assert_int(_pedidos).is_zero()
	pantalla.mostrar(FinalConPantalla.Cual.DESPEDIDO)
	pantalla.boton_de_volver().pressed.emit()
	pantalla.boton_de_nueva_partida().pressed.emit()
	assert_int(_pedidos).is_equal(1)
	assert_int(_nuevas).is_equal(1)


func test_un_final_sin_pantalla_no_se_dibuja() -> void:
	var pantalla := _pantalla()
	var intentar := func() -> void: pantalla.mostrar(FinalConPantalla.Cual.NINGUNO)
	await assert_error(intentar).is_push_error("Este final no tiene pantalla")
	assert_bool(pantalla.visible).is_false()
