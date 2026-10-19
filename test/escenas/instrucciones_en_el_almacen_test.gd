extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const MENU := preload("res://src/escenas/menu_de_inicio.tscn")
const GUION := preload("res://src/dominio/investigacion/conversacion_con_el_jefe.tres")
const Jugador := preload("res://src/escenas/jugador.gd")

var _almacen: Node3D
var _ruta_anterior: String


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = create_temp_dir("intro").path_join("partida.guardado")


func after_test() -> void:
	get_tree().paused = false
	await _cerrar_almacen()
	Guardado.ruta_por_defecto = _ruta_anterior


func _cerrar_almacen() -> void:
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null


func _abrir() -> void:
	_almacen = ALMACEN.instantiate()
	get_tree().root.add_child(_almacen)


func _instrucciones() -> PantallaDeInstrucciones:
	return _almacen.get_node("Interfaz/PantallaDeInstrucciones")


func _persiana() -> PersianaDeLaNoche:
	return _almacen.get_node("Interfaz/PersianaDeLaNoche")


func _reloj() -> RelojDelTurno:
	return _almacen.get("_reloj")


func _jugador() -> Jugador:
	return _almacen.get("_jugador")


func _restante() -> float:
	return (_reloj().get("_turno") as Turno).tiempo_restante()


func _siguiente() -> Button:
	return _instrucciones().get("_siguiente")


func _esc() -> void:
	var evento := InputEventAction.new()
	evento.action = "ui_cancel"
	evento.pressed = true
	(_almacen.get_node("Interfaz/ControlDePausa") as ControlDePausa)._input(evento)


func _preparar_nueva() -> void:
	_abrir()
	_almacen.call("empezar_partida_nueva")


func test_sin_menu_no_muestra_instrucciones_ni_detiene_el_control() -> void:  # AC-EMP-048
	_abrir()
	assert_bool(_instrucciones().visible).is_false()
	assert_bool(_persiana().visible).is_false()
	assert_bool(_jugador().suspendido()).is_false()


func test_leer_dos_minutos_no_cobra_y_comenzar_anuncia_una_sola_noche() -> void:  # AC-EMP-048
	_preparar_nueva()
	assert_bool(_instrucciones().visible).is_true()
	assert_bool(_persiana().visible).is_true()
	assert_bool((_instrucciones().get("_volver") as Button).disabled).is_true()
	assert_bool((_persiana().get("_placa") as Label).visible).is_false()
	assert_bool(_jugador().suspendido()).is_true()
	var lista: Control = _instrucciones().get("_contenido")
	assert_int(lista.get_child_count()).is_equal(2)
	assert_str((lista.get_child(0) as RichTextLabel).text).is_equal(GUION.mensajes[0].texto)
	var restante := _restante()
	_reloj().set("_ultimo_cuadro_usec", Time.get_ticks_usec() - 120000000)
	_reloj().call("_process", 0.0)
	for _cuadro in 4:
		await get_tree().process_frame
	assert_float(_restante()).is_equal(restante)
	assert_bool(Guardado.new().hay_guardado()).is_false()
	for _paso in 11:
		_siguiente().pressed.emit()
	assert_str(_siguiente().text).is_equal("OK")
	_siguiente().pressed.emit()
	var entrada: EntradaALaNoche = _persiana().get("_entrada")
	assert_object(entrada).is_not_null()
	_siguiente().pressed.emit()
	assert_object(_persiana().get("_entrada")).is_same(entrada)
	assert_bool(_instrucciones().visible).is_false()
	assert_bool((_persiana().get("_placa") as Label).visible).is_true()
	assert_bool(_jugador().suspendido()).is_true()
	assert_float(_restante()).is_equal(restante)
	_persiana().terminar()
	assert_bool(_jugador().suspendido()).is_false()
	_reloj().call("_process", 0.0)
	assert_float(_restante()).is_greater(restante - 0.1)
	assert_bool(Guardado.new().hay_guardado()).is_false()


