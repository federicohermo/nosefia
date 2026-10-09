## Sonda externa sobre A304 certificada; ejecutar sólo en la cola compartida.
extends SceneTree

var _validaciones := 0
var _fotos: Array[String] = []
var _fallo := false


func _initialize() -> void:
	call_deferred("_montar")


func _montar() -> void:
	print(
		"SONDA309_PROPIA ",
		JSON.stringify(
			{"pid": OS.get_process_id(), "proyecto": ProjectSettings.globalize_path("res://")}
		)
	)
	await _ejercer()
	print(
		"SONDA309_RESULTADO ",
		JSON.stringify({"validaciones": _validaciones, "fotos": _fotos, "fallo": _fallo})
	)
	print("SONDA309_MONTAJE_LIBERADO")
	quit(1 if _fallo else 0)


func _ejercer() -> void:
	var almacen: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
	root.add_child(almacen)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	jugador.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var caja: CajaRegistradora = almacen.get_node("Servicios/CajaRegistradora")
	var programa: ProgramaDeTickets = almacen.get_node("Interfaz/ProgramaDeTickets")
	var puesto: StaticBody3D = almacen.get_node("Estructura/cajaregistradora/StaticBody3D")
	var menu: MenuDePausa = almacen.get_node("Interfaz/MenuDePausa")
	var pila: PilaDeNotificaciones = almacen.get_node("Interfaz/PilaDeNotificaciones")
	var agarre: Agarre = almacen.get("_agarre")
	almacen.get("_reloj").set_process(false)
	var eventos: Array[String] = []
	programa.pausa_pedida.connect(func() -> void: eventos.append("popup-esc"))
	programa.cierre_pedido.connect(func() -> void: eventos.append("popup-right"))
	for _cuadro in 4:
		await physics_frame
	pila.set_process(false)
	await _ambas_interfaces(almacen, pila, caja)
	almacen.call("_al_abrir_la_jornada", 3)
	var unidad: ObjetoAgarrable = (
		load("res://src/escenas/objetos/objeto_agarrable.tscn").instantiate()
	)
	unidad.datos = UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI))
	almacen.add_child(unidad)
	_exigir(agarre.pedir_agarrar(unidad.datos, unidad), "Se conserva una unidad en la mano")
	for pantalla: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = pantalla
		programa.call("_ajustar")
		for _cuadro in 4:
			await process_frame
		caja.pedir_borrar()
		caja.pedir_elegir(1, Catalogo.de(Producto.Id.MAROLINI))
		caja.pedir_elegir(2, Catalogo.de(Producto.Id.CORACOLA))
		# Controlar el reloj del aviso durante la preparación de la foto, no durante la pausa.
		pila.set_process(false)
		pila.vaciar()
		# La llegada debe preparar también la atención que consume el panel de la ventanilla.
		var ventanilla: StaticBody3D = almacen.get_node("Estructura/Ventanilla")
		ventanilla.call("abrir")
		ventanilla.call("cerrar")
		puesto.call("abrir")
		_exigir(_hay_aviso(pila), "La señal real de llegada dibuja el aviso")
		var selector := programa.selectores[0]
		selector.show_popup()
		_exigir(selector.get_popup().visible, "PopupMenu real abierto antes de Esc")
		_exigir(programa.selectores[0].selected == 0, "Fila primera vacía")
		await _foto("309-aviso-popup-" + str(pantalla.x), pila, selector)
		_listo(selector, "ESC", pantalla.x)
		await _esperar_pausa(menu)
		_exigir(paused and menu.visible, "Esc abre la pausa real")
		_exigir(_listas_ocultas(programa), "La pausa cierra todas las listas reales")
		_exigir(programa.visible and _hay_aviso(pila), "Programa y aviso se conservan")
		_exigir(agarre.manos().sostenido() == unidad.datos, "Pausa conserva la mano")
		# Procesamiento habilitado: sólo la pausa real impide consumir los tres segundos.
		pila.set_process(true)
		_exigir(not pila.can_process(), "La pausa suspende el procesamiento del aviso")
		await create_timer(Notificaciones.DURACION + 0.1, true).timeout
		_exigir(_hay_aviso(pila), "Más de tres segundos pausado conservan el aviso")
		await _foto("309-aviso-pausa-" + str(pantalla.x), pila, selector)
		var reanudar: Button = menu.get("_reanudar")
		reanudar.pressed.emit()
		pila.set_process(false)
		for _cuadro in 4:
			await process_frame
		_exigir(not paused and not menu.visible and programa.visible, "Reanudar conserva programa")
		_exigir(_listas_ocultas(programa), "Reanudar no reabre automáticamente las listas")
		_exigir(
			(jugador.get("_control") as ControlDelJugador).esta_suspendido(),
			"El programa todavía suspende el control del jugador"
		)
		_exigir(
			(
				caja.generador().en_el_renglon(1).id == Producto.Id.MAROLINI
				and caja.generador().en_el_renglon(2).id == Producto.Id.CORACOLA
			),
			"Reanudar conserva las selecciones físicas"
		)
		pila._process(2.9)
		_exigir(_hay_aviso(pila), "Reanudar conserva los 2,9 segundos del aviso")
		pila._process(0.1)
		_exigir(not _hay_aviso(pila), "Completar tres segundos retira el aviso")
		selector.show_popup()
		for _cuadro in 3:
			await process_frame
		_listo(selector, "RIGHT", pantalla.x)
		var inicio := Time.get_ticks_msec()
		while programa.visible and Time.get_ticks_msec() - inicio < 5000:
			await process_frame
		_exigir(
			not programa.visible and _listas_ocultas(programa), "RIGHT cierra programa y listas"
		)
		_exigir(
			not (jugador.get("_control") as ControlDelJugador).esta_suspendido(),
			"RIGHT devuelve el control"
		)
		_exigir(agarre.manos().sostenido() == unidad.datos, "RIGHT conserva la mano")
	_exigir(
		eventos == ["popup-esc", "popup-right", "popup-esc", "popup-right"],
		"Dos resoluciones recibieron la secuencia nativa exacta"
	)
	print("SONDA309_EVENTOS ", JSON.stringify(eventos))
	jugador.call("suspender")
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for voz in almacen.find_children("*", tipo, true, false):
			voz.stop()
			voz.stream = null
	almacen.queue_free()
	for _cuadro in 4:
		await physics_frame


