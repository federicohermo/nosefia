## El nodo de la pausa: traduce Esc y el cursor a la pregunta del dominio, y pausa el árbol.
extends GdUnitTestSuite

var _pausas: int = 0
var _reanudaciones: int = 0
var _menus: int = 0
var _cierres: int = 0


func before_test() -> void:
	_pausas = 0
	_reanudaciones = 0
	_menus = 0
	_cierres = 0


func after_test() -> void:
	get_tree().paused = false


func _control(placa: CanvasLayer = null, configuraciones: CanvasLayer = null) -> ControlDePausa:
	var control: ControlDePausa = auto_free(ControlDePausa.new())
	control.placa = placa
	control.configuraciones = configuraciones
	control.cierre_de_configuraciones_pedido.connect(func() -> void: _cierres += 1)
	control.pausado.connect(func() -> void: _pausas += 1)
	control.reanudado.connect(func() -> void: _reanudaciones += 1)
	control.volver_al_menu_pedido.connect(func() -> void: _menus += 1)
	add_child(control)
	return control


func _esc() -> InputEventAction:
	var evento := InputEventAction.new()
	evento.action = &"ui_cancel"
	evento.pressed = true
	return evento


func test_esc_pausa_el_arbol_y_otro_esc_lo_reanuda() -> void:  # AC-SAV-018
	var control := _control()
	control._input(_esc())
	assert_bool(get_tree().paused).is_true()
	assert_int(_pausas).is_equal(1)
	control._input(_esc())
	assert_bool(get_tree().paused).is_false()
	assert_int(_reanudaciones).is_equal(1)
	assert_int(_pausas).is_equal(1)