func test_fade_y_subida_usan_trescientos_milisegundos_reales() -> void:  # AC-EMP-049
	_abrir()
	var ahora: Array[int] = [0]
	_instrucciones().set("_ahora", func() -> int: return ahora[0])
	_persiana().set("_ahora", func() -> int: return ahora[0])
	_almacen.call("empezar_partida_nueva")
	var negro: ColorRect = _persiana().get("_negro")
	var marco: Control = _instrucciones().get("_marco")
	var altura := marco.size.y * marco.scale.y
	var destino := marco.position.y - altura
	assert_float(negro.modulate.a).is_equal(1.0)
	var animadas: Array[Node] = [_instrucciones(), _persiana()]
	_cuadros(ahora, 150000, animadas)
	assert_float(negro.modulate.a).is_equal_approx(0.5, 0.001)
	assert_float(marco.position.y).is_equal_approx(destino + altura / 2, 0.01)
	_cuadros(ahora, 299999, animadas)
	assert_bool(negro.visible).is_true()
	assert_bool(_instrucciones().is_processing()).is_true()
	_cuadros(ahora, 300000, animadas)
	assert_bool(negro.visible).is_false()
	assert_float(marco.position.y).is_equal_approx(destino, 0.01)
	assert_bool(_instrucciones().is_processing()).is_false()
	assert_bool(_persiana().visible).is_true()
	assert_bool((_persiana().get("_placa") as Label).visible).is_false()
	# La entrada posterior conserva 1 s quieta, 0,5 s de fade y 1 s de subida.
	for _paso in 12:
		_siguiente().pressed.emit()
	ahora[0] += 1000000
	_persiana().call("_process", 99.0)
	assert_float((_persiana().get("_placa") as Label).modulate.a).is_equal(1.0)
	ahora[0] += 250000
	_persiana().call("_process", 99.0)
	assert_float((_persiana().get("_placa") as Label).modulate.a).is_equal(0.5)
	ahora[0] += 250000
	_persiana().call("_process", 99.0)
	assert_vector((_persiana().get("_persiana") as TextureRect).position).is_equal(Vector2.ZERO)
	ahora[0] += 999999
	_persiana().call("_process", 99.0)
	assert_bool(_persiana().visible).is_true()
	assert_bool(_jugador().suspendido()).is_true()
	ahora[0] += 1
	_persiana().call("_process", 0.0)
	assert_bool(_persiana().visible).is_false()
	assert_bool(_jugador().suspendido()).is_false()


## El cuadro que abre la partida tarda: con el tiempo entero, el fundido se iba de un salto.
func test_un_cuadro_largo_adelanta_el_fade_un_paso_maximo() -> void:  # AC-EMP-049
	_abrir()
	var ahora: Array[int] = [0]
	_instrucciones().set("_ahora", func() -> int: return ahora[0])
	_persiana().set("_ahora", func() -> int: return ahora[0])
	_almacen.call("empezar_partida_nueva")
	ahora[0] = 150000
	_persiana().call("_process", 0.0)
	var negro: ColorRect = _persiana().get("_negro")
	var avance := CabeceraConSolapa.PASO_MAXIMO / PersianaDeLaNoche.FADE_DE_LA_PERSIANA_BAJA
	assert_float(negro.modulate.a).is_equal_approx(1.0 - avance, 0.001)


func test_esc_conserva_cuatro_pasos_animacion_y_presupuesto() -> void:  # AC-EMP-049
	_abrir()
	var ahora: Array[int] = [0]
	_instrucciones().set("_ahora", func() -> int: return ahora[0])
	_persiana().set("_ahora", func() -> int: return ahora[0])
	_almacen.call("empezar_partida_nueva")
	for _paso in 3:
		_siguiente().pressed.emit()
	var animadas: Array[Node] = [_instrucciones(), _persiana()]
	_cuadros(ahora, 150000, animadas)
	var marco: Control = _instrucciones().get("_marco")
	var posicion := marco.position
	var negro: ColorRect = _persiana().get("_negro")
	var opacidad := negro.modulate.a
	var restante := _restante()
	_esc()
	assert_bool(get_tree().paused).is_true()
	ahora[0] += 120000000
	for _cuadro in 4:
		await get_tree().process_frame
	(
		assert_int((_instrucciones().get("_instrucciones") as InstruccionesDelJefe).paso_actual())
		. is_equal(4)
	)
	assert_vector(marco.position).is_equal(posicion)
	assert_float(negro.modulate.a).is_equal(opacidad)
	assert_float(_restante()).is_equal(restante)
	_esc()
	assert_bool(get_tree().paused).is_false()
	_cuadros(ahora, ahora[0] + 150000, animadas)
	assert_bool(negro.visible).is_false()
	assert_bool(_instrucciones().is_processing()).is_false()
	(
		assert_int((_instrucciones().get("_instrucciones") as InstruccionesDelJefe).paso_actual())
		. is_equal(4)
	)
	assert_float(_restante()).is_equal(restante)


func test_continuar_carga_seis_y_siete_medios_sin_instrucciones() -> void:  # AC-SAV-021
	(
		assert_bool(Guardado.new().escribir(PartidaSerializada.sanear({"jornada": 6, "medios": 7})))
		. is_true()
	)
	_abrir()
	_almacen.call("anunciar_la_noche")
	var partida: Partida = _almacen.get("_partida")
	assert_int(partida.jornada()).is_equal(6)
	assert_int(partida.medios()).is_equal(7)
	assert_bool(_instrucciones().visible).is_false()
	assert_bool(_jugador().suspendido()).is_true()
	var restante := _restante()
	_reloj().set("_ultimo_cuadro_usec", Time.get_ticks_usec() - 120000000)
	_reloj().call("_process", 0.0)
	assert_float(_restante()).is_equal(restante)
	_persiana().terminar()
	assert_bool(_jugador().suspendido()).is_false()


