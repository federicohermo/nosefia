## La computadora del escritorio: si la terminal de ventas está abierta.
##
## **Abrir y cerrar son decisiones del juego, no del motor**, y por eso viven acá
## y no en la pantalla. Es la trampa central de este spec: `src/ui/` es la capa que
## `gate_de_tests.py` no mira, así que escritas allá arriba nacerían sin test y los nodos
## darían verde igual.
##
## **Y no consume tiempo.** Abrir la computadora no descuenta un segundo del turno: lo que cuesta
## es que el reloj no se detuvo mientras el jugador leía. Cobrarle además a cada clic cobraría
## dos veces lo mismo.
class_name Computadora
extends RefCounted

var _abierta: bool = false
var _se_ofrece_la_conjunta: bool = false
var _conjunta: bool = false


func abierta() -> bool:
	return _abierta


## Devuelve `true` **sólo si la abrió ahora**.
##
## De ese `false` se agarra la escena para no volver a suspender al jugador ni a repintar la
## pantalla en cada clic sobre el mismo escritorio.
func abrir() -> bool:
	if _abierta:
		return false
	_abierta = true
	_conjunta = false
	return true


func cerrar() -> bool:
	if not _abierta:
		return false
	_abierta = false
	_conjunta = false
	return true


## Si la jornada ofrece la pantalla conjunta del registro y el celular. Cambiar de jornada la
## deja en la pantalla normal.
func ofrecer_la_conjunta(se_ofrece: bool) -> void:
	_se_ofrece_la_conjunta = se_ofrece
	_conjunta = false


func conjunta_ofrecida() -> bool:
	return _se_ofrece_la_conjunta


func conjunta() -> bool:
	return _conjunta


## Pasa de la pantalla normal a la conjunta y de la conjunta a la normal. Devuelve `true` sólo si
## cambió: con la computadora cerrada, o en una jornada que no la ofrece, no hace nada.
func alternar_la_conjunta() -> bool:
	if not _abierta or not _se_ofrece_la_conjunta:
		return false
	_conjunta = not _conjunta
	return true


## Devuelve `true` sólo si estaba en la conjunta.
func volver_a_la_normal() -> bool:
	if not _conjunta:
		return false
	_conjunta = false
	return true