func _esperar_pausa(menu: MenuDePausa) -> void:
	var inicio := Time.get_ticks_msec()
	while (not paused or not menu.visible) and Time.get_ticks_msec() - inicio < 5000:
		await process_frame
	for _cuadro in 4:
		await process_frame


func _ambas_interfaces(almacen: Node3D, pila: PilaDeNotificaciones, caja: CajaRegistradora) -> void:
	var ventanilla: StaticBody3D = almacen.get_node("Estructura/Ventanilla")
	var escritorio: StaticBody3D = almacen.get_node("Estructura/base compu/StaticBody3D")
	var pantalla: PantallaDeComputadora = almacen.get_node("Interfaz/PantallaDeComputadora")
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = tamano
		pila.vaciar()
		caja.arrancar(GeneradorDeTickets.para_la_jornada(1))
		_exigir(not caja.generador().es_manual(), "Lector real presente en jornada 1")
		caja.pedir_anotar(ObjetoDelAlmacen.new())
		_exigir(_textos(pila).is_empty(), "Objeto ajeno a productos no avisa")
		for _renglon in GeneradorDeTickets.RENGLONES:
			caja.pedir_anotar(UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI)))
		_exigir(_textos(pila).is_empty(), "Tres lecturas anotadas no avisan")
		caja.pedir_anotar(UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI)))
		_exigir(_textos(pila) == ["NO SE PUDO LEER"], "Lector lleno real publica su aviso")
		ventanilla.call("abrir")
		_exigir(
			_textos(pila) == ["¡HAY UN CLIENTE!", "NO SE PUDO LEER"],
			"Llegada real convive primero con rechazo anterior"
		)
		await _foto_carteles("309-ventanilla-" + str(tamano.x), pila)
		ventanilla.call("cerrar")
		escritorio.call("abrir")
		_exigir(pantalla.visible, "Computadora real abierta con ambos avisos")
		await _foto_carteles("309-computadora-" + str(tamano.x), pila)
		escritorio.call("cerrar")
		pila.vaciar()


