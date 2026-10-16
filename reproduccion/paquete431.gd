extends SceneTree

var _fallos: Array[String] = []


func _initialize() -> void:
	create_timer(90.0).timeout.connect(_vencer)
	_ejercer.call_deferred()


func _vencer() -> void:
	push_error("PAQUETE431: tiempo máximo sin final")
	quit(1)


func _exigir(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos.append(mensaje)
		push_error("PAQUETE431: " + mensaje)


func _ejercer() -> void:
	var clase_partida: Script = load("res://src/dominio/empleo/partida.gd")
	var politica: Script = load("res://src/dominio/empleo/politica_de_guardado.gd")
	var partida: RefCounted = clase_partida.call("nueva")
	partida.call("abrir_la_jornada")
	var tareas: Array = partida.call("obligatorias")
	for tarea: RefCounted in tareas:
		tarea.call("completar")
	partida.call("cerrar_la_jornada", tareas.size())
	var datos: Dictionary = politica.call("datos", partida)
	var argumentos := OS.get_cmdline_user_args()
	if not argumentos.is_empty():
		var archivo := FileAccess.open(argumentos[0], FileAccess.WRITE)
		_exigir(archivo != null, "no se pudo crear el checkpoint de prueba")
		if archivo != null:
			archivo.store_string(var_to_str(datos))
			archivo.close()
	var escena := load("res://src/escenas/almacen.tscn") as PackedScene
	_exigir(escena != null, "no cargó el almacén exportado")
	if escena == null:
		quit(1)
		return
	var local := escena.instantiate() as Node3D
	local.set("_partida", partida)
	root.add_child(local)
	local.get_node("Interfaz/PersianaDeLaNoche").call("terminar")
	for _cuadro: int in 3:
		await process_frame
	(local.get("_reloj") as Node).set_process(false)
	var celular: Node = local.get("_celular")
	var bandeja: RefCounted = celular.call("bandeja")
	var conversaciones: Array = bandeja.call("conversaciones")
	_exigir(conversaciones.size() == 2, "el paquete perdió alguno de los chats de J2")
	var yasmin: Array = bandeja.call("mensajes_de", 3)
	_exigir(yasmin.size() == 15, "el paquete no tiene los quince mensajes de Yasmín")
	for indice: int in yasmin.size():
		_exigir(
			yasmin[indice].get("identidad") == "J2_%d" % (indice + 1),
			"identidad de Yasmín fuera de orden"
		)
	var jefe: Array = bandeja.call("mensajes_de", 0)
	_exigir(jefe.size() == 23, "instrucciones, devolución1 y apertura2 deben sumar23")
	if jefe.size() >= 23:
		_exigir(jefe[19].get("momento") == 1, "la devolución1 no precede apertura2")
		_exigir(jefe[21].get("foto") != null, "el paquete no contiene foto del contenedor")
		_exigir(jefe[22].get("identidad") == "J2_CONTENEDOR_TEXTO", "la foto perdió su adjunto")
	var pedidos: Array[String] = []
	celular.connect(
		"tramo_de_pista_pedido", func(identidad: String) -> void: pedidos.append(identidad)
	)
	celular.call("pedir_alternar", false)
	var pantalla: Node = local.get("_pantalla_del_celular")
	var lista: VBoxContainer = pantalla.get("_mensajes")
	var resumen := lista.get_child(1).find_child("VistaPrevia", true, false) as Label
	for codigo: int in [0x2728, 0x1f4aa]:
		_exigir(
			resumen.get_theme_font("font").has_char(codigo), "el preview perdió un glifo portable"
		)
	var simbolos := load("res://assets/ui/manada/celular/simbolos_de_chat.ttf") as FontFile
	var huella := HashingContext.new()
	huella.start(HashingContext.HASH_SHA256)
	huella.update(simbolos.data)
	_exigir(
		(
			huella.finish().hex_encode()
			== "af469b9aea3c3e278a8def15a63d87f67264254b7c77823b871c5ba74b6fc4ed"
		),
		"la fuente exportada no conserva el TTF con licencia completa"
	)
	celular.call("pedir_chat", 3)
	_exigir(_rotulos(lista) == ["HOY"], "Yasmín exportada no tiene HOY")
	for caso: Vector2i in [Vector2i(0, 0x2728), Vector2i(14, 0x1f4aa)]:
		var texto := (
			_burbuja(lista, caso.x).find_children("*", "RichTextLabel", true, false)[0]
			as RichTextLabel
		)
		_exigir(texto.get_theme_font("normal_font").has_char(caso.y), "una burbuja perdió su glifo")
	celular.call("pedir_tramo", "J2_6", "fuera")
	_exigir(pedidos.is_empty(), "un tramo ajeno pidió una pista")
	celular.call("pedir_tramo", "J2_6", "falta_algo")
	_exigir(pedidos == ["2A"], "el tramo exportado no pidió2A")
	celular.call("pedir_volver")
	celular.call("pedir_chat", 0)
	_exigir(_rotulos(lista) == ["AYER", "HOY"], "Enrique exportado no separa J1/J2")
	celular.call("pedir_foto", 21)
	var imagen: TextureRect = pantalla.get("_imagen")
	var adjunto: RichTextLabel = pantalla.get("_adjunto")
	_exigir(imagen.texture != null, "la ampliación no tiene textura")
	_exigir(
		adjunto.text.contains("todos los tachos del local en el contenedor"),
		"el adjunto no es la apertura2"
	)
	celular.call("pedir_cerrar_foto")
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in local.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	local.queue_free()
	local = null
	celular = null
	bandeja = null
	pantalla = null
	simbolos = null
	partida = null
	tareas.clear()
	jefe.clear()
	yasmin.clear()
	conversaciones.clear()
	for _cuadro: int in 4:
		await process_frame
	print("PAQUETE431_FINAL fallos=%d" % _fallos.size())
	quit(0 if _fallos.is_empty() else 1)


func _burbuja(lista: VBoxContainer, indice: int) -> PanelContainer:
	for hijo: Node in lista.get_children():
		if hijo.has_meta("indice_de_mensaje") and int(hijo.get_meta("indice_de_mensaje")) == indice:
			return hijo as PanelContainer
	return null


func _rotulos(lista: VBoxContainer) -> Array[String]:
	var rotulos: Array[String] = []
	for hijo: Node in lista.get_children():
		if hijo is Label:
			rotulos.append(hijo.text)
	return rotulos
