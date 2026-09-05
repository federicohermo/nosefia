## Una de las tareas obligatorias del turno: qué tipo es, cuánto cuesta y si ya se hizo.
##
## No sabe cuántas hay ni cuáles son obligatorias esta noche: eso lo decide quien arma el
## `Turno`. Acá sólo vive el tipo y el estado de una.
class_name Tarea
extends RefCounted

## El conjunto es cerrado y por eso es un `enum` y no un `String`: `"limpar"` no rompe nada, el
## `if` simplemente no entra nunca y el motor no dice una palabra.
enum Tipo { CAJA, REPONER, REGISTRAR, LIMPIAR, SACAR_LA_BASURA }

var _tipo: Tipo
var _completada: bool = false


func _init(tipo: Tipo) -> void:
	_tipo = tipo


func tipo() -> Tipo:
	return _tipo


## El costo se le pide a `Reglas` cada vez en lugar de copiarlo en el `_init`: si se copiara,
## rebalancear `reglas.gd` dejaría a las tareas ya construidas con el número viejo.
func costo() -> float:
	return Reglas.costo_de(_tipo)


func completada() -> bool:
	return _completada


## Devuelve `true` **sólo si la marcó ahora**. Sobre una tarea ya completada devuelve `false` y
## no cambia nada, y es de ese `false` que se agarra `Turno` para no contarla ni cobrarla dos
## veces sin llevar un registro propio de cuáles ya cumplió.
func completar() -> bool:
	if _completada:
		return false
	_completada = true
	return true
