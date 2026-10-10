extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Jugador := preload("res://src/escenas/jugador.gd")

var _almacen: Node3D


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null


func _abrir(jornada: int = 1) -> void:
	_almacen = ALMACEN.instantiate()
	_almacen.set("_partida", Partida.desde(PartidaSerializada.sanear({"jornada": jornada})))
	get_tree().root.add_child(_almacen)


func _celular() -> CelularDelEmpleado:
	return _almacen.get_node("Interfaz/CelularDelEmpleado")


func _pantalla() -> PantallaDelCelular:
	return _almacen.get_node("Interfaz/PantallaDelCelular")


func _jugador() -> Jugador:
	return _almacen.get("_jugador")


func _q() -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = KEY_Q
	evento.pressed = true
	Input.parse_input_event(evento)
	await get_tree().process_frame
	evento.pressed = false
	Input.parse_input_event(evento)


func test_q_fisica_es_unica_y_alterna_menu_y_cierre() -> void:  # AC-INV-026, AC-INV-027
	_abrir()
	assert_bool(InputMap.has_action(Celular.ACCION)).is_true()
	var acciones: Array[StringName] = []
	for accion in InputMap.get_actions():
		for evento in InputMap.action_get_events(accion):
			if evento is InputEventKey and evento.physical_keycode == KEY_Q:
				acciones.append(accion)
	assert_array(acciones).is_equal([Celular.ACCION])
	await _q()
	assert_bool(_celular().celular().abierto()).is_true()
	assert_bool(_jugador().suspendido()).is_true()
	_celular().pedir_chat(_celular().bandeja().conversaciones()[0].interlocutor)
	await _q()
	assert_bool(_celular().celular().abierto()).is_false()
	assert_bool(_jugador().suspendido()).is_false()
	await _q()
	assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.MENU)


func test_q_no_abre_con_otra_interfaz_ni_examen_ni_turno_cerrado() -> void:  # AC-INV-026
	_abrir()
	var escritorio: Node = _almacen.get_node("Estructura/base compu/StaticBody3D")
	escritorio.abrir()
	assert_bool(_jugador().suspendido()).is_true()
	await _q()
	assert_bool(_celular().celular().abierto()).is_false()
	escritorio.cerrar()
	var agarre: Agarre = _almacen.get("_agarre")
	var caja: Node3D = _almacen.get("_cajas_de_productos")[0]
	assert_bool(agarre.pedir_agarrar(caja.get("datos"), caja)).is_true()
	assert_bool(_jugador().examen.iniciar()).is_true()
	await _q()
	assert_bool(_celular().celular().abierto()).is_false()
	assert_bool(_jugador().examen.esta_examinando()).is_true()
	_jugador().examen.terminar()
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.avanzar(Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL)
	assert_bool((_almacen.get("_pantalla") as CanvasLayer).visible).is_true()
	await _q()
	assert_bool(_celular().celular().abierto()).is_false()
	assert_bool(_jugador().suspendido()).is_true()


func test_celular_bloquea_entrada_y_conserva_la_unidad_y_la_pose() -> void:  # AC-PLY-081
	_abrir()
	var agarre: Agarre = _almacen.get("_agarre")
	var cuerpo := Node3D.new()
	_almacen.add_child(cuerpo)
	var datos := UnidadDeProducto.new(Catalogo.todos()[0])
	assert_bool(agarre.pedir_agarrar(datos, cuerpo)).is_true()
	var padre := cuerpo.get_parent()
	var pose := cuerpo.transform
	var control: ControlDelJugador = _jugador().get("_control")
	await _q()
	assert_bool(_jugador().suspendido()).is_true()
	assert_bool(control.quiere_el_cursor_tomado()).is_false()
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
	var yaw := control.yaw()
	control.girar(Vector2(300, 200))
	assert_float(control.yaw()).is_equal(yaw)
	assert_vector(control.velocidad(Vector2.ONE)).is_equal(Vector3.ZERO)
	assert_bool(control.observar(987, 1.0, true)).is_false()
	for accion: StringName in [ReglasDeLosObjetos.ACCION_AGARRAR, ReglasDelJugador.ACCION_USAR]:
		var evento := InputEventAction.new()
		evento.action = accion
		evento.pressed = true
		_jugador()._unhandled_input(evento)
	assert_object(agarre.cuerpo_sostenido()).is_same(cuerpo)
	assert_object(cuerpo.get_parent()).is_same(padre)
	assert_bool(cuerpo.transform.is_equal_approx(pose)).is_true()
	await _q()
	assert_bool(_jugador().suspendido()).is_false()
	assert_bool(control.quiere_el_cursor_tomado()).is_true()
	assert_object(agarre.cuerpo_sostenido()).is_same(cuerpo)
	assert_object(cuerpo.get_parent()).is_same(padre)
	assert_bool(cuerpo.transform.is_equal_approx(pose)).is_true()


