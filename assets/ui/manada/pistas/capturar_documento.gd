## Captura el documento impreso examinado, con la mano y la cámara reales del jugador. La salida
## siempre se indica fuera del checkout.
extends SceneTree

const JORNADA_DEL_DOCUMENTO := 6

var _local: Node3D
var _fallos: Array[String] = []


func _init() -> void:
	call_deferred("_capturar")


func _exigir(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos.append(mensaje)
		printerr("FOTO789_FALLO ", mensaje)


func _cuadros(cantidad: int = 4) -> void:
	for _cuadro: int in cantidad:
		await process_frame


func _capturar() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or OS.get_environment("NOSEFIA_CAPTURA_AISLADA") != "789":
		printerr(
			"Indicar salida externa y ejecutar con APPDATA aislado y NOSEFIA_CAPTURA_AISLADA=789"
		)
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		printerr("La foto requiere un motor que dibuje")
		quit(1)
		return
	var salida := args[0]
	var proyecto := ProjectSettings.globalize_path("res://").simplify_path()
	if not salida.is_absolute_path() or salida.simplify_path().begins_with(proyecto):
		printerr("La salida debe ser absoluta y externa al checkout")
		quit(1)
		return
	root.size = Vector2i(1536, 1024)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var guardado: Script = load("res://src/sistemas/marco/guardado.gd")
	guardado.set("ruta_por_defecto", "user://foto_documento_789.guardado")
	var serializada: Script = load("res://src/dominio/empleo/partida_serializada.gd")
	var escrito: bool = guardado.new().call(
		"escribir", serializada.call("sanear", {"jornada": JORNADA_DEL_DOCUMENTO, "medios": 0})
	)
	_exigir(escrito, "No se puede escribir la partida de la jornada del documento")
	_local = (load("res://src/escenas/almacen.tscn") as PackedScene).instantiate()
	root.add_child(_local)
	_local.get_node("Interfaz/PersianaDeLaNoche").call("terminar")
	(_local.get("_reloj") as Node).set_process(false)
	await _cuadros(5)
	var expediente: RefCounted = (_local.get("_partida") as RefCounted).get("expediente")
	var cuarta := JORNADA_DEL_DOCUMENTO - 2
	for paso: Array in [["2A", cuarta], ["5A", cuarta + 1]]:
		expediente.call("registrar", paso[0])
		expediente.call("elegir", paso[1], paso[0])
	_local.call("_al_abrir_la_jornada", JORNADA_DEL_DOCUMENTO)
	await _cuadros(5)
	for interfaz: Node in _local.get_node("Interfaz").get_children():
		if interfaz is CanvasLayer:
			interfaz.hide()
	var documento := _local.get_node_or_null("Objetos/DocumentoImpreso") as RigidBody3D
	_exigir(
		documento != null and documento.is_visible_in_tree(), "El documento no está en el local"
	)
	var jugador := _local.get("_jugador") as CharacterBody3D
	var agarre: Node = _local.get("_agarre")
	if documento != null and documento.is_visible_in_tree():
		_exigir(
			bool(agarre.call("pedir_agarrar", documento.get("datos"), documento)),
			"No se levanta el documento"
		)
		_exigir(bool(jugador.get("examen").call("iniciar")), "No arranca el examen")
	await _cuadros(30)
	await RenderingServer.frame_post_draw
	var imagen := root.get_texture().get_image()
	_exigir(imagen.get_size() == Vector2i(1536, 1024), "El encuadre no es el pedido")
	if _fallos.is_empty():
		DirAccess.make_dir_recursive_absolute(salida.get_base_dir())
		_exigir(imagen.save_png(salida) == OK, "No se puede guardar la foto")
	await _terminar()


func _terminar() -> void:
	if is_instance_valid(_local):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _local.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_local.queue_free()
		await _cuadros()
	print("FOTO789_FINAL fallos=", _fallos.size())
	quit(0 if _fallos.is_empty() else 1)