func _textos(pila: PilaDeNotificaciones) -> Array[String]:
	var textos: Array[String] = []
	for texto: Label in pila.find_children("*", "Label", true, false):
		textos.append(texto.text.replace("\n", " "))
	return textos


func _foto_carteles(nombre: String, pila: PilaDeNotificaciones) -> void:
	for _cuadro in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var simbolos: Array[Dictionary] = []
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	for simbolo: TextureRect in pila.find_children("*", "TextureRect", true, false):
		var rect := simbolo.get_global_rect()
		var original := simbolo.texture.get_size()
		var escala := minf(rect.size.x / original.x, rect.size.y / original.y)
		var dibujado := Rect2(
			rect.position + (rect.size - original * escala) / 2.0, original * escala
		)
		_exigir(viewport.encloses(rect) and rect.has_area(), "Símbolo local dentro del viewport")
		(
			simbolos
			. append(
				{
					"recurso": simbolo.texture.resource_path,
					"textura": [simbolo.texture.get_width(), simbolo.texture.get_height()],
					"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
					"rect_dibujado":
					[dibujado.position.x, dibujado.position.y, dibujado.size.x, dibujado.size.y],
				}
			)
		)
	_exigir(simbolos.size() == 2, "Ambos símbolos originales presentes")
	var destino := OS.get_environment("SONDA309_SALIDA").path_join(nombre + ".png")
	_exigir(root.get_texture().get_image().save_png(destino) == OK, "Captura guardada: " + nombre)
	_fotos.append(destino)
	print(
		"SONDA309_ESTADO_FOTO ",
		(
			JSON
			. stringify(
				{
					"nombre": nombre,
					"resolucion": [root.size.x, root.size.y],
					"textos": _textos(pila),
					"simbolos": simbolos,
				}
			)
		)
	)


func _listas_ocultas(programa: ProgramaDeTickets) -> bool:
	for selector in programa.selectores:
		if selector.get_popup().visible:
			return false
	return true


func _hay_aviso(pila: PilaDeNotificaciones) -> bool:
	for texto in pila.find_children("*", "Label", true, false):
		if texto.text.replace("\n", " ") == "¡HAY UN CLIENTE!":
			return true
	return false


func _listo(selector: OptionButton, accion: String, ancho: int) -> void:
	var popup := selector.get_popup()
	print(
		"SONDA309_POPUP_LISTO ",
		JSON.stringify(
			{
				"accion": accion,
				"ancho": ancho,
				"popup":
				DisplayServer.window_get_native_handle(
					DisplayServer.WINDOW_HANDLE, popup.get_window_id()
				),
				"raiz":
				DisplayServer.window_get_native_handle(
					DisplayServer.WINDOW_HANDLE, root.get_window_id()
				),
				"x": popup.position.x,
				"y": popup.position.y,
				"embebido": root.gui_embed_subwindows,
				"factor": popup.content_scale_factor,
				"max_size": [popup.max_size.x, popup.max_size.y]
			}
		)
	)


func _foto(nombre: String, pila: PilaDeNotificaciones, selector: OptionButton) -> void:
	for _cuadro in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var destino := OS.get_environment("SONDA309_SALIDA").path_join(nombre + ".png")
	_exigir(root.get_texture().get_image().save_png(destino) == OK, "Captura guardada: " + nombre)
	_fotos.append(destino)
	print(
		"SONDA309_ESTADO_FOTO ",
		JSON.stringify(
			{
				"nombre": nombre,
				"resolucion": [root.size.x, root.size.y],
				"pausa": paused,
				"popup_abierto": selector.get_popup().visible,
				"aviso": _hay_aviso(pila)
			}
		)
	)


func _exigir(valida: bool, descripcion: String) -> void:
	_validaciones += 1
	print("SONDA309_VALIDACION ", descripcion, " = ", valida)
	if not valida:
		_fallo = true
		push_error(descripcion)
		quit(1)
