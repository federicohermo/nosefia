## Los gestos del cursor no son una acción: reasignar Agarrar / Soltar no los mueve del botón
## izquierdo del mouse. Pulsar al comprador sí es Agarrar / Soltar, y sigue a la reasignación.
##
## El `InputMap` es de todo el proceso: cada caso lo deja como en `project.godot` al terminar.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const APP_CAJA := preload("res://src/ui/diegetica/app_caja.tscn")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

## La primera hora en que hay un comprador en la ventanilla de la primera jornada.
const HORA_CON_COMPRADOR := Vector2i(22, 0)

var _entradas: Array[String] = []


func before_test() -> void:
	_entradas = []


func after_test() -> void:
	_aplicar(AsignacionDeControles.new())


func _aplicar(asignacion: AsignacionDeControles) -> void:
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	var preferencias := Preferencias.new()
	preferencias.poner_controles(asignacion)
	ajuste.aplicar(preferencias)


func _agarrar_en_f() -> void:
	var asignacion := AsignacionDeControles.new()
	asignacion.asignar(
		AsignacionDeControles.AGARRAR, 0, AsignacionDeControles.TipoDeEntrada.TECLA, KEY_F
	)
	_aplicar(asignacion)


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	almacen.get("_limpieza").set_physics_process(false)
	return almacen


func _ventanilla_con_comprador() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.nueva())
	add_child(almacen)
	almacen.get_node("Jugador").set_physics_process(false)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.set_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	RelojDePrueba.avanzar_hasta(reloj, HORA_CON_COMPRADOR)
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	puesto.call("abrir")
	return almacen


func test_con_agarrar_en_f_f_atiende_al_comprador_y_el_clic_izquierdo_no() -> void:  # AC-CFG-020
	_agarrar_en_f()
	var almacen := await _ventanilla_con_comprador()
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	var atencion: Atencion = (almacen.get("_atenciones") as Ventanilla).atencion()
	assert_bool(atencion.dialogo().terminado()).is_false()
	var inicial := atencion.dialogo().entrada_actual()
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	puesto.call("_input", clic)
	assert_str(atencion.dialogo().entrada_actual()).is_equal(inicial)
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_F
	tecla.physical_keycode = KEY_F
	tecla.pressed = true
	puesto.call("_input", tecla)
	assert_str(atencion.dialogo().entrada_actual()).is_not_equal(inicial)


func test_con_agarrar_en_f_el_clic_izquierdo_sigue_avanzando_un_dialogo() -> void:  # AC-CFG-020
	_agarrar_en_f()
	var locutor: Locutor = auto_free(Locutor.new())
	locutor.entrada_mostrada.connect(func(entrada: String) -> void: _entradas.append(entrada))
	assert_bool(locutor.abrir(Dialogo.new(PackedStringArray(["Primera", "Segunda"])))).is_true()
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	locutor.recibir(clic)
	assert_array(_entradas).is_equal(["Primera", "Segunda"])


func test_con_agarrar_en_f_arrastrar_con_el_clic_izquierdo_gira_el_examen() -> void:  # AC-CFG-020
	var almacen := await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	var balde: Node3D = almacen.get_node("Objetos/Balde")
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(balde.get("datos"), balde)).is_true()
	var examen: Examen = jugador.get("examen")
	jugador.set("_enfocado", balde)
	var examinar := InputEventAction.new()
	examinar.action = ReglasDeLosObjetos.ACCION_EXAMINAR
	examinar.pressed = true
	jugador.call("_unhandled_input", examinar)
	assert_bool(examen.esta_examinando()).is_true()
	assert_bool(jugador.call("_el_cursor_esta_tomado")).is_false()
	_agarrar_en_f()
	var antes := balde.global_basis
	var arrastre := InputEventMouseMotion.new()
	arrastre.relative = Vector2(80.0, 50.0)
	arrastre.button_mask = MOUSE_BUTTON_MASK_LEFT
	jugador.call("_unhandled_input", arrastre)
	balde.call("_process", 0.016)
	assert_bool(balde.global_basis.is_equal_approx(antes)).is_false()
	jugador.call("_unhandled_input", examinar)
	agarre.soltar(true)


func test_con_agarrar_en_f_el_clic_izquierdo_sigue_arrastrando_la_planilla() -> void:  # AC-CFG-020
	_agarrar_en_f()
	var caja: AppCaja = auto_free(APP_CAJA.instantiate())
	add_child(caja)
	var lista: ScrollContainer = caja.get("_scroll")
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	lista.gui_input.emit(clic)
	assert_int(lista.mouse_default_cursor_shape).is_equal(Control.CURSOR_DRAG)
	clic.pressed = false
	caja.call("_input", clic)
	assert_int(lista.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