func test_esc_cubre_la_foto_q_no_cambia_y_reanudar_conserva_la_pantalla() -> void:  # AC-INV-036
	_abrir()
	var mensaje := Mensaje.new()
	mensaje.foto = GradientTexture2D.new()
	var quien := _celular().bandeja().conversaciones()[0].interlocutor
	_celular().recibir(quien, mensaje)
	await _q()
	_celular().pedir_chat(quien)
	_celular().pedir_foto(_celular().bandeja().mensajes_de(quien).size() - 1)
	var foto: Control = _pantalla().get("_foto_ampliada")
	assert_bool(foto.visible).is_true()
	var pausa: ControlDePausa = _almacen.get_node("Interfaz/ControlDePausa")
	pausa.pausar()
	assert_bool(get_tree().paused).is_true()
	assert_bool((_almacen.get_node("Interfaz/MenuDePausa") as CanvasLayer).visible).is_true()
	await _q()
	assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.FOTO)
	assert_bool(_celular().celular().abierto()).is_true()
	pausa.reanudar()
	assert_bool(foto.visible).is_true()
	assert_bool(_jugador().suspendido()).is_true()
	await get_tree().process_frame


func test_cierre_baja_celular_y_otra_jornada_cierra() -> void:  # AC-INV-035, AC-INV-036
	_abrir()
	await _q()
	var recordatorio: Control = _pantalla().get("_recordatorio")
	assert_bool(recordatorio.visible).is_true()
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.avanzar(Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL)
	assert_bool(_celular().celular().abierto()).is_false()
	assert_bool(recordatorio.visible).is_false()
	assert_bool(_jugador().suspendido()).is_true()
	assert_float(_pantalla().get("_destino")).is_zero()
	var cierre: PantallaDeCierre = _almacen.get("_pantalla")
	(cierre.get("_continuar") as Button).pressed.emit()
	assert_bool(_celular().celular().abierto()).is_false()
	assert_bool(recordatorio.visible).is_true()
	(_almacen.get_node("Interfaz/PersianaDeLaNoche") as PersianaDeLaNoche).terminar()
	await _q()
	assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.MENU)


func test_celular_no_cobra_acciones_y_el_reloj_sigue_corriendo() -> void:  # AC-INV-007
	_abrir()
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.set_process(false)
	var turno: Turno = reloj.get("_turno")
	var antes := turno.tiempo_restante()
	var quien := _celular().bandeja().conversaciones()[0].interlocutor
	var foto := Mensaje.new()
	foto.foto = GradientTexture2D.new()
	_celular().recibir(quien, foto)
	_celular().pedir_alternar(false)
	_celular().pedir_chat(quien)
	_celular().pedir_foto(_celular().bandeja().mensajes_de(quien).size() - 1)
	assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.FOTO)
	_celular().pedir_cerrar_foto()
	_celular().pedir_volver()
	_celular().pedir_alternar(false)
	assert_float(turno.tiempo_restante()).is_equal(antes)
	reloj.avanzar(30.0)
	var sin_celular := antes - turno.tiempo_restante()
	_celular().pedir_alternar(false)
	antes = turno.tiempo_restante()
	reloj.avanzar(30.0)
	assert_float(antes - turno.tiempo_restante()).is_equal(sin_celular)
	assert_float(sin_celular).is_equal(Ritmo.escalar(30.0))


