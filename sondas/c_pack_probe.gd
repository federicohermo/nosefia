extends SceneTree

func _initialize() -> void:
	var source: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.READ)
	var paths: Array = JSON.parse_string(source.get_as_text())
	var loaded: Array[Resource] = []
	for path: String in paths:
		var resource: Resource = load(path)
		if resource == null:
			push_error("Falta recurso seleccionado: " + path)
			quit(1)
			return
		loaded.append(resource)
	print("[pack] ", loaded.size(), " raíces cargadas sin recursos ausentes")
	quit(0)
