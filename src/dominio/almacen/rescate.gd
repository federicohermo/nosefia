## Adónde va lo que igual quedó adentro de un sólido fijo, y cuándo se lo mira.
##
## Mandarlo derecho al origen deshace el recorrido del jugador. Por eso se busca primero
## cerca de donde quedó y el origen es el último recurso.
class_name Rescate
extends RefCounted

## Los lugares que se prueban, en el orden en que se prueban.
enum Clase { DESHACER, ALREDEDOR, ENCIMA_DEL_ORIGEN, ORIGEN }

const NINGUNO := -1


## La primera clase libre, o `NINGUNO`. `libres` va en el orden de `Clase`.
static func elegir(libres: Array[bool]) -> int:
	for clase in libres.size():
		if libres[clase]:
			return clase
	return NINGUNO


## Un empujón no tiene fin propio: el jugador empuja en cada paso que camina contra la caja. La
## racha termina en el primer paso sin empujón.
static func termino_la_racha(empujada_ahora: bool, empujada_antes: bool) -> bool:
	return empujada_antes and not empujada_ahora
