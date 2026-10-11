## Sonda externa: observa el flujo real y sólo prepara un checkpoint para CONTINUAR.
extends Node

var _preparado := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var menu: Control = load("res://src/escenas/menu_de_inicio.tscn").instantiate()
	get_tree().root.add_child.call_deferred(menu)
	await get_tree().process_frame
	get_tree().current_scene = menu
	JavaScriptBridge.eval("window.nosefia374_accion = ''; window.nosefia374_estado = {}")
	_preparado = true


func _process(_delta: float) -> void:
	if not _preparado:
		return
	var escena := get_tree().current_scene
	if escena == null:
		return
	var estado: Dictionary = {"botones": [], "alma": false, "pausa": get_tree().paused}
	for boton: Button in escena.find_children("*", "Button", true, false):
		if boton.is_visible_in_tree():
			var centro := boton.get_global_rect().get_center()
			estado["botones"].append(
				{
					"texto": boton.text,
					"nombre": boton.tooltip_text,
					"x": centro.x,
					"y": centro.y,
					"habilitado": not boton.disabled
				}
			)
	var sistema := escena.get_node_or_null("Interfaz/CelularDelEmpleado") as CelularDelEmpleado
	if sistema == null:
		JavaScriptBridge.eval("window.nosefia374_estado = " + JSON.stringify(estado))
		return
	estado["alma"] = true
	var partida: RefCounted = escena.get("_partida")
	estado["jornada"] = partida.call("jornada")
	estado["medios"] = partida.call("medios")
	var reloj: Node = escena.get("_reloj")
	estado["presupuesto"] = (reloj.get("_turno") as RefCounted).call("tiempo_restante")
	var persiana: PersianaDeLaNoche = escena.get_node("Interfaz/PersianaDeLaNoche")
	var placa: Label = persiana.get("_placa")
	estado["placa"] = {"visible": placa.is_visible_in_tree(), "texto": placa.text}
	var instrucciones: PantallaDeInstrucciones = escena.get_node("Interfaz/PantallaDeInstrucciones")
	var pasos: Array[Dictionary] = []
	if instrucciones.visible:
		var contenido: VBoxContainer = instrucciones.get("_contenido")
		var botones: HBoxContainer = instrucciones.get("_botones")
		for fila: Node in contenido.get_children():
			if fila == botones:
				continue
			var paso: Dictionary = {"foto": "", "foto_antes_del_texto": true}
			for hijo: Node in fila.get_children():
				if hijo is TextureRect:
					paso["foto"] = (hijo as TextureRect).texture.resource_path
					paso["foto_tamano"] = (hijo as TextureRect).texture.get_size()
					paso["foto_antes_del_texto"] = hijo.get_index() == 0
				elif hijo is RichTextLabel:
					paso["texto"] = (hijo as RichTextLabel).text
					paso["texto_dibujado"] = (hijo as RichTextLabel).get_parsed_text()
			pasos.append(paso)
	estado["instrucciones"] = {"visible": instrucciones.visible, "pasos": pasos}
	estado["abierto"] = sistema.celular().abierto()
	estado["pantalla"] = sistema.celular().pantalla()
	var pantalla: PantallaDelCelular = escena.get_node("Interfaz/PantallaDelCelular")
	var scroll: ScrollContainer = pantalla.get("_scroll")
	estado["fotos"] = []
	for foto: TextureButton in pantalla.find_children("*", "TextureButton", true, false):
		var centro := foto.get_global_rect().get_center()
		if foto.is_visible_in_tree() and scroll.get_global_rect().has_point(centro):
			estado["fotos"].append([centro.x, centro.y])
	if sistema.celular().pantalla() == Celular.Pantalla.FOTO:
		var imagen: TextureRect = pantalla.get("_imagen")
		var adjunto: RichTextLabel = pantalla.get("_adjunto")
		estado["foto_ampliada"] = {
			"ruta": imagen.texture.resource_path,
			"texto": adjunto.text,
			"texto_dibujado": adjunto.get_parsed_text()
		}
	var accion: String = str(JavaScriptBridge.eval("window.nosefia374_accion || ''"))
	if accion == "checkpoint":
		var script_guardado: Script = load("res://src/sistemas/marco/guardado.gd")
		var script_serializado: Script = load("res://src/dominio/empleo/partida_serializada.gd")
		var guardado: RefCounted = script_guardado.new()
		var serializado: Dictionary = script_serializado.call("sanear", {"jornada": 3, "medios": 7})
		var correcto: bool = guardado.call("escribir", serializado)
		assert(correcto, "El fixture debe preparar un guardado real para CONTINUAR")
		print("[sonda] checkpoint real: jornada3/medios7")
	JavaScriptBridge.eval("window.nosefia374_accion = ''")
	JavaScriptBridge.eval("window.nosefia374_estado = " + JSON.stringify(estado))
