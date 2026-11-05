## Pulsar al comprador en la ventanilla con el joystick: lo hace el botón de Agarrar / Soltar, que
## de fábrica es X. Los eventos entran por el viewport, como los del motor.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Puesto := preload("res://src/escenas/puestos/ventanilla.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

var _almacen: Node3D


func after_test() -> void:
	get_tree().paused = false
	_almacen.get_node("Servicios/AudioDelAlmacen/Reproductor").silenciar()
	_almacen.queue_free()
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	ajuste.aplicar(Preferencias.new())
	for _cuadro in 4:
		await get_tree().process_frame


## La ventanilla abierta con un comprador esperando, sin que corra el reloj.
func _atender() -> Ventanilla:
	_almacen = ALMACEN.instantiate()
	_almacen.set("_partida", Partida.nueva())
	add_child(_almacen)
	_almacen.get_node("Jugador").set_physics_process(false)
	_almacen.get_node("Servicios/RelojDelTurno").set_process(false)
	for _cuadro in 3:
		await get_tree().physics_frame
	RelojDePrueba.avanzar_hasta(_almacen.get("_reloj"), Vector2i(22, 0))
	(_almacen.get_node("Estructura/Ventanilla") as Puesto).abrir()
	return _almacen.get("_atenciones")


func _apretar(boton: JoyButton) -> void:
	var evento := InputEventJoypadButton.new()
	evento.button_index = boton
	for presionado: bool in [true, false]:
		evento.pressed = presionado
		get_viewport().push_input(evento)


## Cuántas conversaciones empezó el comprador: el primer pulso lo hace hablar.
func _conversaciones(atenciones: Ventanilla) -> Array[int]:
	var contador: Array[int] = [0]
	atenciones.conversacion_iniciada.connect(func(_comprador: Comprador) -> void: contador[0] += 1)
	return contador


func test_x_pulsa_al_comprador_en_la_ventanilla() -> void:  # AC-CFG-029
	var atenciones := await _atender()
	assert_object(atenciones.atencion()).is_not_null()
	var conversaciones := _conversaciones(atenciones)
	_apretar(JOY_BUTTON_A)
	assert_int(conversaciones[0]).is_equal(1)


func test_con_agarrar_en_l1_pulsa_l1_y_x_no() -> void:  # AC-CFG-029
	var atenciones := await _atender()
	var asignacion := AsignacionDeControles.new()
	asignacion.asignar(
		AsignacionDeControles.AGARRAR,
		AsignacionDeControles.RANURA_DEL_JOYSTICK,
		AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK,
		JOY_BUTTON_LEFT_SHOULDER
	)
	var preferencias := Preferencias.new()
	preferencias.poner_controles(asignacion)
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	ajuste.aplicar(preferencias)
	var conversaciones := _conversaciones(atenciones)
	_apretar(JOY_BUTTON_A)
	assert_int(conversaciones[0]).is_zero()
	_apretar(JOY_BUTTON_LEFT_SHOULDER)
	assert_int(conversaciones[0]).is_equal(1)
