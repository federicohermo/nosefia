## El archivo de los logros: lo escribe y lo lee. Vive aparte del guardado de la partida y de las
## preferencias, y borrar la partida no lo toca.
##
## Qué es legible lo decide `Logros`. Acá sólo está el disco.
class_name ArchivoDeLogros
extends RefCounted

## En la web, `user://` es el almacenamiento del navegador, igual que el del guardado: sobrevive
## a recargar la página.
const RUTA_DEL_USUARIO := "user://logros.datos"

## La corrida de tests la apunta a otra carpeta, igual que `Guardado`: las escenas desbloquean
## solas, y los logros del usuario no pueden decidir un test ni ser pisados por uno.
static var ruta_por_defecto: String = RUTA_DEL_USUARIO

var ruta: String = ruta_por_defecto


## Devuelve si la escritura llegó al disco. Una que falla no interrumpe a nadie.
func escribir(logros: Logros) -> bool:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return false
	return archivo.store_string(var_to_str(logros.datos()))


## Nunca falla: sin archivo, o con uno que no se puede leer, no hay nada desbloqueado.
func cargar() -> Logros:
	if not FileAccess.file_exists(ruta):
		return Logros.new()
	var crudo: Variant = str_to_var(FileAccess.get_file_as_string(ruta))
	if crudo is not Dictionary:
		return Logros.new()
	return Logros.desde(crudo)


func borrar() -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ruta)
