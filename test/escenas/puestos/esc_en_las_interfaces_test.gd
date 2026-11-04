## Esc cierra la computadora, la caja y las notas como el clic derecho, y sin interfaz pausa.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const UNIDAD := preload("res://src/escenas/objetos/objeto_agarrable.tscn")

const COMPUTADORA := "computadora"
const CAJA := "caja"
const NOTA := "nota"


func after_test() -> void:
	get_tree().paused = false


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get_node("Jugador").set_physics_process(false)
	for _cuadro in 4:
		await get_tree().physics_frame
	return almacen


func _esc(almacen: Node3D) -> void:
	var evento := InputEventAction.new()
	evento.action = &"ui_cancel"
	evento.pressed = true
	almacen.get_node("Interfaz/ControlDePausa").call("_input", evento)


func _puesto(almacen: Node3D, cual: String) -> Node:
	match cual:
		COMPUTADORA:
			return almacen.get_node("Estructura/base compu/StaticBody3D")
		CAJA:
			return almacen.get("_puesto_de_la_caja")
		_:
			return almacen.get_node("Estructura/NotasDelAlmacen")


## Abre la interfaz por el mismo camino que el primario y afirma que quedó abierta.
func _abrir_interfaz(almacen: Node3D, cual: String) -> Node:
	var puesto := _puesto(almacen, cual)
	if cual == NOTA:
		puesto.call("_abrir", (puesto.get("notas") as Array)[0])
	else:
		puesto.call("abrir")
	assert_bool(puesto.call("esta_abierta")).is_true()
	return puesto


func _control(almacen: Node3D) -> ControlDelJugador:
	return almacen.get_node("Jugador").get("_control")


func _con_una_unidad_en_la_mano(almacen: Node3D) -> ObjetoAgarrable:
	var unidad: ObjetoAgarrable = UNIDAD.instantiate()
	unidad.datos = UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI))
	almacen.add_child(unidad)
	var agarre: Agarre = almacen.get_node("Jugador").get("agarre")
	assert_bool(agarre.pedir_agarrar(unidad.datos, unidad)).is_true()
	return unidad


func test_esc_cierra_cada_interfaz_sin_pausar_y_conserva_la_mano() -> void:  # AC-PLY-166
	var almacen := await _almacen()
	var agarre: Agarre = almacen.get_node("Jugador").get("agarre")
	var unidad: ObjetoAgarrable = null
	for con_mano: bool in [false, true]:
		if con_mano:
			unidad = _con_una_unidad_en_la_mano(almacen)
		for cual: String in [COMPUTADORA, CAJA, NOTA]:
			var puesto := _abrir_interfaz(almacen, cual)
			assert_bool(_control(almacen).esta_suspendido()).is_true()
			_esc(almacen)
			assert_bool(puesto.call("esta_abierta")).is_false()
			assert_bool(_control(almacen).esta_suspendido()).is_false()
			assert_bool(get_tree().paused).is_false()
			assert_object(agarre.cuerpo_sostenido()).is_same(unidad)


func test_sin_interfaz_esc_pausa_y_tras_cerrar_una_el_siguiente_pausa() -> void:  # AC-PLY-167
	var almacen := await _almacen()
	_esc(almacen)
	assert_bool(get_tree().paused).is_true()
	_esc(almacen)
	assert_bool(get_tree().paused).is_false()
	for cual: String in [COMPUTADORA, CAJA, NOTA]:
		_abrir_interfaz(almacen, cual)
		_esc(almacen)
		assert_bool(get_tree().paused).is_false()
		_esc(almacen)
		assert_bool(get_tree().paused).is_true()
		_esc(almacen)
		assert_bool(get_tree().paused).is_false()


func test_con_una_lista_desplegada_esc_cierra_la_lista_y_despues_la_caja() -> void:  # AC-PLY-168
	var almacen := await _almacen()
	var puesto := _abrir_interfaz(almacen, CAJA)
	var programa: ProgramaDeTickets = almacen.get_node("Interfaz/ProgramaDeTickets")
	var selector := programa.selectores[0]
	selector.call("_alternar")
	assert_bool(selector.esta_abierta()).is_true()
	_esc(almacen)
	assert_bool(selector.esta_abierta()).is_false()
	assert_bool(puesto.call("esta_abierta")).is_true()
	assert_bool(get_tree().paused).is_false()
	_esc(almacen)
	assert_bool(puesto.call("esta_abierta")).is_false()
	assert_bool(get_tree().paused).is_false()
	_esc(almacen)
	assert_bool(get_tree().paused).is_true()


func test_en_pausa_esc_reanuda_y_la_interfaz_sigue_abierta() -> void:  # AC-PLY-169
	var almacen := await _almacen()
	for cual: String in [COMPUTADORA, CAJA, NOTA]:
		var puesto := _abrir_interfaz(almacen, cual)
		almacen.get_node("Interfaz/ControlDePausa").call("pausar")
		_esc(almacen)
		assert_bool(get_tree().paused).is_false()
		assert_bool(puesto.call("esta_abierta")).is_true()
		assert_bool(_control(almacen).esta_suspendido()).is_true()
		puesto.call("cerrar_con_esc")


func test_el_cursor_que_suelta_el_esc_de_la_salida_no_pausa() -> void:  # AC-PLY-170
	var almacen := await _almacen()
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	for cual: String in [COMPUTADORA, CAJA, NOTA]:
		var puesto := _abrir_interfaz(almacen, cual)
		pausa.set("_gracia_tras_esc", 0.0)
		pausa.set("_cursor_antes", true)
		_esc(almacen)
		pausa.call("_mirar_el_cursor")
		assert_bool(puesto.call("esta_abierta")).is_false()
		assert_bool(get_tree().paused).is_false()
