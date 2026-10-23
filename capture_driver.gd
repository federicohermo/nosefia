extends Node

var fixture: RefCounted
var ocupado: bool = true


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
	await get_tree().process_frame
	fixture = load("res://test/escenas/captura_de_cami.gd").new()
	await fixture.call("crear", self)
	await fixture.call("llegar")
	await _command("front")
	print("[cami] ready")
	ocupado = false


func _process(_delta: float) -> void:
	if ocupado or fixture == null:
		return
	var command: Variant = JavaScriptBridge.eval("window.camiCommand || ''")
	if command is String and not command.is_empty():
		JavaScriptBridge.eval("window.camiCommand = ''")
		ocupado = true
		_command(command)


func _command(command: String) -> void:
	var pose: Dictionary = {}
	match command:
		"front", "left", "right", "transparent":
			var side: float = -0.35 if command == "left" else 0.35 if command == "right" else 0.0
			pose = await fixture.call("mirar", command == "transparent", side)
		"talk", "world":
			await fixture.call("clic")
			await fixture.call("cuadros", 16)
		"fede":
			await fixture.call("llegar", true)
			pose = await fixture.call("mirar")
		"reset":
			fixture.get("local").get("_ciclo").abrir_la_jornada()
			await fixture.call("llegar")
			pose = await fixture.call("mirar")
		_:
			if command.begins_with("frame"):
				var sprite: AnimatedSprite3D = fixture.call("figura")
				sprite.set_frame_and_progress(command.trim_prefix("frame").to_int(), 0.0)
				pose = await fixture.call("mirar")
	await fixture.call("cuadros")
	var sprite: AnimatedSprite3D = fixture.call("figura")
	var puesto: Node3D = fixture.call("puesto")
	var frames: Array[Dictionary] = []
	for index: int in sprite.sprite_frames.get_frame_count(&"idle"):
		var texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"idle", index)
		frames.append(
			{
				"path": texture.resource_path,
				"width": texture.get_width(),
				"height": texture.get_height()
			}
		)
	var state: Dictionary = {
		"command": command,
		"visible": sprite.visible,
		"frame": sprite.frame,
		"resource": sprite.sprite_frames.resource_path,
		"frames": frames,
		"panel": puesto.get("panel").visible,
		"outline": sprite.material_overlay != null,
		"pose": pose,
		"cached_images": puesto.get("objetivo").get("_imagenes").size(),
		"retreats": puesto.get("_retiradas").size(),
	}
	JavaScriptBridge.eval("window.camiState = " + JSON.stringify(state))
	print("[cami] " + JSON.stringify(state))
	ocupado = false
