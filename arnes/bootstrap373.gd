extends Node

var _preparado: bool = false


func _ready() -> void:
	var menu: Control = load("res://src/escenas/menu_de_inicio.tscn").instantiate()
	get_tree().root.add_child.call_deferred(menu)
	await get_tree().process_frame
	get_tree().current_scene = menu
	JavaScriptBridge.eval("window.nosefia373_accion = ''; window.nosefia373_estado = {}")
	_preparado = true


func _process(_delta: float) -> void:
	if not _preparado:
		return
	var escena := get_tree().current_scene
	if escena == null:
		return
	var estado: Dictionary = {"botones": [], "alma": false}
	for boton: Button in escena.find_children("*", "Button", true, false):
		if boton.is_visible_in_tree():
			var centro := boton.get_global_rect().get_center()
			estado["botones"].append(
				{"texto": boton.text, "nombre": boton.tooltip_text, "x": centro.x, "y": centro.y}
			)
	var sistema := escena.get_node_or_null("Interfaz/CelularDelEmpleado") as CelularDelEmpleado
	if sistema != null:
		estado["alma"] = true
		estado["abierto"] = sistema.celular().abierto()
		estado["pantalla"] = sistema.celular().pantalla()
		var pantalla: PantallaDelCelular = escena.get_node("Interfaz/PantallaDelCelular")
		var telefono: Control = pantalla.get("_telefono")
		var rectangulo := telefono.get_global_rect()
		estado["rect"] = [
			rectangulo.position.x, rectangulo.position.y, rectangulo.size.x, rectangulo.size.y
		]
		estado["scroll"] = (pantalla.get("_scroll") as ScrollContainer).scroll_vertical
		if sistema.celular().pantalla() == Celular.Pantalla.FOTO:
			var adjunto: RichTextLabel = pantalla.get("_adjunto")
			var imagen: TextureRect = pantalla.get("_imagen")
			var rect_adjunto := adjunto.get_global_rect()
			var rect_imagen := imagen.get_global_rect()
			estado["adjunto"] = {
				"texto": adjunto.text,
				"texto_dibujado": adjunto.get_parsed_text(),
				"altura_de_contenido": adjunto.get_content_height(),
				"altura_del_nodo": adjunto.size.y,
				"lineas": adjunto.get_line_count(),
				"altura_de_imagen": imagen.size.y,
				"cabe_texto": rectangulo.encloses(rect_adjunto),
				"cabe_imagen": rectangulo.encloses(rect_imagen)
			}

		estado["fotos"] = []
		for foto: TextureButton in pantalla.find_children("*", "TextureButton", true, false):
			if foto.is_visible_in_tree():
				var centro := foto.get_global_rect().get_center()
				estado["fotos"].append([centro.x, centro.y])
		var accion: String = str(JavaScriptBridge.eval("window.nosefia373_accion || ''"))
		if accion == "congelar":
			(escena.get("_reloj") as Node).set_process(false)
			(escena.get("_jugador") as Node).set_physics_process(false)
		elif accion == "sin_velo":
			(pantalla.get("_velo") as Control).hide()
		elif accion == "con_velo":
			(pantalla.get("_velo") as Control).show()
		elif accion == "foto":
			var quien := sistema.bandeja().conversaciones()[0].interlocutor
			var foto := Mensaje.new()
			foto.de_quien = "Foto de prueba"
			foto.foto = load("res://assets/ui/manada/persiana.png")
			var adjunto := Mensaje.new()
			adjunto.texto = "Para esta noche, te pido que [b]organices las cajas[/b] que dejó el proveedor en el depósito. Acomodalas en los estantes y que no quede ni una en el piso, entendido? Te voy a tener cortito con esos detalles. Para trabajar en una estación de servicio tan prestigiosa como esta, tenés que estar al nivel."
			sistema.recibir(quien, foto)
			sistema.recibir(quien, adjunto)
		JavaScriptBridge.eval("window.nosefia373_accion = ''")
	JavaScriptBridge.eval("window.nosefia373_estado = " + JSON.stringify(estado))
