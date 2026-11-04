## Qué dice el reloj de pared del local.
##
## **El GDD dice que la hora no está siempre a la vista**: se lee sólo en este reloj. No es
## cosmético — la tensión del juego es aritmética, y un número siempre visible la afloja: saber
## cuánto queda sale gratis. Fuera del HUD, enterarse cuesta caminar hasta él; y la sexta noche,
## con el corte de luz, ni caminar alcanza: queda leyendo la hora del corte hasta el cierre.
##
## **Va en `dominio/` y no en el script del nodo**, y está medido: la misma sonda con esta regla
## escrita en `escenas/` da los dos gates en verde. Ahí nacería sin test y nadie lo diría.
##
## **La jornada y el tiempo entran por parámetro.** Este archivo no cuenta noches —eso es de la
## partida— ni mira el reloj del motor: es lo que permite probar la noche del corte sin jugar tres.
##
## No reimplementa la hora: se la pide a `Marcador`.
class_name RelojDeMesa
extends RefCounted

## La jornada de un reloj al que todavía nadie le declaró ninguna.
##
## El primer cuadro llega antes de que el ciclo abra la noche, y el reloj lee entonces la hora
## de una noche cualquiera.
const JORNADA_SIN_DECLARAR := 0


## Lo que se lee en el display: la hora de la noche. La del corte de luz se queda leyendo la hora
## a la que se cortó hasta el cierre, y nunca queda en blanco.
static func lectura(jornada: int, restante: float) -> String:
	if AnomaliasDeLaJornada.reloj_detenido(jornada, restante):
		return Marcador.hora(AnomaliasDeLaJornada.restante_al_cortar())
	return Marcador.hora(restante)
