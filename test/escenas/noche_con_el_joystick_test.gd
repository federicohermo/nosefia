## Una noche con joystick: la cruceta y el joystick derecho eligen en cada interfaz, X aprieta, y
## cada interfaz que se abre deja el foco en un control.
##
## Los eventos entran por el viewport, como los del motor: pasan por la cruceta del foco y por las
## acciones de `project.godot`, que es lo que este issue agrega.
extends GdUnitTestSuite

const COMPUTADORA := preload("res://src/ui/diegetica/pantalla_de_computadora.tscn")
const PROGRAMA_DE_TICKETS := preload("res://src/ui/diegetica/programa_de_tickets.tscn")
const CELULAR := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")
const CONFIGURACIONES := "res://src/ui/interrupciones/pantalla_de_configuraciones.tscn"
const CONTROLES := "res://src/ui/interrupciones/pantalla_de_controles.tscn"
const PAUSA := "res://src/ui/interrupciones/menu_de_pausa.tscn"
const C := Preferencias.Campo

var _reanudar: int = 0


func before_test() -> void:
	_reanudar = 0


func after_test() -> void:
	get_tree().paused = false
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	ajuste.aplicar(Preferencias.new())


func _eje(eje: JoyAxis, valor: float) -> InputEventJoypadMotion:
	var evento := InputEventJoypadMotion.new()
	evento.axis = eje
	evento.axis_value = valor
	return evento


func _boton(indice: JoyButton) -> InputEventJoypadButton:
	var evento := InputEventJoypadButton.new()
	evento.button_index = indice
	evento.pressed = true
	return evento


## Un gesto entra por el viewport y se suelta: el motor entrega siempre la pareja.
func _gesto(evento: InputEvent) -> void:
	get_viewport().push_input(evento)
	var soltado := evento.duplicate() as InputEvent
	if soltado is InputEventJoypadButton:
		(soltado as InputEventJoypadButton).pressed = false
	elif soltado is InputEventJoypadMotion:
		(soltado as InputEventJoypadMotion).axis_value = 0.0
	get_viewport().push_input(soltado)


func _foco() -> Control:
	return get_viewport().gui_get_focus_owner()


func _foco_adentro_de(raiz: Node) -> bool:
	var foco := _foco()
	return foco != null and raiz.is_ancestor_of(foco) and foco.is_visible_in_tree()


func test_la_cruceta_el_derecho_y_x_son_las_acciones_de_las_interfaces() -> void:  # AC-CFG-027
	var acciones: Dictionary[StringName, Array] = {
		&"ui_up": [_boton(JOY_BUTTON_DPAD_UP), _eje(JOY_AXIS_RIGHT_Y, -1.0)],
		&"ui_down": [_boton(JOY_BUTTON_DPAD_DOWN), _eje(JOY_AXIS_RIGHT_Y, 1.0)],
		&"ui_left": [_boton(JOY_BUTTON_DPAD_LEFT), _eje(JOY_AXIS_RIGHT_X, -1.0)],
		&"ui_right": [_boton(JOY_BUTTON_DPAD_RIGHT), _eje(JOY_AXIS_RIGHT_X, 1.0)],
		&"ui_accept": [_boton(JOY_BUTTON_A)],
	}
	for accion: StringName in acciones:
		for evento: InputEvent in acciones[accion]:
			assert_bool(InputMap.event_is_action(evento, accion)).is_true()


func test_configuraciones_elige_una_barra_y_los_costados_mueven_un_paso() -> void:  # AC-CFG-027
	var avisos: Array[Preferencias] = []
	var pantalla: PantallaDeConfiguraciones = auto_free(load(CONFIGURACIONES).instantiate())
	add_child(pantalla)
	pantalla.preparar(Preferencias.new())
	pantalla.preferencias_cambiadas.connect(func(p: Preferencias) -> void: avisos.append(p))
	pantalla.abrir()
	assert_object(_foco()).is_instanceof(HSlider)
	assert_bool(_foco_adentro_de(pantalla)).is_true()
	var paso := Preferencias.paso(C.EFECTOS)
	var maximo := Preferencias.maximo(C.EFECTOS)
	_gesto(_eje(JOY_AXIS_RIGHT_X, -1.0))
	assert_int(avisos.size()).is_equal(1)
	assert_float(avisos[0].valor(C.EFECTOS)).is_equal_approx(maximo - paso, 1e-4)
	_gesto(_eje(JOY_AXIS_RIGHT_X, 1.0))
	assert_int(avisos.size()).is_equal(2)
	assert_float(avisos[1].valor(C.EFECTOS)).is_equal_approx(maximo, 1e-4)
	var barra := _foco()
	_gesto(_boton(JOY_BUTTON_DPAD_DOWN))
	assert_object(_foco()).is_not_same(barra)
	assert_bool(_foco_adentro_de(pantalla)).is_true()


