extends SceneTree


func _initialize() -> void:
	call_deferred("_montar")


func _montar() -> void:
	var script: Script = load(OS.get_environment("NOSEFIA444_FIXTURE"))
	var fixture: Node = script.new()
	root.add_child(fixture)