func test_botones_guiones_y_llegadas_al_final() -> void:  # AC-INV-027, AC-INV-029, AC-INV-038
	_abrir()
	await _q()
	var lista: VBoxContainer = _pantalla().get("_mensajes")
	var conversaciones := _celular().bandeja().conversaciones()
	var originales: Array[Mensaje] = conversaciones[0].mensajes.duplicate()
	assert_int(conversaciones.size()).is_equal(3)
	for indice in conversaciones.size():
		var conversacion := conversaciones[indice]
		(lista.get_child(indice) as Button).pressed.emit()
		assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.CHAT)
		assert_int(_celular().bandeja().no_leidos(conversacion.interlocutor)).is_zero()
		assert_int(lista.get_child_count()).is_equal(conversacion.mensajes.size())
		for entrada in conversacion.mensajes.size():
			var mensaje := conversacion.mensajes[entrada]
			var burbuja := lista.get_child(entrada)
			var textos := burbuja.find_children("*", "RichTextLabel", true, false)
			var fotografias := burbuja.find_children("*", "TextureButton", true, false)
			assert_int(textos.size()).is_equal(0 if mensaje.texto.is_empty() else 1)
			assert_int(fotografias.size()).is_equal(0 if mensaje.foto == null else 1)
			if textos.size() == 1:
				assert_str((textos[0] as RichTextLabel).text).is_equal(mensaje.texto)
			if fotografias.size() == 1:
				var fotografia: TextureButton = fotografias[0]
				assert_object(fotografia.texture_normal).is_same(mensaje.foto)
				fotografia.pressed.emit()
				assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.FOTO)
				assert_object((_pantalla().get("_imagen") as TextureRect).texture).is_same(
					mensaje.foto
				)
				var adjunto := _celular().bandeja().adjunto_de(conversacion.interlocutor, entrada)
				assert_str((_pantalla().get("_adjunto") as RichTextLabel).text).is_equal(
					adjunto.texto if adjunto != null else ""
				)
				_pantalla().cierre_de_foto_pedido.emit()
				assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.CHAT)
		(_pantalla().get("_volver") as Button).pressed.emit()
		assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.MENU)
		await get_tree().process_frame
	var quien := conversaciones[0].interlocutor
	(lista.get_child(0) as Button).pressed.emit()
	var recibido := Mensaje.new()
	recibido.texto = "Llegó este mensaje [b]completo[/b]."
	_celular().recibir(quien, recibido)
	assert_int(_celular().bandeja().no_leidos(quien)).is_equal(1)
	var ultimo := lista.get_child(lista.get_child_count() - 1)
	var cuerpos := ultimo.find_children("*", "RichTextLabel", true, false)
	assert_int(cuerpos.size()).is_equal(1)
	if cuerpos.size() == 1:
		assert_str((cuerpos[0] as RichTextLabel).text).is_equal(recibido.texto)
		assert_str((cuerpos[0] as RichTextLabel).get_parsed_text()).is_equal(
			"Llegó este mensaje completo."
		)
	assert_array(conversaciones[0].mensajes).is_equal(originales)
	assert_int(lista.get_child_count()).is_equal(originales.size() + 1)
	await get_tree().process_frame
	await get_tree().process_frame


func test_mensaje_recibido_suena_una_vez_y_anotar_ya_no_suena() -> void:  # AC-INV-029
	_abrir()
	var reproductor: ReproductorDeSonidos = _almacen.get_node(
		"Servicios/AudioDelAlmacen/Reproductor"
	)
	var pedidos: Array[EntradaSonora.Evento] = []
	reproductor.sonido_pedido.connect(
		func(evento: EntradaSonora.Evento) -> void: pedidos.append(evento)
	)
	var mensaje := Mensaje.new()
	mensaje.texto = "Prueba de llegada"
	var quien := _celular().bandeja().conversaciones()[0].interlocutor
	_celular().recibir(quien, mensaje)
	assert_array(pedidos).is_equal([EntradaSonora.Evento.MENSAJE_DEL_CELULAR])
	_celular().recibir(quien, null)
	var computadora: ComputadoraDeEscritorio = _almacen.get("_computadora")
	computadora.pedir_escribir("Prueba", "Sin sonido de mensaje")
	assert_array(pedidos).is_equal([EntradaSonora.Evento.MENSAJE_DEL_CELULAR])


