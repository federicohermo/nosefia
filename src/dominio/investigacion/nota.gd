## Una nota del cuaderno: su título y su cuerpo.
##
## Una nota no hace nada, **es**. Qué llega a ser una nota y qué no lo decide `Cuaderno`, que es
## quien las escribe.
class_name Nota
extends RefCounted

var _titulo: String
var _texto: String


## Los argumentos van con el mismo nombre que los campos que asignan porque el prefijo `_` de los
## campos ya los distingue.
func _init(titulo: String, texto: String) -> void:
	_titulo = titulo
	_texto = texto


func titulo() -> String:
	return _titulo


## Puede estar vacío: el título alcanza para anotar algo al pasar, y exigir el cuerpo le cobraría
## segundos de turno a un recordatorio de dos palabras.
func texto() -> String:
	return _texto
