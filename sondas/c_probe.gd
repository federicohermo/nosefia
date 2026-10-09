extends Node

func _ready() -> void:
	_ejecutar.call_deferred()

func _capturar(nombre: String) -> void:
	for cuadro: int in 35:
		await RenderingServer.frame_post_draw
	print("[etapa] ", nombre)
	while JavaScriptBridge.eval("window.__capturada !== '" + nombre + "'"):
		await RenderingServer.frame_post_draw

func _ejecutar() -> void:
	# RAICES_EXPORT
	var tabla: TablaDeSonidos = TablaDeSonidos.desde_disco()
	if tabla == null or not tabla.cubre_todos():
		push_error("Falta la tabla de sonidos o sus eventos")
		return
	for quien: Conversacion.Interlocutor in Conversacion.Interlocutor.values():
		var conversacion: Conversacion = Conversacion.de(quien)
		if conversacion == null:
			push_error("Falta conversación dinámica")
			return
	print("[dinamicos] audio y tres conversaciones OK")
	var rutas: Array[String] = ["res://src/escenas/menu_de_inicio.tscn", "res://src/ui/diegetica/pantalla_de_computadora.tscn", "res://src/ui/diegetica/panel_de_la_ventanilla.tscn"]
	var nombres: Array[String] = ["inicio", "computadora", "ventanilla"]
	for indice: int in rutas.size():
		var escena: Node = load(rutas[indice]).instantiate()
		if indice == 0:
			(escena.get("_guardado") as Guardado).ruta = "user://medicion.guardado"
		add_child(escena)
		if indice == 1:
			escena.call("mostrar", 0)
		if indice == 2:
			escena.call("mostrar_sin_nadie")
		await _capturar(nombres[indice])
		if indice > 0:
			var pantalla: CanvasLayer = escena as CanvasLayer
			escena.call("ocultar")
			if pantalla.visible:
				push_error("La interfaz no se cerró")
				return
			if indice == 1:
				escena.call("mostrar", 0)
			else:
				escena.call("mostrar_sin_nadie")
			if not pantalla.visible:
				push_error("La interfaz no se abrió")
				return
			print("[apertura-cierre] ", nombres[indice], " OK")
		remove_child(escena)
		escena.free()
	print("[fin] OK")
