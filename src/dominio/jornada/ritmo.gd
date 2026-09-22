## La conversión entre el reloj de pared y el reloj del turno.
##
## Una noche entera de ficción no puede durar una noche entera de sesión, así que el tiempo del
## juego corre más rápido que el real y este archivo es el único que sabe cuánto.
##
## **No vive en `reglas.gd` a propósito, y son tres razones.** El libro de reglas del turno lo
## lee el dominio entero, y este factor lo lee sólo `sistemas/`. El 001 decidió que `Turno` no
## sabe que existe un reloj real —el tiempo le entra por parámetro, y es lo que lo hace
## testeable—, y meter la conversión ahí adentro pondría en el libro un número que el turno tiene
## prohibido usar. Y son dos specs distintos escribiendo el mismo archivo por nada.
##
## Es un primer valor y se ajusta jugando. Ajustarlo no toca ni el reloj de la escena ni el HUD:
## los dos lo piden acá.
class_name Ritmo
extends RefCounted

## De dónde sale: una sesión de veinte minutos reales tiene que cubrir el turno de ocho horas
## que declara `Reglas.DURACION_DEL_TURNO`, y `20 · 60 · 24 = 28 800`. Cambiar uno de los dos
## sin recalcular el otro deja la noche terminando antes o después de que se acabe la sesión, y
## eso lo caza `ritmo_test.gd`.
const SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL := 24.0


## Cuántos segundos de turno consumieron estos segundos reales.
static func escalar(segundos_reales: float) -> float:
	return segundos_reales * SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL
