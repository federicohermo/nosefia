## Una mancha del piso: cuántas pasadas le faltan.
##
## Una mancha no sabe dónde está ni de qué zona es: eso lo lleva `PisoDelLocal`. Acá sólo vive el
## contador, y vive acá y no en la escena porque «cuántas pasadas quedan» es una regla del juego —
## escrita contando los hijos de un `Node3D` daría cero hallazgos en los dos gates.
class_name Mancha
extends RefCounted

var _restantes: int = ReglasDeLaLimpieza.PASADAS_POR_MANCHA


func pasadas_restantes() -> int:
	return _restantes


func esta_limpia() -> bool:
	return _restantes <= 0


## Pasa el trapeador una vez, y devuelve `true` **sólo si bajó una pasada**.
##
## Sobre una mancha ya limpia devuelve `false` y no baja de cero: machacar sobre lo limpio no
## cierra nada, y sin el corte el contador se iría a negativo y `esta_limpia()` seguiría diciendo
## que sí — un estado imposible que ningún número delata.
func pasar() -> bool:
	if esta_limpia():
		return false
	_restantes -= 1
	return true
