## Cuándo se puede leer la hora en el reloj de pared del local, y qué dice cuando se puede.
##
## **El GDD dice que la hora no está siempre a la vista**: se lee en la computadora y en este
## reloj, que deja de funcionar a mitad de una de las jornadas. No es cosmético — la tensión del
## juego es aritmética, y un número siempre visible la afloja: saber cuánto queda sale gratis.
## Fuera del HUD, enterarse cuesta caminar; y desde la noche en que el reloj se rompe, ni
## caminar alcanza.
##
## **Va en `dominio/` y no en el script del nodo**, y está medido: la misma sonda con esta regla
## escrita en `escenas/` da los dos gates en verde. Ahí nacería sin test y nadie lo diría.
##
## **La jornada y el tiempo entran por parámetro.** Este archivo no cuenta noches —eso es de la
## partida— ni mira el reloj del motor: es lo que permite probar la noche en que se rompe sin
## jugar tres.
##
## No reimplementa el formato ni el umbral de aviso: los dos se los pide a `Marcador`.
class_name RelojDePared
extends RefCounted

## La jornada de un reloj al que todavía nadie le declaró ninguna.
##
## Es **menor** que la que rompe a propósito, y por eso el reloj arranca andando: el primer
## cuadro llega antes de que el ciclo abra la noche, y un reloj que naciera roto se leería como
## un reloj mal cableado.
const JORNADA_SIN_DECLARAR := 0

## El reloj aguanta hasta la mitad del turno de esa noche. Se escribe como divisor y no como
## segundos para que el día que la noche dure otra cosa se siga rompiendo a la mitad.
const MITAD := 2.0


## Si la hora se puede leer en el reloj.
##
## Se rompe **y no se arregla**: las noches posteriores contestan `false` sin mirar el tiempo.
## Un reloj que volviera a andar al día siguiente sería uno que se descompuso, y lo que el GDD
## pide es uno roto.
static func hora_visible(jornada: int, restante: float) -> bool:
	if jornada < Reglas.JORNADA_EN_QUE_SE_ROMPE_EL_RELOJ_DE_PARED:
		return true
	if jornada > Reglas.JORNADA_EN_QUE_SE_ROMPE_EL_RELOJ_DE_PARED:
		return false
	return restante > Reglas.DURACION_DEL_TURNO / MITAD


## Lo que se lee en la esfera: el tiempo formateado, o nada.
##
## La cadena vacía y no un `"--:--"`: el reloj roto no dice que está roto, y darse cuenta es
## parte de lo que la noche cobra.
static func lectura(jornada: int, restante: float) -> String:
	if not hora_visible(jornada, restante):
		return ""
	return Marcador.reloj(restante)
