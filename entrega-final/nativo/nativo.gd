extends SceneTree


func _initialize() -> void:
	call_deferred("_comenzar")


func _comenzar() -> void:
	var guion: Script = load(
		"C:/Users/fede_/AppData/Local/Temp/nosefia-batch-425-435/434-visual-final02/mapa.gd"
	)
	root.add_child(guion.new())