func test_el_nodo_corre_tambien_en_pausa() -> void:
	var control := _control()
	assert_int(control.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_con_la_placa_en_pantalla_esc_pausa_y_otro_esc_reanuda() -> void:  # AC-SAV-018
	var placa: CanvasLayer = auto_free(CanvasLayer.new())
	placa.visible = true
	var control := _control(placa)
	control._input(_esc())
	assert_bool(get_tree().paused).is_true()
	assert_int(_pausas).is_equal(1)
	control._input(_esc())
	assert_bool(get_tree().paused).is_false()
	assert_int(_reanudaciones).is_equal(1)
	assert_bool(placa.visible).is_true()


func test_con_la_placa_en_pantalla_perder_el_cursor_no_pausa() -> void:  # AC-SAV-018
	var placa: CanvasLayer = auto_free(CanvasLayer.new())
	placa.visible = true
	var control := _control(placa)
	control.set("_cursor_antes", true)
	control.call("_mirar_el_cursor")
	assert_bool(get_tree().paused).is_false()
	assert_int(_pausas).is_zero()


func test_perder_el_cursor_que_el_juego_tenia_tomado_pausa() -> void:  # AC-SAV-018
	# En headless el motor nunca tiene el cursor tomado: lo de antes se escribe a mano, y lo de
	# ahora es lo que contesta el motor, suelto.
	var control := _control()
	control.set("_cursor_antes", true)
	control.call("_mirar_el_cursor")
	assert_bool(get_tree().paused).is_true()
	assert_int(_pausas).is_equal(1)


func test_el_cursor_que_suelta_el_juego_no_pausa() -> void:  # AC-SAV-018
	# Lo de antes se mide después de que el juego escribe: si el juego lo soltó, ya estaba suelto.
	var control := _control()
	control._physics_process(0.0)
	control.call("_mirar_el_cursor")
	assert_bool(get_tree().paused).is_false()
	assert_int(_pausas).is_zero()


func test_cambiar_de_ventana_no_pausa_y_esc_sigue_pausando() -> void:  # AC-SAV-018
	var control := _control()
	control.set("_cursor_antes", true)
	control.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	control.call("_mirar_el_cursor")
	assert_bool(get_tree().paused).is_false()
	control.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	control.call("_mirar_el_cursor")
	assert_bool(get_tree().paused).is_false()
	control._input(_esc())
	assert_bool(get_tree().paused).is_true()
	control._input(_esc())
	assert_bool(get_tree().paused).is_false()


func test_volver_al_menu_sale_de_la_pausa_y_pide_el_menu_una_vez() -> void:  # AC-SAV-020
	var control := _control()
	control._input(_esc())
	control.pedir_volver_al_menu()
	control.pedir_volver_al_menu()
	assert_bool(get_tree().paused).is_false()
	assert_int(_menus).is_equal(1)


func test_reanudar_fuera_de_la_pausa_no_avisa() -> void:
	var control := _control()
	control.reanudar()
	assert_int(_reanudaciones).is_zero()


## Al volver al menú, el almacén sale del árbol unos cuadros antes de liberarse. Si en esos
## cuadros el nodo sigue mirando el cursor, lee la pausa de un árbol nulo.
func test_fuera_del_arbol_deja_de_mirar_el_cursor() -> void:
	var control := _control()
	var arbol := get_tree()
	remove_child(control)
	assert_bool(arbol.physics_frame.is_connected(control._mirar_el_cursor)).is_false()


func test_con_configuraciones_abierta_esc_la_cierra_y_sigue_en_pausa() -> void:  # AC-SAV-018
	var configuraciones: CanvasLayer = auto_free(CanvasLayer.new())
	configuraciones.visible = false
	var control := _control(null, configuraciones)
	control.cierre_de_configuraciones_pedido.connect(configuraciones.hide)
	control._input(_esc())
	configuraciones.show()
	control._input(_esc())
	assert_int(_cierres).is_equal(1)
	assert_bool(configuraciones.visible).is_false()
	assert_bool(get_tree().paused).is_true()
	assert_int(_reanudaciones).is_zero()
	control._input(_esc())
	assert_bool(get_tree().paused).is_false()
	assert_int(_reanudaciones).is_equal(1)


func _celular_abierto(fijo: bool) -> CelularDelEmpleado:
	var celular: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	if fijo:
		celular.mostrar_fijo(Conversacion.Interlocutor.JEFE)
	else:
		celular.abrir_jornada(1)
		celular.pedir_alternar(false)
	return celular


func test_con_el_celular_libre_abierto_esc_lo_cierra_y_no_pausa() -> void:  # AC-INV-070
	var control := _control()
	control.celular = _celular_abierto(false)
	var devueltos: Array[int] = []
	control.esc_atendido_por_el_celular.connect(func() -> void: devueltos.append(1))
	control._input(_esc())
	assert_bool(control.celular.celular().abierto()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(_pausas).is_zero()
	assert_array(devueltos).is_equal([1])
	control._input(_esc())
	assert_bool(get_tree().paused).is_true()
	assert_int(_pausas).is_equal(1)
	assert_array(devueltos).is_equal([1])


func test_con_el_celular_fijo_esc_pausa_y_lo_deja_abierto() -> void:  # AC-INV-072
	var control := _control()
	control.celular = _celular_abierto(true)
	control._input(_esc())
	assert_bool(get_tree().paused).is_true()
	assert_bool(control.celular.celular().abierto()).is_true()
	control._input(_esc())
	assert_bool(get_tree().paused).is_false()
	assert_bool(control.celular.celular().abierto()).is_true()


## Una interfaz de prueba: abierta hasta que Esc la cierra, con su cursor devuelto al juego.
class InterfazDePrueba:
	var abierta := true
	var cierres: int = 0

	func esta_abierta() -> bool:
		return abierta

	func cerrar_con_esc() -> void:
		abierta = false
		cierres += 1


func test_con_una_interfaz_abierta_esc_la_cierra_y_el_siguiente_pausa() -> void:  # AC-PLY-167
	var control := _control()
	var interfaz := InterfazDePrueba.new()
	control.registrar_interfaz(interfaz.esta_abierta, interfaz.cerrar_con_esc)
	control._input(_esc())
	assert_int(interfaz.cierres).is_equal(1)
	assert_bool(get_tree().paused).is_false()
	assert_int(_pausas).is_zero()
	control._input(_esc())
	assert_int(interfaz.cierres).is_equal(1)
	assert_bool(get_tree().paused).is_true()
	assert_int(_pausas).is_equal(1)


func test_cada_interfaz_registrada_se_cierra_sola() -> void:  # AC-PLY-166
	var control := _control()
	var cerrada := InterfazDePrueba.new()
	cerrada.abierta = false
	var abierta := InterfazDePrueba.new()
	control.registrar_interfaz(cerrada.esta_abierta, cerrada.cerrar_con_esc)
	control.registrar_interfaz(abierta.esta_abierta, abierta.cerrar_con_esc)
	control._input(_esc())
	assert_int(cerrada.cierres).is_zero()
	assert_int(abierta.cierres).is_equal(1)
	assert_bool(get_tree().paused).is_false()


func test_en_pausa_esc_reanuda_y_no_cierra_la_interfaz() -> void:  # AC-PLY-169
	var control := _control()
	var interfaz := InterfazDePrueba.new()
	control.registrar_interfaz(interfaz.esta_abierta, interfaz.cerrar_con_esc)
	control.pausar()
	control._input(_esc())
	assert_bool(get_tree().paused).is_false()
	assert_int(interfaz.cierres).is_zero()
	assert_bool(interfaz.abierta).is_true()


func test_el_cursor_que_suelta_el_esc_de_la_interfaz_no_pausa() -> void:  # AC-PLY-170
	var control := _control()
	var interfaz := InterfazDePrueba.new()
	control.registrar_interfaz(interfaz.esta_abierta, interfaz.cerrar_con_esc)
	control._cursor_antes = true
	control._input(_esc())
	control._mirar_el_cursor()
	assert_bool(get_tree().paused).is_false()
	assert_int(_pausas).is_zero()


func test_con_logros_abierta_esc_la_cierra_y_sigue_en_pausa() -> void:  # AC-SAV-036
	var logros: CanvasLayer = auto_free(CanvasLayer.new())
	logros.visible = false
	var control := _control()
	control.logros = logros
	var cierres_de_logros: Array[int] = []
	control.cierre_de_logros_pedido.connect(
		func() -> void:
			cierres_de_logros.append(1)
			logros.hide()
	)
	control._input(_esc())
	logros.show()
	control._input(_esc())
	assert_int(cierres_de_logros.size()).is_equal(1)
	assert_bool(logros.visible).is_false()
	assert_bool(get_tree().paused).is_true()
	assert_int(_reanudaciones).is_zero()
	control._input(_esc())
	assert_bool(get_tree().paused).is_false()
