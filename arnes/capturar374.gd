extends SceneTree

const DESTINO := "C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010/capturas374/"

var _viewport: SubViewport
var _almacen: Node3D
var _sistema: CelularDelEmpleado
var _pantalla: PantallaDelCelular
var _instrucciones: PantallaDeInstrucciones
var _ficha: Dictionary = {}


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	DirAccess.make_dir_recursive_absolute(DESTINO)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.world_3d = World3D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	await physics_frame
	await process_frame
	assert(_viewport.world_3d != null)
	assert(_viewport.world_3d.direct_space_state != null)
	var muestra := TextureRect.new()
	muestra.texture = _viewport.get_texture()
	muestra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	muestra.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	muestra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(muestra)
	_almacen = load("res://src/escenas/almacen.tscn").instantiate()
	_almacen.set("_partida", load("res://src/dominio/empleo/partida.gd").call("nueva"))
	_viewport.add_child(_almacen)
	_sistema = _almacen.get_node("Interfaz/CelularDelEmpleado")
	_pantalla = _almacen.get_node("Interfaz/PantallaDelCelular")
	_instrucciones = _almacen.get_node("Interfaz/PantallaDeInstrucciones")
	(_almacen.get("_reloj") as Node).set_process(false)
	(_almacen.get("_jugador") as Node).set_physics_process(false)
	await _esperar(0.5)
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		_viewport.size = tamano
		_almacen.call("empezar_partida_nueva")
		await _esperar(0.4)
		assert(_instrucciones.visible)
		var contenido: VBoxContainer = _instrucciones.get("_contenido")
		assert(contenido.get_child_count() == 2)
		await _capturar("escritorio-instrucciones-primero-%d" % tamano.x)
		var siguiente: Button = _instrucciones.get("_siguiente")
		for cantidad in range(2, 15):
			siguiente.pressed.emit()
			await _esperar(0.1)
			assert(contenido.get_child_count() == cantidad + 1)
			if cantidad == 4:
				assert(contenido.get_child(3).get_child(0) is TextureRect)
				await _capturar("escritorio-instrucciones-foto-%d" % tamano.x)
		assert(siguiente.text == "Comenzar")
		assert(siguiente.get_global_rect().intersects(Rect2(Vector2.ZERO, Vector2(tamano))))
		await _capturar("escritorio-instrucciones-ultimo-%d" % tamano.x)
		siguiente.pressed.emit()
		assert(not _instrucciones.visible)
		var persiana: PersianaDeLaNoche = _almacen.get_node("Interfaz/PersianaDeLaNoche")
		var placa: Label = persiana.get("_placa")
		assert(placa.visible and placa.text == "NOCHE 1")
		await _capturar("escritorio-noche-1-%d" % tamano.x)
		await _esperar(2.6)
		assert(not persiana.visible)
		_sistema.pedir_alternar(false)
		assert(_sistema.celular().abierto())
		await _esperar(0.35)
		var quien := _sistema.bandeja().conversaciones()[0].interlocutor
		_sistema.pedir_chat(quien)
		await _esperar(0.2)
		await _capturar("escritorio-chat-enrique-%d" % tamano.x)
		var mensajes := _sistema.bandeja().mensajes_de(quien)
		assert(mensajes.size() == 21)
		var indice := mensajes.size() - 1
		while indice >= 0 and mensajes[indice].foto == null:
			indice -= 1
		assert(indice >= 0)
		_sistema.pedir_foto(indice)
		assert(_sistema.celular().pantalla() == Celular.Pantalla.FOTO)
		await _esperar(0.2)
		var telefono: Control = _pantalla.get("_telefono")
		var cuerpo: RichTextLabel = _pantalla.get("_adjunto")
		var imagen: TextureRect = _pantalla.get("_imagen")
		var rectangulo := telefono.get_global_rect()
		assert(is_equal_approx(rectangulo.size.x / rectangulo.size.y, 9.0 / 16.0))
		assert(rectangulo.get_center().is_equal_approx(Vector2(tamano) / 2))
		assert(rectangulo.encloses(cuerpo.get_global_rect()))
		assert(rectangulo.encloses(imagen.get_global_rect()))
		assert(cuerpo.size.y >= cuerpo.get_content_height() - 1)
		assert(imagen.size.y > 0)
		assert(cuerpo.text == mensajes[indice + 1].texto)
		_ficha[str(tamano.x)] = {
			"foto": imagen.texture.resource_path,
			"adjunto": cuerpo.text,
			"texto_dibujado": cuerpo.get_parsed_text(),
			"altura_de_contenido": cuerpo.get_content_height(),
			"altura_del_nodo": cuerpo.size.y,
			"altura_de_imagen": imagen.size.y,
			"pasos": 14,
			"entradas": mensajes.size()
		}
		await _capturar("escritorio-foto-enrique-%d" % tamano.x)
		_sistema.pedir_alternar(false)
		await _esperar(0.35)
	var archivo := FileAccess.open(DESTINO + "escritorio-medidas.json", FileAccess.WRITE)
	archivo.store_string(JSON.stringify(_ficha, "\t"))
	archivo.close()
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in _almacen.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	muestra.texture = null
	muestra.queue_free()
	_viewport.queue_free()
	_sistema = null
	_pantalla = null
	_instrucciones = null
	_almacen = null
	_viewport = null
	for _cuadro in 4:
		await process_frame
	quit.call_deferred(0)


func _esperar(segundos: float) -> void:
	var hasta := Time.get_ticks_usec() + int(segundos * 1000000)
	while Time.get_ticks_usec() < hasta:
		await process_frame


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var imagen := _viewport.get_texture().get_image()
	assert(not imagen.is_empty())
	assert(imagen.save_png(DESTINO + nombre + ".png") == OK)
	print("CAPTURA ", nombre, " ", imagen.get_size())
