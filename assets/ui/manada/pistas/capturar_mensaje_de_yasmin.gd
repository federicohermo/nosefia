## Captura el mensaje de Yasmín con la queja de 2A tal como lo dibuja el celular. La salida
## siempre se indica fuera del checkout.
extends SceneTree

const MARGEN := 16.0

var _fallos: Array[String] = []


func _init() -> void:
	call_deferred("_capturar")


func _exigir(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos.append(mensaje)
		printerr("FOTO2A_FALLO ", mensaje)


func _cuadros(cantidad: int) -> void:
	for _cuadro: int in cantidad:
		await process_frame


func _capturar() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Indicar la salida, absoluta y externa al checkout")
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
	root.size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var escena := load("res://src/ui/diegetica/pantalla_del_celular.tscn") as PackedScene
	var pantalla := escena.instantiate() as PantallaDelCelular
	root.add_child(pantalla)
	await _cuadros(2)
	var yasmin := Conversacion.de(Conversacion.Interlocutor.YASMIN)
	var bandeja := Bandeja.new([yasmin])
	bandeja.abrir_jornada(2)
	var mensajes := bandeja.mensajes_de(Conversacion.Interlocutor.YASMIN)
	pantalla.subir()
	pantalla.mostrar_chat(yasmin, mensajes, true, 2)
	await _cuadros(40)
	var burbuja: PanelContainer = null
	for candidata: PanelContainer in pantalla.get("_burbujas"):
		if mensajes[int(candidata.get_meta("indice_de_mensaje"))].pista == "2A":
			burbuja = candidata
	_exigir(burbuja != null, "Falta el mensaje de Yasmín que dispara 2A")
	if burbuja != null:
		var historial := pantalla.get("_scroll") as ScrollContainer
		historial.scroll_vertical = int(burbuja.position.y - historial.size.y / 3.0)
		await _cuadros(4)
		await RenderingServer.frame_post_draw
		var visible := (pantalla.get("_scroll") as ScrollContainer).get_global_rect()
		var region := burbuja.get_global_rect().grow(MARGEN)
		_exigir(visible.encloses(burbuja.get_global_rect()), "El mensaje no está entero a la vista")
		var imagen := root.get_texture().get_image().get_region(Rect2i(region))
		if _fallos.is_empty():
			DirAccess.make_dir_recursive_absolute(salida.get_base_dir())
			_exigir(imagen.save_png(salida) == OK, "No se puede guardar la foto")
	print("FOTO2A_FINAL fallos=", _fallos.size())
	quit(0 if _fallos.is_empty() else 1)
