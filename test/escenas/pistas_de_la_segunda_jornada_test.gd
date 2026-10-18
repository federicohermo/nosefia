extends GdUnitTestSuite

const Avance := preload("res://test/avance_de_devolucion.gd")
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")

var _almacen: Node3D
var _ruta_anterior: String
var _tamano_anterior: Vector2i


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	_tamano_anterior = get_window().size
	get_window().size = Vector2i(1920, 1080)
	Guardado.ruta_por_defecto = "user://pistas_22_prueba.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_almacen):
		_almacen.hide()
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await _cuadros(3)
	_almacen = null
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_anterior
	get_window().size = _tamano_anterior


func _cuadros(cantidad: int = 3) -> void:
	for _cuadro: int in cantidad:
		await get_tree().process_frame


func _abrir(jornada: int = 2) -> void:
	var partida := Partida.desde({"jornada": jornada, "medios": 0})
	var escena := load("res://src/escenas/almacen.tscn") as PackedScene
	_almacen = escena.instantiate()
	_almacen.set("_partida", partida)
	add_child(_almacen)
	if jornada == 1:
		_almacen.call("anunciar_la_noche")
	(_almacen.get_node("Interfaz/PersianaDeLaNoche") as PersianaDeLaNoche).terminar()
	(_almacen.get("_reloj") as Node).set_process(false)
	await _cuadros(5)
	assert_int(partida.jornada()).is_equal(jornada)
	assert_bool((_almacen.get("_reloj") as RelojDelTurno).corriendo()).is_true()


func _expediente() -> Expediente:
	return (_almacen.get("_partida") as Partida).expediente


func _celular() -> CelularDelEmpleado:
	return _almacen.get("_celular") as CelularDelEmpleado


func _pantalla() -> PantallaDelCelular:
	return _almacen.get("_pantalla_del_celular") as PantallaDelCelular


func _colilla() -> ObjetoAgarrable:
	return _almacen.get_node_or_null("Objetos/Colilla") as ObjetoAgarrable


func _clic(punto: Vector2) -> void:
	for apretado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = apretado
		evento.position = punto
		get_viewport().push_input(evento)
	await _cuadros()


func _tecla(accion: StringName) -> void:
	for apretado: bool in [true, false]:
		var evento := InputEventAction.new()
		evento.action = accion
		evento.pressed = apretado
		get_viewport().push_input(evento)
	Avance.terminar_movimiento(_almacen.get("_pantalla") as PantallaDeDevolucion)
	await _cuadros(5)


func _burbuja(indice: int) -> PanelContainer:
	var lista: VBoxContainer = _pantalla().get("_mensajes")
	for hijo: Node in lista.get_children():
		if hijo.has_meta("indice_de_mensaje") and int(hijo.get_meta("indice_de_mensaje")) == indice:
			return hijo as PanelContainer
	return null


