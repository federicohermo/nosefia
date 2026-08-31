## Los números del turno, ya formateados, y el umbral con el que la pantalla cambia de tono.
##
## **La frontera con `ui/` se dice en una línea: acá viven los números, allá las palabras.**
## `"01:30"` y `"3/4"` son números formateados; «Te quedan», «Apercibimientos» y el color del
## reloj son de la pantalla.
##
## El umbral está acá y no en el HUD porque es **un número que decide**, y un número que decide
## en `ui/` nace sin test: es exactamente la trampa que describe `.claude/rules/presentacion.md`.
class_name Marcador
extends RefCounted

const SEGUNDOS_POR_MINUTO := 60
const MINUTOS_POR_HORA := 60
const SEGUNDOS_POR_HORA := SEGUNDOS_POR_MINUTO * MINUTOS_POR_HORA

## Media hora de ficción. Es un primer valor de balance, no una medición, y moverlo no toca ni
## el reloj de la escena ni el HUD: los dos preguntan acá.
const SEGUNDOS_DE_AVISO := 1800.0

## Lo que queda del turno, en un texto que se lee de un vistazo.
##
## Cambia de forma en la hora porque un turno entero en minutos puros daría `"480:00"`, que
## nadie lee como ocho horas.
##
## **Trunca y no redondea**, y por debajo de cero devuelve el cero: mostrar `"01:00"` cuando ya
## no queda un minuto entero es mentirle al jugador justo cuando el número importa, y un
## `"-00:00"` es un tiempo imposible.
@warning_ignore("integer_division")
static func reloj(restante: float) -> String:
	var segundos := int(maxf(0.0, restante))
	var horas := segundos / SEGUNDOS_POR_HORA
	var minutos := segundos / SEGUNDOS_POR_MINUTO
	var resto := segundos % SEGUNDOS_POR_MINUTO
	if horas > 0:
		return "%d:%02d:%02d" % [horas, minutos % MINUTOS_POR_HORA, resto]
	return "%02d:%02d" % [minutos, resto]


## Si lo que queda ya entra en la franja en la que el HUD pinta el reloj distinto.
static func en_aviso(restante: float) -> bool:
	return restante <= SEGUNDOS_DE_AVISO


## Cuántas obligatorias van sobre cuántas se declararon.
##
## La cantidad declarada entra por argumento y nunca está escrita acá: el 001 dejó la quinta
## tarea como dato, y este archivo no la vuelve a decidir.
static func tareas(cumplidas: int, obligatorias: int) -> String:
	return "%d/%d" % [cumplidas, obligatorias]
