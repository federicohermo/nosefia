## La computadora del escritorio: si está abierta y en qué app.
##
## **Abrir, cerrar y cambiar de app son decisiones del juego, no del motor**, y por eso viven acá
## y no en la pantalla. Es la trampa central de este spec: `src/ui/` es la capa que
## `gate_de_tests.py` no mira, así que escritas allá arriba nacerían sin test y los seis nodos
## darían verde igual.
##
## **Y no consume tiempo.** Abrir la computadora no descuenta un segundo del turno: lo que cuesta
## es que el reloj no se detuvo mientras el jugador leía. Cobrarle además a cada clic cobraría
## dos veces lo mismo.
class_name Computadora
extends RefCounted

## Las tres del GDD, y no una cantidad cualquiera: la caja es tarea del jefe y los chats y las
## notas son investigación. Es lo que pone las dos puntas de la tensión a un clic una de otra.
##
## Es un `enum` y no un `String` porque el conjunto es cerrado: un `"chast"` no rompe nada, la
## pestaña simplemente no se abre nunca y el motor no dice una palabra.
enum App { CAJA, CHATS, NOTAS }

var _abierta: bool = false

## Sobrevive a `cerrar()` a propósito: reabrir vuelve a donde el jugador dejó, y eso le ahorra
## dos clics cada vez que va a atender y vuelve — o sea, tiempo de turno.
var _app: App = App.CAJA


func abierta() -> bool:
	return _abierta


func app() -> App:
	return _app


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


## Cambia de app, y devuelve `true` **sólo si cambió**.
##
## Con la computadora cerrada no cambia nada: dejar que cambie igual haría que reabrir apareciera
## en una app que el jugador nunca eligió.
func cambiar_a(otra: App) -> bool:
	if not _abierta or otra == _app:
		return false
	_app = otra
	return true
