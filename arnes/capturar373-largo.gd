extends SceneTree

const DESTINO := "C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010/capturas373/"

var _viewport: SubViewport
var _almacen: Node3D
var _sistema: CelularDelEmpleado
var _pantalla: PantallaDelCelular
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
	(_almacen.get("_reloj") as Node).set_process(false)
	(_almacen.get("_jugador") as Node).set_physics_process(false)
	await _esperar(0.5)
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		_viewport.size = tamano
		await _esperar(0.2)
		await _capturar("escritorio-cerrado-%d" % tamano.x)
		_sistema.pedir_alternar(false)
		assert(_sistema.celular().abierto())
		await _esperar(0.4)
		var telefono: Control = _pantalla.get("_telefono")
		var lienzo: Control = _pantalla.get("_lienzo")
		var rectangulo := telefono.get_global_rect()
		assert(is_equal_approx(rectangulo.size.x / rectangulo.size.y, 9.0 / 16.0))
		assert(rectangulo.get_center().is_equal_approx(Vector2(tamano) / 2))
		_ficha[str(tamano.x)] = {
			"rect":
			[rectangulo.position.x, rectangulo.position.y, rectangulo.size.x, rectangulo.size.y],
			"scale": lienzo.scale.x
		}
		await _capturar("escritorio-menu-%d" % tamano.x)
		var velo: Control = _pantalla.get("_velo")
		velo.hide()
		await _capturar("escritorio-menu-sin-velo-%d" % tamano.x)
		velo.show()
		var quien := _sistema.bandeja().conversaciones()[0].interlocutor
		_sistema.pedir_chat(quien)
		await _esperar(0.2)
		await _capturar("escritorio-chat-%d" % tamano.x)
		var foto := Mensaje.new()
		foto.de_quien = "Foto de prueba"
		foto.foto = load("res://assets/ui/manada/persiana.png")
		var adjunto := Mensaje.new()
		adjunto.texto = "Para esta noche, te pido que [b]organices las cajas[/b] que dejó el proveedor en el depósito. Acomodalas en los estantes y que no quede ni una en el piso, entendido? Te voy a tener cortito con esos detalles. Para trabajar en una estación de servicio tan prestigiosa como esta, tenés que estar al nivel."
		_sistema.recibir(quien, foto)
		_sistema.recibir(quien, adjunto)
		_sistema.pedir_foto(_sistema.bandeja().mensajes_de(quien).size() - 2)
		assert(_sistema.celular().pantalla() == Celular.Pantalla.FOTO)
		await _esperar(0.2)
		var cuerpo: RichTextLabel = _pantalla.get("_adjunto")
		var imagen: TextureRect = _pantalla.get("_imagen")
		var rectangulo_final := telefono.get_global_rect()
		assert(rectangulo_final.is_equal_approx(rectangulo))
		assert(rectangulo_final.encloses(cuerpo.get_global_rect()))
		assert(rectangulo_final.encloses(imagen.get_global_rect()))
		assert(cuerpo.size.y >= cuerpo.get_content_height() - 1)
		assert(imagen.size.y > 0)
		assert(cuerpo.text == adjunto.texto)
		_ficha[str(tamano.x)]["adjunto"] = {
			"texto": cuerpo.text,
			"texto_dibujado": cuerpo.get_parsed_text(),
			"lineas": cuerpo.get_line_count(),
			"altura_de_contenido": cuerpo.get_content_height(),
			"altura_del_nodo": cuerpo.size.y,
			"altura_de_imagen": imagen.size.y
		}
		await _capturar("escritorio-foto-%d" % tamano.x)
		_sistema.pedir_alternar(false)
		await _esperar(0.4)
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
