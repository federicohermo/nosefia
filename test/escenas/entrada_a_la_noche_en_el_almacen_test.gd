extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Menu := preload("res://src/escenas/menu_de_inicio.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
## Cuántos cuadros se espera, como mucho, a que termine un calentamiento.
const CUADROS_DEL_CALENTAMIENTO := 3000


class MenuSinCarga:
	extends Menu

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass


var _almacen: Node3D
var _escena_anterior: Node


func before_test() -> void:
	_escena_anterior = get_tree().current_scene


func after_test() -> void:
	get_tree().paused = false
	get_tree().current_scene = _escena_anterior
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null


func _abrir(jornada := 1) -> void:
	_almacen = ALMACEN.instantiate()
	_almacen.set("_partida", Partida.desde(PartidaSerializada.sanear({"jornada": jornada})))
	get_tree().root.add_child(_almacen)


func _persiana() -> PersianaDeLaNoche:
	return _almacen.get_node("Interfaz/PersianaDeLaNoche")


func _control() -> ControlDelJugador:
	return _almacen.get("_jugador").get("_control")


func _restante() -> float:
	var turno: Turno = _almacen.get("_reloj").get("_turno")
	return turno.tiempo_restante()


func _cerrar_y_seguir() -> void:
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	var pantalla: PantallaDeDevolucion = _almacen.get("_pantalla")
	AvanceDeDevolucion.esperar_el_celular(pantalla)
	assert_bool(pantalla.visible).is_true()
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	pantalla.elegir()
	AvanceDeDevolucion.pasar_la_reflexion(pantalla)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	await get_tree().process_frame


func test_instanciar_sin_menu_conserva_el_turno_corriendo() -> void:
	_abrir()
	assert_bool(_persiana().en_pantalla()).is_false()
	assert_bool(_control().esta_suspendido()).is_false()
	var antes := _restante()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(_restante()).is_less(antes)


func test_seguir_dos_veces_anuncia_una_sola_noche_y_retiene_hasta_subir() -> void:  # AC-SHF-024
	# La primera completa abre la noche siguiente sin instrucciones.
	_abrir(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	await _cerrar_y_seguir()
	var siguiente := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
	assert_int((_almacen.get("_partida") as Partida).jornada()).is_equal(siguiente)
	var instrucciones: PantallaDeInstrucciones = _almacen.get_node(
		"Interfaz/PantallaDeInstrucciones"
	)
	assert_bool(instrucciones.visible).is_false()
	assert_bool(_persiana().en_pantalla()).is_true()
	assert_bool(_control().esta_suspendido()).is_true()
	var antes := _restante()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(_restante()).is_equal(antes)
	var subidas: Array[int] = []
	_persiana().persiana_subida.connect(func(jornada: int) -> void: subidas.append(jornada))
	_persiana().terminar()
	_persiana().terminar()
	assert_array(subidas).is_equal([siguiente])
	assert_bool(_persiana().en_pantalla()).is_false()
	assert_bool(_control().esta_suspendido()).is_false()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(_restante()).is_less(antes)


func test_desde_la_cuarta_seguir_anuncia_sin_instrucciones() -> void:  # AC-EMP-077
	var ultima := ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
	for jornada in range(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA, ultima):
		_abrir(jornada)
		await _cerrar_y_seguir()
		assert_int((_almacen.get("_partida") as Partida).jornada()).is_equal(jornada + 1)
		var instrucciones: PantallaDeInstrucciones = _almacen.get_node(
			"Interfaz/PantallaDeInstrucciones"
		)
		assert_bool(instrucciones.visible).is_false()
		# La noche del corte espera a que su oscuridad quede preparada.
		for _cuadro in CUADROS_DEL_CALENTAMIENTO:
			if _persiana().get("_entrada") != null:
				break
			await get_tree().process_frame
		assert_object(_persiana().get("_entrada")).is_not_null()
		await after_test()


func test_el_menu_anuncia_la_jornada_nueva_y_la_guardada() -> void:  # AC-SHF-025
	for jornada: int in [
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
	]:
		_abrir(jornada)
		var menu := MenuSinCarga.new()
		get_tree().root.add_child(menu)
		menu.set("_nuevo_juego", jornada == ReglasDeLaPartida.PRIMERA_JORNADA)
		menu.call("_entrar", _almacen)
		if jornada == ReglasDeLaPartida.PRIMERA_JORNADA:
			var instrucciones: PantallaDeInstrucciones = _almacen.get_node(
				"Interfaz/PantallaDeInstrucciones"
			)
			assert_bool(instrucciones.visible).is_true()
			var siguiente: Button = instrucciones.get("_siguiente")
			for _paso in 14:
				siguiente.pressed.emit()
			AvanceDeDevolucion.terminar_instrucciones(instrucciones)
			assert_bool(instrucciones.visible).is_false()
		assert_object(get_tree().current_scene).is_same(_almacen)
		assert_bool(_persiana().en_pantalla()).is_true()
		assert_str((_persiana().get_node("Marco/Placa") as Label).text).is_equal(
			"NOCHE %d" % jornada
		)
		assert_bool(_control().esta_suspendido()).is_true()
		await after_test()


func test_esc_congela_entrada_y_turno_y_reanudar_continua() -> void:  # AC-SHF-026
	_abrir()
	var ahora: Array[int] = [0]
	_persiana().set("_ahora", func() -> int: return ahora[0])
	_almacen.call("anunciar_la_noche")
	# Un avance conocido deja la placa en medio del fade, sin depender del ritmo headless.
	ahora[0] += 1250000
	_persiana().call("_process", 0.0)
	var placa: Label = _persiana().get_node("Marco/Placa")
	var persiana: TextureRect = _persiana().get_node("Persiana")
	var opacidad := placa.modulate.a
	var posicion := persiana.position
	var restante := _restante()
	assert_float(opacidad).is_equal(0.5)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	var pausa: ControlDePausa = _almacen.get_node("Interfaz/ControlDePausa")
	pausa._input(esc)
	assert_bool(get_tree().paused).is_true()
	for _cuadro in 4:
		await get_tree().process_frame
	assert_float(placa.modulate.a).is_equal(opacidad)
	assert_vector(persiana.position).is_equal(posicion)
	assert_float(_restante()).is_equal(restante)
	pausa._input(esc)
	assert_bool(get_tree().paused).is_false()
	ahora[0] += 250000
	_persiana().call("_process", 0.0)
	assert_float(placa.modulate.a).is_zero()
	assert_bool(_persiana().en_pantalla()).is_true()
	assert_float(_restante()).is_equal(restante)


func test_la_entrada_esta_sobre_el_local_y_debajo_de_avisos_y_pausa() -> void:  # AC-SHF-026
	_abrir()
	var entrada := _persiana()
	assert_int(entrada.layer).is_equal(4)
	for nombre: String in ["Hud", "PantallaDeComputadora", "PanelDeLaVentanilla"]:
		var capa: CanvasLayer = _almacen.get_node("Interfaz/" + nombre)
		assert_int(entrada.layer).is_greater(capa.layer)
	for nombre: String in ["PilaDeNotificaciones", "MenuDePausa"]:
		var capa: CanvasLayer = _almacen.get_node("Interfaz/" + nombre)
		assert_int(entrada.layer).is_less(capa.layer)


func test_volver_de_una_partida_terminada_no_anuncia_otra_noche() -> void:  # AC-SHF-024
	_abrir(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA)
	var pedidos := [0]
	_almacen.set("_ir_al_menu", func() -> void: pedidos[0] += 1)
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	var pantalla: PantallaDeDevolucion = _almacen.get("_pantalla")
	AvanceDeDevolucion.esperar_el_celular(pantalla)
	assert_bool(pantalla.visible).is_true()
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	assert_int(pedidos[0]).is_equal(1)
	assert_bool(_persiana().en_pantalla()).is_false()
