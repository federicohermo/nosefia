## El único archivo de la partida: lo escribe, lo lee y lo borra.
##
## Qué es legible y cómo se completa lo decide `PartidaSerializada`. Acá sólo está el disco.
class_name Guardado
extends RefCounted

const RUTA_DEL_USUARIO := "user://partida.guardado"

## La corrida de tests la apunta a otra carpeta: las escenas arman su guardado solas, y la
## partida del usuario no puede decidir un test ni ser pisada por uno.
static var ruta_por_defecto: String = RUTA_DEL_USUARIO

var ruta: String = ruta_por_defecto


## Devuelve si la escritura llegó al disco. Una que falla no interrumpe a nadie.
func escribir(datos: Dictionary) -> bool:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return false
	return archivo.store_string(var_to_str(datos))


## Vacío sin archivo, y vacío con una versión futura, que queda en disco. Un archivo que no se
## puede leer se borra, para que el arranque siguiente no vuelva a tropezar con él.
func cargar() -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var crudo: Variant = str_to_var(FileAccess.get_file_as_string(ruta))
	if crudo is not Dictionary:
		borrar()
		return {}
	if not PartidaSerializada.legible(crudo):
		return {}
	return PartidaSerializada.sanear(crudo)


func borrar() -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ruta)


func hay_guardado() -> bool:
	return not cargar().is_empty()
