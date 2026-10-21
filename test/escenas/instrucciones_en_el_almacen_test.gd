extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const MENU := preload("res://src/escenas/menu_de_inicio.tscn")
const GUION := preload("res://src/dominio/investigacion/conversacion_con_el_jefe.tres")
const Jugador := preload("res://src/escenas/jugador.gd")
const PRIMERA := ReglasDeLaPartida.PRIMERA_JORNADA
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA

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


func _pasos(jornada: int) -> Array[InstruccionesDelJefe.Paso]:
	var partida: Partida = _almacen.get("_partida")
	var condiciones := CondicionesDelJefe.elegidas(partida.noches_de_prueba)
	return InstruccionesDelJefe.pasos_de(
		InstruccionesDelJefe.de_la_jornada(GUION.mensajes, jornada, condiciones)
	)


## Avanza hasta el «OK» y lo elige.
func _leer_todo(jornada: int = PRIMERA) -> void:
	for _paso in _pasos(jornada).size():
		_siguiente().pressed.emit()


## Sin medios: cerrar una noche vacía no despide.
func _guardar(jornada: int, medios: int = 0, noches: Dictionary = {}) -> void:
	var datos := {"jornada": jornada, "medios": medios, "noches_de_prueba": noches}
	assert_bool(Guardado.new().escribir(PartidaSerializada.sanear(datos))).is_true()


func _cerrar_y_seguir() -> void:
	_persiana().terminar()
	_reloj().avanzar(_restante())
	var pantalla: PantallaDeDevolucion = _almacen.get("_pantalla")
	assert_bool(pantalla.visible).is_true()
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	AvanceDeDevolucion.pasar_la_reflexion(pantalla)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	assert_bool(await AvanceDeDevolucion.esperar_la_noche_siguiente(_almacen)).is_true()
	assert_bool(pantalla.visible).is_false()


## Las de la jornada desde su primera pantalla, sobre la persiana baja y sin cobrar la lectura.
func _comprobar_instrucciones_de(jornada: int) -> void:
	assert_int((_almacen.get("_partida") as Partida).jornada()).is_equal(jornada)
	assert_bool(_instrucciones().visible).is_true()
	assert_bool(_persiana().visible).is_true()
	assert_bool((_persiana().get("_placa") as Label).visible).is_false()
	assert_bool(_jugador().suspendido()).is_true()
	var pasos: Array = _instrucciones().get("_pasos")
	assert_str((pasos[0] as InstruccionesDelJefe.Paso).textos[0].identidad).is_equal(
		_pasos(jornada)[0].textos[0].identidad
	)
	(
		assert_int((_instrucciones().get("_instrucciones") as InstruccionesDelJefe).paso_actual())
		. is_equal(1)
	)
	assert_str((_instrucciones().get("_contador") as Label).text).is_equal(
		"1/%d" % _pasos(jornada).size()
	)
	var restante := _restante()
	_reloj().set("_ultimo_cuadro_usec", Time.get_ticks_usec() - 120000000)
	_reloj().call("_process", 0.0)
	assert_float(_restante()).is_equal(restante)


func _comprobar_mensaje_1_de(jornada: int) -> void:
	var pasos: Array = _instrucciones().get("_pasos")
	var primero: Mensaje = (pasos[0] as InstruccionesDelJefe.Paso).textos[0]
	assert_bool(primero.condicion.is_empty()).is_false()
	assert_int(pasos.size()).is_equal(_pasos(jornada).size())


## Una sola entrada a la noche de la jornada, con el turno y el control retenidos.
func _comprobar_una_noche(jornada: int) -> void:
	var entrada: EntradaALaNoche = _persiana().get("_entrada")
	assert_object(entrada).is_not_null()
	_siguiente().pressed.emit()
	assert_object(_persiana().get("_entrada")).is_same(entrada)
	assert_bool(_instrucciones().visible).is_false()
	assert_int(_persiana().get("_jornada")).is_equal(jornada)
	assert_bool((_persiana().get("_placa") as Label).visible).is_true()
	assert_bool(_jugador().suspendido()).is_true()
	var restante := _restante()
	_reloj().set("_ultimo_cuadro_usec", Time.get_ticks_usec() - 120000000)
	_reloj().call("_process", 0.0)
	assert_float(_restante()).is_equal(restante)


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
	for _paso in _pasos(PRIMERA).size() - 1:
		_siguiente().pressed.emit()
	assert_str(_siguiente().text).is_equal(PantallaDeInstrucciones.TEXTO_DE_COMENZAR)
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
	_leer_todo()
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


