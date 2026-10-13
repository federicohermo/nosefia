## El archivo de las preferencias: lo escribe y lo lee. Vive aparte del guardado de la partida,
## y borrar la partida no lo toca.
##
## Qué es legible y cómo se completa lo decide `Preferencias`. Acá sólo está el disco.
class_name ArchivoDePreferencias
extends RefCounted

## En la web, `user://` es el almacenamiento del navegador, igual que el del guardado: sobrevive
## a recargar la página.
const RUTA_DEL_USUARIO := "user://preferencias.datos"

## La corrida de tests la apunta a otra carpeta, igual que `Guardado`: las escenas leen sus
## preferencias solas, y las del usuario no pueden decidir un test ni ser pisadas por uno.
static var ruta_por_defecto: String = RUTA_DEL_USUARIO

var ruta: String = ruta_por_defecto


## Devuelve si la escritura llegó al disco. Una que falla no interrumpe a nadie.
func escribir(preferencias: Preferencias) -> bool:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return false
	return archivo.store_string(var_to_str(preferencias.datos()))


## Nunca falla: sin archivo, o con uno que no se puede leer, vuelven los defectos.
func cargar() -> Preferencias:
	if not FileAccess.file_exists(ruta):
		return Preferencias.new()
	var crudo: Variant = str_to_var(FileAccess.get_file_as_string(ruta))
	if crudo is not Dictionary:
		return Preferencias.new()
	return Preferencias.desde(crudo)


func borrar() -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ruta)
