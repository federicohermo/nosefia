## Cuándo se puede leer la hora en el reloj de mesa del local, y qué dice cuando se puede.
##
## **El GDD dice que la hora no está siempre a la vista**: se lee sólo en este reloj, al lado de
## la computadora, que deja de funcionar a mitad de una de las jornadas. No es cosmético — la
## tensión del juego es aritmética, y un número siempre visible la afloja: saber cuánto queda
## sale gratis. Fuera del HUD, enterarse cuesta caminar hasta el escritorio; y la noche en que el
## reloj falla, ni caminar alcanza.
##
## **Va en `dominio/` y no en el script del nodo**, y está medido: la misma sonda con esta regla
## escrita en `escenas/` da los dos gates en verde. Ahí nacería sin test y nadie lo diría.
##
## **La jornada y el tiempo entran por parámetro.** Este archivo no cuenta noches —eso es de la
## partida— ni mira el reloj del motor: es lo que permite probar la noche en que falla sin
## jugar tres.
##
## No reimplementa la hora: se la pide a `Marcador`.
class_name RelojDeMesa
extends RefCounted

## La jornada de un reloj al que todavía nadie le declaró ninguna.
##
## Es **distinta** de la que falla a propósito, y por eso el reloj arranca andando: el primer
## cuadro llega antes de que el ciclo abra la noche, y un reloj que naciera apagado se leería
## como un reloj mal cableado.
const JORNADA_SIN_DECLARAR := 0

## El reloj aguanta hasta la mitad del turno de esa noche. Se escribe como divisor y no como
## segundos para que el día que la noche dure otra cosa se siga apagando a la mitad.
const MITAD := 2.0


## Si la hora se puede leer en el reloj.
##
## Falla **una** noche y vuelve: las demás contestan `true` sin mirar el tiempo. Lo que el GDD
## pide es un reloj que deja de funcionar a mitad de una jornada, no uno roto para siempre.
static func hora_visible(jornada: int, restante: float) -> bool:
	if jornada != Reglas.JORNADA_EN_QUE_FALLA_EL_RELOJ:
		return true
	return restante > Reglas.DURACION_DEL_TURNO / MITAD


## Lo que se lee en el display: la hora de la noche, o nada.
##
## La cadena vacía y no un `"--:--"`: el reloj apagado no dice que está apagado, y darse cuenta
## es parte de lo que la noche cobra.
static func lectura(jornada: int, restante: float) -> String:
	if not hora_visible(jornada, restante):
		return ""
	return Marcador.hora(restante)
