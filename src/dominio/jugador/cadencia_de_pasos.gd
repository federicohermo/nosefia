## Cuándo toca un paso: cada cierta distancia recorrida, no cada cierto tiempo.
##
## Por eso quieto no suena y el mismo tramo, a otra velocidad, da los mismos pasos.
class_name CadenciaDePasos
extends RefCounted

## Los metros entre un paso y el siguiente. Primer valor: ver OQ-AMB-007.
const DISTANCIA_ENTRE_PASOS := 1.1

var _acumulado := 0.0


## Suma lo recorrido en un cuadro y contesta si toca un paso. Lo que sobra cuenta para el
## siguiente, pero nunca más de un paso: un cuadro largo no suena dos pasos pegados.
func avanzar(distancia: float) -> bool:
	_acumulado += maxf(distancia, 0.0)
	if _acumulado < DISTANCIA_ENTRE_PASOS:
		return false
	_acumulado = fmod(_acumulado, DISTANCIA_ENTRE_PASOS)
	return true
