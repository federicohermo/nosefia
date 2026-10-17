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
	return true


func cerrar() -> bool:
	if not _abierta:
		return false
	_abierta = false
	return true