func test_seguir_despues_de_la_primera_noche_no_repite_la_intro() -> void:
	Guardado.new().borrar()
	_preparar_nueva()
	for _paso in 12:
		_siguiente().pressed.emit()
	assert_bool(_instrucciones().visible).is_false()
	_persiana().terminar()
	_reloj().avanzar(_restante())
	var pantalla: PantallaDeDevolucion = _almacen.get("_pantalla")
	assert_bool(pantalla.visible).is_true()
	assert_int((_almacen.get("_partida") as Partida).jornada()).is_equal(2)
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	AvanceDeDevolucion.pasar_la_reflexion(pantalla)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	await get_tree().process_frame
	assert_bool(pantalla.visible).is_false()
	assert_bool(_instrucciones().visible).is_false()
	_persiana().terminar()
	for _cuadro in 4:
		await get_tree().process_frame
	assert_bool(_instrucciones().visible).is_false()
	assert_bool(_persiana().visible).is_false()
	assert_bool(_jugador().suspendido()).is_false()
	assert_bool(_reloj().corriendo()).is_true()


func test_abandonar_preparacion_no_escribe_y_preserva_checkpoint_anterior() -> void:  # AC-SAV-023
	var guardado := Guardado.new()
	for preparacion: String in ["instrucciones", "entrada_nueva", "entrada_guardada"]:
		(
			assert_bool(guardado.escribir(PartidaSerializada.sanear({"jornada": 6, "medios": 7})))
			. is_true()
		)
		var anterior := FileAccess.get_file_as_string(guardado.ruta)
		if preparacion == "entrada_guardada":
			_abrir()
			_almacen.call("anunciar_la_noche")
		else:
			var pedidos: PedidosDelMenu = auto_free(PedidosDelMenu.new())
			pedidos.preparar(MenuDeInicio.new(false, true), guardado)
			pedidos.nuevo_juego_pedido.connect(_preparar_nueva)
			pedidos.elegir(MenuDeInicio.Opcion.NUEVO_JUEGO)
			assert_bool(guardado.hay_guardado()).is_false()
			assert_bool(_instrucciones().visible).is_true()
			if preparacion == "entrada_nueva":
				for _paso in 12:
					_siguiente().pressed.emit()
				assert_bool(_persiana().visible).is_true()
		var salidas: Array[int] = [0]
		_almacen.set("_ir_al_menu", func() -> void: salidas[0] += 1)
		_esc()
		assert_bool(get_tree().paused).is_true()
		var pausa: MenuDePausa = _almacen.get_node("Interfaz/MenuDePausa")
		var volver: Button = pausa.get("_volver_al_menu")
		volver.pressed.emit()
		volver.pressed.emit()
		assert_bool(get_tree().paused).is_false()
		assert_int(salidas[0]).is_equal(1)
		if preparacion == "entrada_guardada":
			assert_str(FileAccess.get_file_as_string(guardado.ruta)).is_equal(anterior)
		else:
			assert_bool(guardado.hay_guardado()).is_false()
		await _cerrar_almacen()
		var menu: Control = auto_free(MENU.instantiate())
		get_tree().root.add_child(menu)
		menu.set_process(false)
		for boton: Button in menu.get_node("Marco").find_children("*", "Button", true, false):
			if boton.text == "CONTINUAR":
				assert_bool(boton.disabled).is_equal(preparacion != "entrada_guardada")
		menu.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame


func test_capa_sobre_persiana_y_debajo_de_avisos_y_pausa() -> void:  # AC-EMP-049
	_abrir()
	assert_int(_instrucciones().layer).is_equal(4)
	assert_int(_instrucciones().get_index()).is_greater(_persiana().get_index())
	for nombre: String in ["PilaDeNotificaciones", "MenuDePausa"]:
		var capa: CanvasLayer = _almacen.get_node("Interfaz/" + nombre)
		assert_int(capa.layer).is_greater(_instrucciones().layer)


## Avanza el reloj hasta `hasta` en cuadros de 10 ms, como un juego que corre parejo.
func _cuadros(ahora: Array[int], hasta: int, nodos: Array[Node]) -> void:
	while ahora[0] < hasta:
		ahora[0] = mini(ahora[0] + 10000, hasta)
		for nodo in nodos:
			nodo.call("_process", 0.0)
