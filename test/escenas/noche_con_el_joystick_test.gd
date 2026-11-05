## Una noche con joystick: la cruceta y el joystick derecho eligen en cada interfaz, X aprieta, y
## cada interfaz que se abre deja el foco en un control.
##
## Los eventos entran por el viewport, como los del motor: pasan por la cruceta del foco y por las
## acciones de `project.godot`, que es lo que este issue agrega.
extends GdUnitTestSuite

const JUGADOR := preload("res://src/escenas/jugador.tscn")
const COMPUTADORA := preload("res://src/ui/diegetica/pantalla_de_computadora.tscn")
const PROGRAMA_DE_TICKETS := preload("res://src/ui/diegetica/programa_de_tickets.tscn")
const CELULAR := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")
const CONFIGURACIONES := "res://src/ui/interrupciones/pantalla_de_configuraciones.tscn"
const CONTROLES := "res://src/ui/interrupciones/pantalla_de_controles.tscn"
const PAUSA := "res://src/ui/interrupciones/menu_de_pausa.tscn"
const C := Preferencias.Campo


func after_test() -> void:
	get_tree().paused = false
	Input.action_release(&"mirar_derecha")
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
	Input.parse_input_event(evento)
	Input.flush_buffered_events()
	var soltado := evento.duplicate() as InputEvent
	if soltado is InputEventJoypadButton:
		(soltado as InputEventJoypadButton).pressed = false
	elif soltado is InputEventJoypadMotion:
		(soltado as InputEventJoypadMotion).axis_value = 0.0
	Input.parse_input_event(soltado)
	Input.flush_buffered_events()


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


func test_configuraciones_elige_una_barra_con_el_paso_de_su_preferencia() -> void:  # AC-CFG-027
	var pantalla: PantallaDeConfiguraciones = auto_free(load(CONFIGURACIONES).instantiate())
	add_child(pantalla)
	pantalla.preparar(Preferencias.new())
	pantalla.abrir()
	var barra := _foco() as HSlider
	assert_object(barra).is_not_null()
	assert_bool(_foco_adentro_de(pantalla)).is_true()
	assert_float(barra.step).is_equal(Preferencias.paso(C.EFECTOS))
	# Abajo pasa a otro renglón: el motor mueve el foco a la barra que tiene debajo.
	var debajo := barra.find_valid_focus_neighbor(SIDE_BOTTOM)
	assert_object(debajo).is_not_null()
	assert_bool(pantalla.is_ancestor_of(debajo)).is_true()
	# Los botones − y + son del clic: la barra es lo único que se elige en su fila.
	for boton: Button in barra.get_parent().find_children("*", "Button", true, false):
		assert_int(boton.focus_mode).is_equal(Control.FOCUS_NONE)


## Configuraciones abierta con los efectos a mitad de la barra, y lo que avisa al cambiar un valor.
func _configuraciones_a_mitad() -> Array:
	var pantalla: PantallaDeConfiguraciones = auto_free(load(CONFIGURACIONES).instantiate())
	add_child(pantalla)
	var preferencias := Preferencias.new()
	preferencias.poner(
		C.EFECTOS, (Preferencias.minimo(C.EFECTOS) + Preferencias.maximo(C.EFECTOS)) / 2.0
	)
	var avisos: Array[Preferencias] = []
	pantalla.preferencias_cambiadas.connect(
		func(nuevas: Preferencias) -> void: avisos.append(nuevas)
	)
	pantalla.preparar(preferencias)
	pantalla.abrir()
	return [pantalla, preferencias, avisos]


func test_los_costados_suben_y_bajan_la_barra_un_paso() -> void:  # AC-CFG-027
	var armado := _configuraciones_a_mitad()
	var mitad: float = (armado[1] as Preferencias).valor(C.EFECTOS)
	var avisos: Array[Preferencias] = armado[2]
	_gesto(_boton(JOY_BUTTON_DPAD_RIGHT))
	assert_float(avisos[-1].valor(C.EFECTOS)).is_equal_approx(
		mitad + Preferencias.paso(C.EFECTOS), 1e-5
	)
	_gesto(_eje(JOY_AXIS_RIGHT_X, -1.0))
	assert_float(avisos[-1].valor(C.EFECTOS)).is_equal_approx(mitad, 1e-5)


## Baja con la cruceta hasta que el foco entra a `fila`, y contesta si llegó.
func _bajar_hasta(pantalla: PantallaDeConfiguraciones, fila: Container) -> bool:
	for _paso in pantalla.filas().size():
		if _foco_adentro_de(fila):
			break
		_gesto(_boton(JOY_BUTTON_DPAD_DOWN))
	return _foco_adentro_de(fila)


