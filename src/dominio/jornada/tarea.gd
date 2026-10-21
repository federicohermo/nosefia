## Una de las tareas obligatorias del turno: qué tipo es y si ya se hizo.
##
## No sabe cuántas hay ni cuáles son obligatorias esta noche: eso lo decide quien arma el
## `Turno`. Acá sólo vive el tipo y el estado de una.
class_name Tarea
extends RefCounted

## El conjunto es cerrado y por eso es un `enum` y no un `String`: `"limpar"` no rompe nada, el
## `if` simplemente no entra nunca y el motor no dice una palabra.
enum Tipo { CAJA, REPONER, REGISTRAR, LIMPIAR, SACAR_LA_BASURA, ORDENAR_LAS_CAJAS }
enum Estado { PENDIENTE, COMPLETADA, CONSOLIDADA }

var _tipo: Tipo
var _estado := Estado.PENDIENTE


func _init(tipo: Tipo) -> void:
	_tipo = tipo


func tipo() -> Tipo:
	return _tipo


func consolidar() -> void:
	if _estado == Estado.COMPLETADA:
		_estado = Estado.CONSOLIDADA


func completada() -> bool:
	return _estado != Estado.PENDIENTE


## Devuelve `true` **sólo si la marcó ahora**. Sobre una tarea ya completada devuelve `false` y
## no cambia nada, y es de ese `false` que se agarra `Turno` para no contarla dos veces sin
## llevar un registro propio de cuáles ya cumplió.
func completar() -> bool:
	if completada():
		return false
	_estado = Estado.COMPLETADA
	return true


## Devuelve `true` **sólo si la desmarcó ahora**, por el mismo motivo que `completar()`.
func descompletar() -> bool:
	if _estado != Estado.COMPLETADA:
		return false
	_estado = Estado.PENDIENTE
	return true