func test_escala_nueve_diecisavos_y_capa_entre_hud_y_avisos() -> void:  # AC-INV-034
	_abrir()
	var telefono: Control = _pantalla().get("_telefono")
	var lienzo: Control = _pantalla().get("_lienzo")
	for tamano: Vector2 in [Vector2(1920, 1080), Vector2(1280, 720)]:
		LienzoDeManada.ajustar(lienzo, tamano)
		assert_float(telefono.size.x / telefono.size.y).is_equal(9.0 / 16.0)
		var centro := lienzo.position + Vector2(960, 540) * lienzo.scale
		assert_vector(centro).is_equal(tamano / 2)
	assert_int(_pantalla().layer).is_equal(4)
	for nombre: String in ["Hud", "PantallaDeComputadora", "PantallaDeCierre"]:
		assert_int((_almacen.get_node("Interfaz/" + nombre) as CanvasLayer).layer).is_less(
			_pantalla().layer
		)
	for nombre: String in ["PilaDeNotificaciones", "MenuDePausa"]:
		assert_int((_almacen.get_node("Interfaz/" + nombre) as CanvasLayer).layer).is_greater(
			_pantalla().layer
		)


func test_retomar_reconstruye_guion_sin_lecturas_ni_recibidos() -> void:  # AC-INV-037
	_abrir(3)
	(_almacen.get("_reloj") as RelojDelTurno).set_process(false)
	var anterior := _celular().bandeja()
	var esperados: Dictionary = {}
	var recibido := Mensaje.new()
	recibido.texto = "Llegada temporal de la sesion anterior."
	await _q()
	for conversacion in anterior.conversaciones():
		var quien := conversacion.interlocutor
		esperados[quien] = anterior.mensajes_de(quien)
		_celular().pedir_chat(quien)
		assert_int(anterior.no_leidos(quien)).is_zero()
		_celular().recibir(quien, recibido)
		assert_int(anterior.no_leidos(quien)).is_equal(1)
		assert_int(anterior.mensajes_de(quien).size()).is_equal(esperados[quien].size() + 1)
		_celular().pedir_volver()
	var guardado := Guardado.new()
	assert_bool(guardado.escribir(PartidaSerializada.sanear({"jornada": 3, "medios": 1}))).is_true()
	assert_bool(guardado.hay_guardado()).is_true()
	await after_test()
	# La escena reconstruye Partida desde el archivo real; no se inyecta _partida.
	_almacen = ALMACEN.instantiate()
	get_tree().root.add_child(_almacen)
	_almacen.call("anunciar_la_noche")
	assert_int((_almacen.get("_partida") as Partida).jornada()).is_equal(3)
	assert_int((_almacen.get("_partida") as Partida).medios()).is_equal(1)
	var nueva := _celular().bandeja()
	assert_object(nueva).is_not_same(anterior)
	assert_bool(_celular().celular().abierto()).is_false()
	assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.MENU)
	assert_int(nueva.conversaciones().size()).is_equal(esperados.size())
	var quienes: Array[Conversacion.Interlocutor] = []
	for conversacion in nueva.conversaciones():
		quienes.append(conversacion.interlocutor)
		var quien := conversacion.interlocutor
		var mensajes := nueva.mensajes_de(quien)
		assert_array(mensajes).is_equal(esperados[quien])
		assert_int(nueva.no_leidos(quien)).is_equal(mensajes.size())
		assert_bool(mensajes.has(recibido)).is_false()
		for mensaje in mensajes:
			assert_int(mensaje.jornada).is_less_equal(3)
	assert_array(quienes).is_equal(esperados.keys())
	guardado.borrar()