func test_en_las_filas_sin_mas_ni_menos_los_costados_no_hacen_nada() -> void:  # AC-CFG-027
	var armado := _configuraciones_a_mitad()
	await await_idle_frame()
	var pantalla: PantallaDeConfiguraciones = armado[0]
	var avisos: Array[Preferencias] = armado[2]
	for fila: Container in pantalla.filas().slice(Preferencias.CAMPOS.size()):
		assert_bool(_bajar_hasta(pantalla, fila)).is_true()
		var foco := _foco()
		_gesto(_boton(JOY_BUTTON_DPAD_RIGHT))
		_gesto(_eje(JOY_AXIS_RIGHT_X, 1.0))
		_gesto(_boton(JOY_BUTTON_DPAD_LEFT))
		assert_object(_foco()).is_same(foco)
	assert_array(avisos).is_empty()


## La planilla de ventas abierta, con su registro: lo que suman y restan sus filas queda ahí.
func _planilla() -> Array:
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
	return [caja, registro]


func test_la_planilla_elige_por_fila_y_los_costados_suman_y_restan() -> void:  # AC-CFG-027
	var planilla := _planilla()
	var caja: AppCaja = planilla[0]
	var registro: RegistroDeVentas = planilla[1]
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
	# Abajo pasa a la fila siguiente, y repintar la planilla no le quita el foco al jugador.
	await await_idle_frame()
	assert_object(primera.find_valid_focus_neighbor(SIDE_BOTTOM)).is_same(filas.get_child(1))
	filas.get_child(1).grab_focus()
	caja.mostrar(registro)
	assert_object(_foco()).is_same(filas.get_child(1))


func test_a_la_izquierda_en_cero_la_planilla_no_resta() -> void:  # AC-CFG-027
	var planilla := _planilla()
	var registro: RegistroDeVentas = planilla[1]
	var producto: Producto = registro.productos()[0]
	assert_int(registro.unidades_de(producto)).is_zero()
	_gesto(_boton(JOY_BUTTON_DPAD_LEFT))
	_gesto(_eje(JOY_AXIS_RIGHT_X, -1.0))
	assert_int(registro.unidades_de(producto)).is_zero()


func test_la_pausa_deja_el_foco_en_un_boton_que_x_aprieta() -> void:  # AC-CFG-027
	var menu: MenuDePausa = auto_free(load(PAUSA).instantiate())
	add_child(menu)
	menu.mostrar()
	assert_object(_foco()).is_instanceof(Button)
	assert_bool(_foco_adentro_de(menu)).is_true()
	# X es la acción de aceptar: con el foco en el botón, el motor lo aprieta.
	assert_bool(InputMap.event_is_action(_boton(JOY_BUTTON_A), &"ui_accept")).is_true()
	assert_bool((_foco() as Button).disabled).is_false()


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


func test_el_foco_no_se_queda_en_un_boton_que_se_deshabilita() -> void:  # AC-CFG-028
	var raiz: Control = auto_free(Control.new())
	var primero := Button.new()
	var segundo := Button.new()
	raiz.add_child(primero)
	raiz.add_child(segundo)
	add_child(raiz)
	segundo.grab_focus()
	segundo.disabled = true
	assert_object(FocoDeLaInterfaz.en_el_primero(raiz)).is_same(primero)
	assert_object(_foco()).is_same(primero)


func test_la_lista_de_tickets_enfoca_un_item_y_el_foco_vuelve_al_selector() -> void:  # AC-CFG-028
	for elegir_con_x: bool in [true, false]:
		var vista: ProgramaDeTickets = auto_free(PROGRAMA_DE_TICKETS.instantiate())
		add_child(vista)
		vista.mostrar(GeneradorDeTickets.para_la_jornada(6))
		var selector := vista.selectores[0]
		var cabecera: Button = selector.get_node("Cabecera")
		cabecera.pressed.emit()
		assert_bool(selector.esta_abierta()).is_true()
		assert_bool(_foco_adentro_de(selector.get_node("Lista"))).is_true()
		if elegir_con_x:
			_gesto(_boton(JOY_BUTTON_A))
		else:
			assert_bool(vista.cerrar_las_listas_abiertas()).is_true()
		assert_bool(selector.esta_abierta()).is_false()
		assert_object(_foco()).is_same(cabecera)
		vista.ocultar()
		remove_child(vista)


## Toda interfaz abierta suspende al jugador: es lo que impide que el joystick derecho gire la vista.
func test_con_una_interfaz_abierta_la_vista_no_gira() -> void:  # AC-CFG-027
	var jugador: CharacterBody3D = auto_free(JUGADOR.instantiate())
	var control: ControlDelJugador = jugador.get("_control")
	Input.action_press(&"mirar_derecha", 1.0)
	jugador.call("suspender")
	var yaw := control.yaw()
	jugador.call("_mirar_con_el_joystick", 0.5)
	assert_float(control.yaw()).is_equal(yaw)
	# La premisa: el mismo joystick, con la interfaz cerrada, sí gira la vista.
	jugador.call("reanudar")
	jugador.call("_mirar_con_el_joystick", 0.5)
	assert_float(control.yaw()).is_not_equal(yaw)
