## Adónde va lo que igual quedó adentro de un sólido fijo, y cuándo se lo mira.
##
## Mandarlo derecho a su origen deshace trabajo o lo regala: una bolsa ya contada que vuelve al
## baño queda a la vista con la tarea cumplida. Por eso el origen es el último recurso.
class_name Rescate
extends RefCounted

## Los lugares que se prueban, en el orden en que se prueban.
enum Clase { DESHACER, ALREDEDOR, ENCIMA_DEL_ORIGEN, ORIGEN }

## Lo que contesta `elegir()` cuando ningún candidato quedó libre.
const NINGUNO := -1


class Candidato:
	extends RefCounted

	var clase: Rescate.Clase
	var libre: bool

	func _init(una_clase: Rescate.Clase, esta_libre: bool) -> void:
		clase = una_clase
		libre = esta_libre


## El índice del primer candidato libre, o `NINGUNO`.
static func elegir(candidatos: Array[Candidato]) -> int:
	for indice in candidatos.size():
		if candidatos[indice].libre:
			return indice
	return NINGUNO


## Un empujón no tiene fin propio: el jugador empuja en cada paso que camina contra la caja. La
## racha termina en el primer paso sin empujón.
static func termino_la_racha(empujada_ahora: bool, empujada_antes: bool) -> bool:
	return empujada_antes and not empujada_ahora
