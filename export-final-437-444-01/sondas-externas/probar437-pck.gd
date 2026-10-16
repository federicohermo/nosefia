extends SceneTree

var _fallos: Array[String] = []


func _initialize() -> void:
	call_deferred("_probar")


func _exigir(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos.append(mensaje)
		push_error("SPRITES437: " + mensaje)


func _probar() -> void:
	for carpeta: String in ["fede", "mia"]:
		var cuadros := load("res://assets/characters/%s/idle.tres" % carpeta) as SpriteFrames
		_exigir(cuadros != null, "Falta SpriteFrames de " + carpeta)
		if cuadros == null:
			continue
		_exigir(cuadros.get_frame_count(&"idle") == 8, "Faltan dibujos")
		_exigir(cuadros.get_animation_loop(&"idle"), "No tiene bucle")
		_exigir(cuadros.get_animation_speed(&"idle") == 2.0, "Cambió ritmo")
		for indice in 8:
			var textura := cuadros.get_frame_texture(&"idle", indice)
			_exigir(textura != null, "Falta textura")
			if textura != null:
				_exigir(textura.get_size() == Vector2(1086, 1448), "Cambió resolución")
				_exigir(
					(
						textura.resource_path
						== "res://assets/characters/%s/%02d.png" % [carpeta, indice + 1]
					),
					"Cambió orden"
				)
				_exigir(cuadros.get_frame_duration(&"idle", indice) == 1.0, "Cambió duración")
	call_deferred("_salir")


func _salir() -> void:
	print("SPRITES437_PCK_FINAL fallos=%d" % _fallos.size())
	if _fallos.is_empty():
		print("SPRITES437_PCK_OK")
	quit(0 if _fallos.is_empty() else 1)
