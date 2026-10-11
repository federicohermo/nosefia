extends "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"

const DESTINO := (
	"C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010/" + "374-cache-resolver.json"
)


func _finalize() -> void:
	var entradas: Dictionary = {}
	for nombre: String in GdInlineParameterSetResolver._resolved_user_classes:
		var script: GDScript = GdInlineParameterSetResolver._resolved_user_classes[nombre]
		entradas[nombre] = script.resource_path
	var archivo := FileAccess.open(DESTINO, FileAccess.WRITE)
	archivo.store_string(JSON.stringify(entradas, "\t"))
	archivo.close()
	super._finalize()