func test_la_planilla_elige_por_fila_y_los_costados_suman_y_restan() -> void:  # AC-CFG-027
	var pantalla: PantallaDeComputadora = auto_free(COMPUTADORA.instantiate())
	add_child(pantalla)
	pantalla.mostrar()
	var atender := TareaDeAtender.new(
		[], Apertura.inventario_de_la_jornada(1, [], {}, {}, RandomNumberGenerator.new())
	)
	var registro := RegistroDeVentas.new(Catalogo.todos(), atender)
	var caja := pantalla.caja()
	caja.suma_pedida.connect(func(producto: Producto) -> void: registro.sumar(producto))
	caja.resta_pedida.connect(func(producto: Producto) -> void: registro.restar(producto))
	caja.mostrar(registro)
	var filas := caja.get("_filas") as Container
	var primera := filas.get_child(0) as Control
	var producto: Producto = registro.productos()[0]
	assert_object(_foco()).is_same(primera)
	_gesto(_eje(JOY_AXIS_RIGHT_X, 1.0))
	assert_int(registro.unidades_de(producto)).is_equal(1)
	_gesto(_boton(JOY_BUTTON_DPAD_RIGHT))
	assert_int(registro.unidades_de(producto)).is_equal(2)
	_gesto(_boton(JOY_BUTTON_DPAD_LEFT))
	assert_int(registro.unidades_de(producto)).is_equal(1)
	_gesto(_boton(JOY_BUTTON_DPAD_DOWN))
	assert_object(_foco()).is_same(filas.get_child(1))
	assert_int(registro.unidades_de(registro.productos()[1])).is_zero()
	# Repintar la planilla no le quita el foco al jugador.
	caja.mostrar(registro)
	assert_object(_foco()).is_same(filas.get_child(1))


func test_la_pausa_deja_el_foco_en_un_boton_y_x_lo_aprieta() -> void:  # AC-CFG-027
	var menu: MenuDePausa = auto_free(load(PAUSA).instantiate())
	menu.reanudar_pedido.connect(func() -> void: _reanudar += 1)
	add_child(menu)
	menu.mostrar()
	assert_object(_foco()).is_instanceof(Button)
	assert_bool(_foco_adentro_de(menu)).is_true()
	_gesto(_boton(JOY_BUTTON_A))
	assert_int(_reanudar).is_equal(1)


func test_controles_deja_el_foco_en_un_renglon() -> void:  # AC-CFG-028
	var pantalla: PantallaDeControles = auto_free(load(CONTROLES).instantiate())
	add_child(pantalla)
	pantalla.preparar(AsignacionDeControles.new())
	pantalla.abrir()
	assert_object(_foco()).is_instanceof(Button)
	assert_bool(_foco_adentro_de(pantalla)).is_true()


func test_el_programa_de_tickets_deja_el_foco_en_un_control() -> void:  # AC-CFG-028
	for jornada: int in [1, 3]:
		var vista: ProgramaDeTickets = auto_free(PROGRAMA_DE_TICKETS.instantiate())
		add_child(vista)
		vista.mostrar(GeneradorDeTickets.para_la_jornada(jornada))
		assert_bool(_foco_adentro_de(vista)).is_true()
		vista.ocultar()
		remove_child(vista)


func test_el_celular_deja_el_foco_en_un_chat_al_aparecer() -> void:  # AC-CFG-028
	var pantalla: PantallaDelCelular = auto_free(CELULAR.instantiate())
	add_child(pantalla)
	var conversacion := Conversacion.new()
	conversacion.nombre = "Contacto"
	var mensaje := Mensaje.new()
	mensaje.de_quien = conversacion.nombre
	mensaje.texto = "Hola."
	conversacion.mensajes.append(mensaje)
	pantalla.mostrar_menu(Bandeja.new([conversacion]))
	(pantalla.get("_telefono") as Control).show()
	await await_idle_frame()
	await await_idle_frame()
	assert_object(_foco()).is_instanceof(Button)
	assert_bool(_foco_adentro_de(pantalla.get("_mensajes"))).is_true()
