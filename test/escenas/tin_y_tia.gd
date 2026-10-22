## Tin y Tia en cualquier jornada: para los casos que ejercen la ventanilla física dentro de una
## jornada que ya no los trae, sin abrir la etapa de prueba.
extends RefCounted


static func en_cualquier_jornada(_jornada: int) -> Array[Comprador]:
	return Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
