## CÍRCULO vuelve un paso atrás en Configuraciones y en la pantalla de controles, desde la pausa y
## desde el menú de inicio; y mientras la pantalla de controles espera un botón, CÍRCULO se asigna.
##
## Los eventos entran por el viewport, como los del motor: pasan por el orden real de los nodos.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const ESCENA_DEL_MENU := "res://src/escenas/menu_de_inicio.tscn"

var _ruta: String


func before_test() -> void:
	_ruta = create_temp_dir("menu").path_join("partida.guardado")


func after_test() -> void:
	get_tree().paused = false
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	ajuste.aplicar(Preferencias.new())


func _circulo() -> InputEventJoypadButton:
	var evento := InputEventJoypadButton.new()
	evento.button_index = JOY_BUTTON_B
	evento.pressed = true
	return evento


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	(almacen.get_node("Jugador") as Node3D).set_physics_process(false)
	for _cuadro in 4:
		await get_tree().physics_frame
	return almacen


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


func _controles_de(configuraciones: PantallaDeConfiguraciones) -> PantallaDeControles:
	(configuraciones.get("_ajustar_controles") as Button).pressed.emit()
	return configuraciones.get("_controles")


func test_circulo_en_la_captura_desde_la_pausa_se_asigna() -> void:  # AC-SAV-046, AC-CFG-026
	var almacen := await _almacen()
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	var configuraciones: PantallaDeConfiguraciones = (
		(almacen.get_node("Interfaz/MenuDePausa") as MenuDePausa).configuraciones()
	)
	pausa.pausar()
	configuraciones.abrir()
	var controles := _controles_de(configuraciones)
	controles.elegir(AsignacionDeControles.AGARRAR, AsignacionDeControles.RANURA_DEL_JOYSTICK)
	assert_bool(controles.capturando()).is_true()
	get_viewport().push_input(_circulo())
	assert_bool(controles.capturando()).is_false()
	assert_bool(controles.visible).is_true()
	assert_bool(configuraciones.visible).is_true()
	var asignado := PantallaDeControles.nombre_de_la_entrada(
		AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK, JOY_BUTTON_B
	)
	(
		assert_str(
			controles.texto_de(
				AsignacionDeControles.AGARRAR, AsignacionDeControles.RANURA_DEL_JOYSTICK
			)
		)
		. is_equal(asignado)
	)


func test_circulo_desde_la_pausa_vuelve_un_paso_a_la_vez() -> void:  # AC-SAV-046
	var almacen := await _almacen()
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	var configuraciones: PantallaDeConfiguraciones = (
		(almacen.get_node("Interfaz/MenuDePausa") as MenuDePausa).configuraciones()
	)
	pausa.pausar()
	configuraciones.abrir()
	var controles := _controles_de(configuraciones)
	get_viewport().push_input(_circulo())
	assert_bool(controles.visible).is_false()
	assert_bool(configuraciones.visible).is_true()
	get_viewport().push_input(_circulo())
	assert_bool(configuraciones.visible).is_false()
	assert_bool(get_tree().paused).is_true()


func test_circulo_en_el_menu_de_inicio_vuelve_un_paso_a_la_vez() -> void:  # AC-SAV-046
	var menu := _menu()
	var configuraciones: PantallaDeConfiguraciones = menu.get("_configuraciones")
	_boton(menu, "CONFIGURACIONES").pressed.emit()
	var controles := _controles_de(configuraciones)
	assert_bool(controles.visible).is_true()
	get_viewport().push_input(_circulo())
	assert_bool(controles.visible).is_false()
	assert_bool(configuraciones.visible).is_true()
	get_viewport().push_input(_circulo())
	assert_bool(configuraciones.visible).is_false()
	assert_bool((menu.get("_marco") as Control).visible).is_true()


func test_circulo_en_el_menu_durante_la_captura_no_cierra() -> void:  # AC-SAV-046
	var menu := _menu()
	var configuraciones: PantallaDeConfiguraciones = menu.get("_configuraciones")
	_boton(menu, "CONFIGURACIONES").pressed.emit()
	var controles := _controles_de(configuraciones)
	controles.elegir(AsignacionDeControles.AGARRAR, AsignacionDeControles.RANURA_DE_WASD)
	get_viewport().push_input(_circulo())
	assert_bool(controles.visible).is_true()
	assert_bool(configuraciones.visible).is_true()
	assert_bool((menu.get("_marco") as Control).visible).is_false()