func _tramo() -> Vector2:
	var texto := _burbuja(5).find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
	var scroll: ScrollContainer = _pantalla().get("_scroll")
	scroll.ensure_control_visible(texto)
	await _cuadros(4)
	var fuente := texto.get_theme_font("normal_font")
	var tamano := texto.get_theme_font_size("normal_font_size")
	var prefijo := fuente.get_string_size("y te aviso q ", HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var punto := (
		texto.get_global_transform() * Vector2(prefijo + 8.0, fuente.get_height(tamano) / 2.0)
	)
	assert_bool(scroll.get_global_rect().has_point(punto)).is_true()
	return punto


func _mirar_colilla() -> bool:
	var colilla := _colilla()
	assert_object(colilla).is_not_null()
	if colilla == null:
		return false
	var jugador := _almacen.get("_jugador") as CharacterBody3D
	var camara: Camera3D = jugador.get("_camara")
	jugador.call(
		"ubicar", Transform3D(Basis.IDENTITY, colilla.global_position + Vector3(0, 0, 0.75))
	)
	camara.look_at(colilla.global_position)
	for _cuadro: int in 12:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
	assert_bool(jugador.is_on_floor()).is_true()
	var consulta := PhysicsRayQueryParameters3D.create(
		camara.global_position, colilla.global_position
	)
	consulta.exclude = [jugador.get_rid()]
	var golpe := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	assert_object(golpe.get("collider")).is_same(colilla)
	assert_object(jugador.call("enfocado")).is_same(colilla)
	assert_bool(colilla.is_visible_in_tree()).is_true()
	var habitaciones: Node3D = _almacen.get("_habitaciones")
	assert_int(habitaciones.call("de", colilla.global_position)).is_equal(
		ReglasDelCierre.Habitacion.DEPOSITO
	)
	return jugador.call("enfocado") == colilla


func test_frase_real_anota_una_vez_y_leer_o_prefijo_no_anotan() -> void:  # AC-INV-048
	await _abrir()
	var nuevas: Array[Pista] = []
	(_almacen.get_node("Servicios/Investigador") as Investigador).pista_nueva.connect(
		func(pista: Pista) -> void: nuevas.append(pista)
	)
	await _tecla(Celular.ACCION)
	_celular().pedir_chat(Conversacion.Interlocutor.YASMIN)
	await _cuadros()
	assert_array(Array(_expediente().identidades())).is_empty()
	var punto := await _tramo()
	var texto := _burbuja(5).find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
	await _clic(
		(
			texto.get_global_transform()
			* Vector2(
				8.0,
				(
					texto.get_theme_font("normal_font").get_height(
						texto.get_theme_font_size("normal_font_size")
					)
					/ 2.0
				)
			)
		)
	)
	assert_array(Array(_expediente().identidades())).is_empty()
	await _clic(punto)
	await _clic(punto)
	assert_array(Array(_expediente().identidades())).is_equal(["2A"])
	assert_int(nuevas.size()).is_equal(1)
	assert_int(_expediente().mensajes_de_notas().size()).is_equal(2)


func test_colilla_real_exige_agarre_y_conserva_hallazgo_al_cerrar() -> void:  # AC-INV-049
	await _abrir()
	if not await _mirar_colilla():
		return
	var colilla := _colilla()
	assert_bool(colilla.datos is UnidadDeProducto).is_false()
	assert_str(String(colilla.datos.id)).is_equal("colilla")
	assert_array(Array(_expediente().identidades())).is_empty()
	var examen: Examen = _almacen.get("_jugador").get("examen")
	var pensamientos: Array[String] = []
	examen.pensamiento_pedido.connect(func(texto: String) -> void: pensamientos.append(texto))
	assert_str(colilla.datos.texto_al_examinar()).is_not_empty()
	await _tecla(ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_array(pensamientos).is_equal([colilla.datos.texto_al_examinar()])
	assert_array(Array(_expediente().identidades())).is_empty()
	assert_bool((_almacen.get("_jugador").get("examen") as Examen).esta_examinando()).is_false()
	await _clic(get_viewport().get_visible_rect().get_center())
	var agarre: Agarre = _almacen.get("_agarre")
	assert_object(agarre.cuerpo_sostenido()).is_same(colilla)
	assert_array(Array(_expediente().identidades())).is_equal(["2B"])
	assert_int(_expediente().mensajes_de_notas().size()).is_equal(2)
	agarre.soltar(false)
	await _cuadros()
	assert_bool(agarre.pedir_agarrar(colilla.datos, colilla)).is_true()
	assert_array(Array(_expediente().identidades())).is_equal(["2B"])
	assert_int(_expediente().mensajes_de_notas().size()).is_equal(2)
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.avanzar((reloj.get("_turno") as Turno).tiempo_restante())
	await _cuadros()
	assert_array(Array(_expediente().identidades())).is_equal(["2B"])
	assert_object(agarre.cuerpo_sostenido()).is_same(colilla)


func test_rechazo_y_pausa_no_registran_colilla() -> void:  # AC-INV-049
	await _abrir()
	var colilla := _colilla()
	assert_object(colilla).is_not_null()
	if colilla == null:
		return
	var agarre: Agarre = _almacen.get("_agarre")
	var balde := _almacen.get_node("Objetos/Balde") as ObjetoAgarrable
	assert_bool(agarre.pedir_agarrar(balde.datos, balde)).is_true()
	assert_bool(agarre.pedir_agarrar(colilla.datos, colilla)).is_false()
	assert_array(Array(_expediente().identidades())).is_empty()
	agarre.soltar(false)
	get_tree().paused = true
	assert_bool(agarre.pedir_agarrar(colilla.datos, colilla)).is_true()
	assert_array(Array(_expediente().identidades())).is_empty()
	assert_array(_expediente().mensajes_de_notas()).is_empty()
	get_tree().paused = false


func test_canales_fuera_de_j2_no_anotan_y_revelaciones_siguen_aparte() -> void:  # AC-INV-054
	await _abrir(3)
	var colilla := _colilla()
	assert_object(colilla).is_not_null()
	if colilla == null:
		return
	var agarre: Agarre = _almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(colilla.datos, colilla)).is_true()
	assert_array(Array(_expediente().identidades())).is_empty()
	var examen: Examen = _almacen.get("_jugador").get("examen")
	agarre.soltar(false)
	await _tecla(Celular.ACCION)
	_celular().pedir_chat(Conversacion.Interlocutor.YASMIN)
	await _cuadros()
	await _clic(await _tramo())
	assert_array(Array(_expediente().identidades())).is_empty()
	await _tecla(Celular.ACCION)
	var objeto := ObjetoDelAlmacen.new()
	objeto.id = &"revelacion_ajena"
	objeto.levantable = false
	objeto.revelacion = Revelacion.new()
	objeto.revelacion.texto = "Una revelación del caso de prueba."
	examen.iniciar(objeto, objeto.revelacion.texto)
	examen.iniciar(objeto, objeto.revelacion.texto)
	assert_int(examen.hallazgos().cantidad()).is_equal(1)
	assert_array(Array(_expediente().identidades())).is_empty()


func test_notas_j2_fijas_y_j3_menu_conservan_pares_y_scroll() -> void:  # AC-INV-051, AC-INV-052
	await _abrir()
	assert_int(_expediente().registrar("2B")).is_equal(Expediente.Resultado.ANOTADA)
	assert_int(_expediente().registrar("2A")).is_equal(Expediente.Resultado.ANOTADA)
	var notas := _celular().bandeja().mensajes_de(Conversacion.Interlocutor.NOTAS)
	assert_int(notas.size()).is_equal(4)
	if notas.size() != 4:
		return
	for conversacion: Conversacion in _celular().bandeja().conversaciones():
		assert_int(conversacion.interlocutor).is_not_equal(Conversacion.Interlocutor.NOTAS)
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.avanzar((reloj.get("_turno") as Turno).tiempo_restante())
	Avance.entregar(_almacen.get("_pantalla") as PantallaDeDevolucion)
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_window().size = tamano
		_celular().mostrar_fijo(Conversacion.Interlocutor.NOTAS)
		Avance.terminar_movimiento(_almacen.get("_pantalla") as PantallaDeDevolucion)
		await _cuadros(4)
		assert_int(_celular().celular().chat()).is_equal(Conversacion.Interlocutor.NOTAS)
		assert_bool(_celular().celular().fijo()).is_true()
		var scroll: ScrollContainer = _pantalla().get("_scroll")
		for indice: int in [0, 2]:
			var foto := (
				_burbuja(indice).find_children("*", "TextureButton", true, false)[0]
				as TextureButton
			)
			scroll.ensure_control_visible(foto)
			await _cuadros()
			var posicion := scroll.scroll_vertical
			await _clic(foto.get_global_rect().get_center())
			assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.FOTO)
			assert_str((_pantalla().get("_adjunto") as RichTextLabel).text).is_equal(
				notas[indice + 1].texto
			)
			await _clic((_pantalla().get("_telefono") as Control).get_global_rect().get_center())
			assert_int(_celular().celular().pantalla()).is_equal(Celular.Pantalla.CHAT)
			assert_int(scroll.scroll_vertical).is_equal(posicion)
		await _tecla(Celular.ACCION)
		assert_bool(_celular().celular().abierto()).is_true()
	_celular().abrir_jornada(3)
	var visibles: Array[Conversacion.Interlocutor] = []
	for conversacion: Conversacion in _celular().bandeja().conversaciones():
		visibles.append(conversacion.interlocutor)
	assert_bool(visibles.has(Conversacion.Interlocutor.NOTAS)).is_true()
	assert_array(Array(_expediente().identidades())).is_equal(["2B", "2A"])
	assert_int(_celular().bandeja().mensajes_de(Conversacion.Interlocutor.NOTAS).size()).is_equal(4)
	assert_array(Conversacion.de(Conversacion.Interlocutor.NOTAS).mensajes).is_empty()