func test_continuar_una_completa_no_muestra_instrucciones() -> void:  # AC-SAV-021, AC-EMP-077
	_guardar(COMPLETA + 1, 7)
	_abrir()
	_almacen.call("retomar_la_partida")
	var partida: Partida = _almacen.get("_partida")
	assert_int(partida.jornada()).is_equal(COMPLETA + 1)
	assert_int(partida.medios()).is_equal(7)
	assert_bool(_instrucciones().visible).is_false()
	assert_bool(_jugador().suspendido()).is_true()
	var restante := _restante()
	_reloj().set("_ultimo_cuadro_usec", Time.get_ticks_usec() - 120000000)
	_reloj().call("_process", 0.0)
	assert_float(_restante()).is_equal(restante)
	_persiana().terminar()
	assert_bool(_jugador().suspendido()).is_false()


func test_seguir_desde_la_primera_abre_las_de_la_segunda() -> void:  # AC-EMP-075, AC-EMP-064
	Guardado.new().borrar()
	_preparar_nueva()
	_leer_todo()
	assert_bool(_instrucciones().visible).is_false()
	await _cerrar_y_seguir()
	_comprobar_instrucciones_de(PRIMERA + 1)
	_comprobar_mensaje_1_de(PRIMERA + 1)
	_leer_todo(PRIMERA + 1)
	_comprobar_una_noche(PRIMERA + 1)
	_persiana().terminar()
	for _cuadro in 4:
		await get_tree().process_frame
	assert_bool(_instrucciones().visible).is_false()
	assert_bool(_persiana().visible).is_false()
	assert_bool(_jugador().suspendido()).is_false()
	assert_bool(_reloj().corriendo()).is_true()


## Esc en la segunda pantalla de la segunda jornada conserva la lectura.
func test_retomar_la_segunda_y_seguir() -> void:  # AC-EMP-076, AC-EMP-075, AC-EMP-049, AC-SAV-033
	_guardar(PRIMERA + 1, 0, {PRIMERA: ResultadoDeLaNoche.new(1, []).a_datos()})
	_abrir()
	_almacen.call("retomar_la_partida")
	_comprobar_instrucciones_de(PRIMERA + 1)
	_comprobar_mensaje_1_de(PRIMERA + 1)
	_siguiente().pressed.emit()
	_esc()
	assert_bool(get_tree().paused).is_true()
	for _cuadro in 4:
		await get_tree().process_frame
	_esc()
	assert_bool(get_tree().paused).is_false()
	(
		assert_int((_instrucciones().get("_instrucciones") as InstruccionesDelJefe).paso_actual())
		. is_equal(2)
	)
	_leer_todo(PRIMERA + 1)
	_comprobar_una_noche(PRIMERA + 1)
	await _cerrar_y_seguir()
	_comprobar_instrucciones_de(PRIMERA + 2)
	_comprobar_mensaje_1_de(PRIMERA + 2)
	assert_str((_instrucciones().get("_contador") as Label).text).is_equal("1/2")
	_siguiente().pressed.emit()
	assert_str(_siguiente().text).is_equal(PantallaDeInstrucciones.TEXTO_DE_COMENZAR)
	_siguiente().pressed.emit()
	_comprobar_una_noche(PRIMERA + 2)


func test_retomar_la_tercera_y_la_cuarta() -> void:  # AC-EMP-076, AC-SAV-021, AC-EMP-077
	_guardar(PRIMERA + 2)
	_abrir()
	_almacen.call("retomar_la_partida")
	_comprobar_instrucciones_de(PRIMERA + 2)
	_leer_todo(PRIMERA + 2)
	_comprobar_una_noche(PRIMERA + 2)
	await _cerrar_almacen()
	_guardar(COMPLETA)
	_abrir()
	_almacen.call("retomar_la_partida")
	assert_bool(_instrucciones().visible).is_false()
	assert_int(_persiana().get("_jornada")).is_equal(COMPLETA)
	assert_bool((_persiana().get("_placa") as Label).visible).is_true()
	var celular: CelularDelEmpleado = _almacen.get("_celular")
	var chat := celular.bandeja().mensajes_de(Conversacion.Interlocutor.JEFE)
	var de_la_cuarta: Array[String] = []
	for mensaje: Mensaje in GUION.mensajes:
		if mensaje.jornada == COMPLETA:
			de_la_cuarta.append(mensaje.identidad)
	var ultimos: Array[String] = []
	for mensaje: Mensaje in chat.slice(chat.size() - de_la_cuarta.size()):
		ultimos.append(mensaje.identidad)
	assert_array(ultimos).is_equal(de_la_cuarta)


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
				_leer_todo()
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
