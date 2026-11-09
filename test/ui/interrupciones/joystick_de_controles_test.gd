## La pantalla de controles detecta el joystick: sin uno no se ve ningún botón de joystick y la
## pestaña JOYSTICK queda apagada y avisa; conectarlo la habilita, y desconectarlo la apaga.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/pantalla_de_controles.tscn"
const FORMAS_DEL_TECLADO: Array[GlifoDeEntrada.Forma] = [
	GlifoDeEntrada.Forma.TECLA, GlifoDeEntrada.Forma.MOUSE
]


func _pantalla(conectado: bool, abierta_en_el_joystick: bool = false) -> PantallaDeControles:
	var pantalla: PantallaDeControles = auto_free(load(ESCENA).instantiate())
	add_child(pantalla)
	pantalla.preparar(AsignacionDeControles.new())
	pantalla.poner_joystick_conectado(conectado)
	pantalla.abrir(abierta_en_el_joystick)
	return pantalla


func _pildoras(pantalla: PantallaDeControles) -> Array[GlifoDeEntrada]:
	var pildoras: Array[GlifoDeEntrada] = []
	pildoras.assign(pantalla.get("_pildoras_de_las_pestanas"))
	return pildoras


func _pestana_del_joystick(pantalla: PantallaDeControles) -> Button:
	return pantalla.get("_pestana_del_joystick")


func _aviso_de_conectar(pantalla: PantallaDeControles) -> Label:
	return pantalla.get("_aviso_sin_joystick")


func test_sin_joystick_no_se_ve_ni_l1_ni_r1_junto_a_las_pestanas() -> void:  # AC-CFG-034
	var pantalla := _pantalla(false)
	assert_int(_pildoras(pantalla).size()).is_equal(2)
	for pildora: GlifoDeEntrada in _pildoras(pantalla):
		assert_bool(pildora.is_visible_in_tree()).is_false()
	pantalla.poner_joystick_conectado(true)
	for pildora: GlifoDeEntrada in _pildoras(pantalla):
		assert_bool(pildora.is_visible_in_tree()).is_true()


func test_sin_joystick_la_pestana_se_ve_apagada_y_con_joystick_no() -> void:  # AC-CFG-034
	var pantalla := _pantalla(false)
	var apagada := _pestana_del_joystick(pantalla).modulate.a
	pantalla.poner_joystick_conectado(true)
	assert_bool(apagada < _pestana_del_joystick(pantalla).modulate.a).is_true()
	assert_str(pantalla.aviso_del_joystick()).is_not_empty()
	pantalla.poner_joystick_conectado(false)
	assert_str(pantalla.aviso_del_joystick()).is_empty()


func test_sin_joystick_la_pestana_se_elige_y_avisa_en_vez_de_la_lista() -> void:  # AC-CFG-034
	var pantalla := _pantalla(false)
	var pestana := _pestana_del_joystick(pantalla)
	assert_bool(pestana.disabled).is_false()
	assert_bool(pestana.focus_mode != Control.FOCUS_NONE).is_true()
	assert_bool(_aviso_de_conectar(pantalla).is_visible_in_tree()).is_false()
	pestana.pressed.emit()
	assert_bool(pantalla.pestana_del_joystick()).is_true()
	assert_bool(_aviso_de_conectar(pantalla).is_visible_in_tree()).is_true()
	assert_str(_aviso_de_conectar(pantalla).text).is_not_empty()
	for fila: HBoxContainer in pantalla.filas(true):
		assert_bool(fila.is_visible_in_tree()).is_false()
	for fila: HBoxContainer in pantalla.filas(false):
		assert_bool(fila.is_visible_in_tree()).is_false()


func test_con_joystick_la_pestana_se_elige_y_muestra_sus_acciones() -> void:  # AC-CFG-033
	var pantalla := _pantalla(true)
	for del_joystick: bool in [false, true]:
		var pestana: Button = pantalla.get(
			"_pestana_del_joystick" if del_joystick else "_pestana_del_teclado"
		)
		assert_bool(pestana.focus_mode != Control.FOCUS_NONE).is_true()
		pestana.pressed.emit()
		assert_bool(pantalla.pestana_del_joystick()).is_equal(del_joystick)
		assert_bool(pantalla.filas(del_joystick)[0].is_visible_in_tree()).is_true()
		assert_bool(_aviso_de_conectar(pantalla).is_visible_in_tree()).is_false()


func test_sin_joystick_no_se_ve_ningun_glifo_de_joystick() -> void:  # AC-CFG-034
	var pantalla := _pantalla(false)
	var vistos := 0
	for nodo: Node in pantalla.find_children("*", "GlifoDeEntrada", true, false):
		var glifo := nodo as GlifoDeEntrada
		if glifo.is_visible_in_tree():
			vistos += 1
			assert_array(FORMAS_DEL_TECLADO).contains([glifo.forma])
	assert_int(vistos).is_greater(0)


func test_conectar_con_la_pantalla_abierta_habilita_la_pestana() -> void:  # AC-CFG-034
	var pantalla := _pantalla(false)
	pantalla.poner_joystick_conectado(true)
	assert_bool(pantalla.pestana_del_joystick()).is_false()
	assert_bool(pantalla.filas(false)[0].is_visible_in_tree()).is_true()
	pantalla.elegir_pestana(true)
	assert_bool(pantalla.filas(true)[0].is_visible_in_tree()).is_true()
	assert_bool(_aviso_de_conectar(pantalla).is_visible_in_tree()).is_false()


func test_conectar_estando_en_el_aviso_muestra_las_acciones_de_la_pestana() -> void:  # AC-CFG-034
	var pantalla := _pantalla(false)
	pantalla.elegir_pestana(true)
	pantalla.poner_joystick_conectado(true)
	assert_bool(pantalla.pestana_del_joystick()).is_true()
	assert_bool(pantalla.filas(true)[0].is_visible_in_tree()).is_true()
	assert_bool(_aviso_de_conectar(pantalla).is_visible_in_tree()).is_false()


func test_desconectar_con_joystick_elegida_pasa_a_teclado_y_mouse() -> void:  # AC-CFG-034
	var pantalla := _pantalla(true, true)
	assert_bool(pantalla.pestana_del_joystick()).is_true()
	pantalla.poner_joystick_conectado(false)
	assert_bool(pantalla.pestana_del_joystick()).is_false()
	assert_bool(pantalla.filas(false)[0].is_visible_in_tree()).is_true()
	assert_bool(_aviso_de_conectar(pantalla).is_visible_in_tree()).is_false()
	for pildora: GlifoDeEntrada in _pildoras(pantalla):
		assert_bool(pildora.is_visible_in_tree()).is_false()


func test_desconectar_con_teclado_elegida_no_cambia_de_pestana() -> void:  # AC-CFG-034
	var pantalla := _pantalla(true)
	pantalla.poner_joystick_conectado(false)
	assert_bool(pantalla.pestana_del_joystick()).is_false()


func test_el_ultimo_dispositivo_joystick_sin_joystick_abre_en_teclado() -> void:  # AC-CFG-032
	assert_bool(_pantalla(false, true).pestana_del_joystick()).is_false()
	assert_bool(_pantalla(true, true).pestana_del_joystick()).is_true()
