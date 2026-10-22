extends Node

const CARGA := preload("res://src/ui/interrupciones/pantalla_de_carga.tscn")


func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.body.dataset.version = '3'")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var argumentos := OS.get_cmdline_user_args()
	var ancho := int(argumentos[0]) if argumentos.size() > 0 else 1280
	var alto := int(argumentos[1]) if argumentos.size() > 1 else 720
	var etiqueta := argumentos[2] if argumentos.size() > 2 else "despues"
	DisplayServer.window_set_size(Vector2i(ancho, alto))
	await get_tree().process_frame
	var presentaciones: Array[int] = [0, 1]
	if OS.has_feature("web"):
		presentaciones = [int(JavaScriptBridge.eval("new URLSearchParams(location.search).get('p') || '0'"))]
	for presentacion: int in presentaciones:
		var padre: Node = Control.new() if presentacion == 0 else Node3D.new()
		if padre is Control:
			padre.theme = load("res://assets/ui/manada/tema.tres")
		add_child(padre)
		var persiana: PersianaDeLaNoche
		if presentacion == 1:
			persiana = load("res://src/ui/interrupciones/persiana_de_la_noche.tscn").instantiate()
			padre.add_child(persiana)
			persiana.mostrar_baja()
		var capa := CanvasLayer.new()
		capa.layer = 10
		var pantalla: PantallaDeCarga = CARGA.instantiate()
		pantalla.presentacion = presentacion
		capa.add_child(pantalla)
		padre.add_child(capa)
		pantalla.mostrar()
		pantalla.pintar(0.5)
		await get_tree().process_frame
		await get_tree().process_frame
		var texto: Label = pantalla.get("_texto")
		var barra: ProgressBar = pantalla.get("_barra")
		print("MEDIDA ", JSON.stringify({"presentacion": presentacion, "pantalla": pantalla.size, "marco": pantalla.get("_marco").scale, "barra": barra.get_global_rect(), "letra": texto.get_theme_font_size("font_size"), "fuente": texto.get_theme_font("font").resource_path, "texto": texto.get_global_rect()}))
		if OS.has_feature("web"):
			JavaScriptBridge.eval("document.body.dataset.presentacion = '%d'" % presentacion)
			JavaScriptBridge.eval("document.body.dataset.medida = '%s'" % JSON.stringify({"barra_pos": barra.get_global_rect().position, "barra_size": barra.get_global_rect().size, "fuente": texto.get_theme_font("font").resource_path, "letra": texto.get_theme_font_size("font_size"), "texto": texto.get_global_rect()}))
			return
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/%s-%dx%d-%d.png" % [etiqueta, ancho, alto, presentacion])
		if presentacion == 1:
			await get_tree().create_timer(0.15).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/%s-%dx%d-pulso.png" % [etiqueta, ancho, alto])
		padre.queue_free()
		await get_tree().process_frame
	if OS.has_feature("web"):
		return
	get_tree().quit()