func test_cierre_j1_abre_notas_vacias_fijas() -> void:  # AC-INV-052
	await _abrir(1)
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.avanzar((reloj.get("_turno") as Turno).tiempo_restante())
	Avance.entregar(_almacen.get("_pantalla") as PantallaDeDevolucion)
	_celular().mostrar_fijo(Conversacion.Interlocutor.NOTAS)
	Avance.terminar_movimiento(_almacen.get("_pantalla") as PantallaDeDevolucion)
	await _cuadros()
	assert_bool(_celular().celular().fijo()).is_true()
	assert_int(_celular().celular().chat()).is_equal(Conversacion.Interlocutor.NOTAS)
	assert_array(_celular().bandeja().mensajes_de(Conversacion.Interlocutor.NOTAS)).is_empty()
	await _tecla(Celular.ACCION)
	assert_bool(_celular().celular().abierto()).is_true()
	assert_array(Array(_expediente().identidades())).is_empty()


func test_recibido_futuro_no_aparece_en_el_chat_abierto() -> void:  # AC-INV-028
	await _abrir()
	await _tecla(Celular.ACCION)
	_celular().pedir_chat(Conversacion.Interlocutor.YASMIN)
	await _cuadros()
	var anteriores: Array[Mensaje] = _celular().bandeja().mensajes_de(
		Conversacion.Interlocutor.YASMIN
	)
	assert_int(anteriores.size()).is_equal(15)
	var futuro := Mensaje.new()
	futuro.identidad = "FUTURO_DE_PRUEBA"
	futuro.jornada = 3
	futuro.momento = Mensaje.Momento.APERTURA
	futuro.texto = "Este mensaje todavía no llegó."
	_celular().recibir(Conversacion.Interlocutor.YASMIN, futuro)
	await _cuadros()
	assert_array(_celular().bandeja().mensajes_de(Conversacion.Interlocutor.YASMIN)).is_equal(
		anteriores
	)
	assert_array(_pantalla().get("_historial")).is_equal(anteriores)
	assert_int(_celular().bandeja().no_leidos(Conversacion.Interlocutor.YASMIN)).is_equal(0)


func test_colilla_levantable_toma_luz_dinamica() -> void:
	var escena := load("res://src/escenas/objetos/colilla.tscn") as PackedScene
	var colilla: RigidBody3D = auto_free(escena.instantiate())
	var mallas := colilla.find_children("*", "MeshInstance3D", true, false)
	assert_array(mallas).is_not_empty()
	for malla: MeshInstance3D in mallas:
		assert_int(malla.gi_mode).is_equal(GeometryInstance3D.GI_MODE_DYNAMIC)
