## Mezcla el atlas de un horneado con el de otro, en su lugar. Lo lanza `hornear.py`.
##
##     godot --headless --path . -s res://addons/hornear/mezclar_horneados.gd -- \
##         BASE.lmbake BASE.exr OTRO.lmbake OTRO.exr NIVEL
##
## El resultado reemplaza a `BASE.exr`. Cada `.lmbake` dice dónde está cada pieza en su atlas: ver
## `mezcla.gd`. Sale con 0 sólo si la mezcla entró entera. Con otro código `hornear.py` devuelve
## los archivos a como estaban.
extends SceneTree

const Mezcla := preload("res://addons/hornear/mezcla.gd")


func _initialize() -> void:
	quit(_mezclar(OS.get_cmdline_user_args()))


func _mezclar(argumentos: PackedStringArray) -> int:
	if argumentos.size() != 5 or not argumentos[4].is_valid_float():
		printerr("[mezclar] error: se esperan BASE.lmbake BASE.exr OTRO.lmbake OTRO.exr NIVEL")
		return 2
	var piezas_base := _piezas(argumentos[0])
	var piezas_otro := _piezas(argumentos[2])
	var base := Image.load_from_file(ProjectSettings.globalize_path(argumentos[1]))
	var otro := Image.load_from_file(ProjectSettings.globalize_path(argumentos[3]))
	if base == null or otro == null or piezas_base.is_empty() or piezas_otro.is_empty():
		printerr("[mezclar] error: no pude leer los dos horneados")
		return 1
	if base.get_size() != otro.get_size():
		printerr("[mezclar] error: los atlas miden %s y %s" % [base.get_size(), otro.get_size()])
		return 1
	var resultado := Mezcla.mezclar(base, otro, piezas_base, piezas_otro, argumentos[4].to_float())
	if resultado.sin_par > 0:
		printerr("[mezclar] error: %d piezas sin par en el otro horneado" % resultado.sin_par)
		return 1
	var error := resultado.imagen.save_exr(ProjectSettings.globalize_path(argumentos[1]))
	if error != OK:
		printerr("[mezclar] error: no pude guardar el atlas (%s)" % error_string(error))
		return 1
	@warning_ignore("integer_division")
	var piezas: int = piezas_base.size() / Mezcla.CAMPOS_POR_PIEZA
	print("[mezclar] %d piezas mezcladas a nivel %s" % [piezas, argumentos[4]])
	return 0


func _piezas(ruta: String) -> Array:
	var datos := load(ruta) as LightmapGIData
	if datos == null:
		return []
	return datos.get("user_data")
