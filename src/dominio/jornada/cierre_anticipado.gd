class_name CierreAnticipado
extends RefCounted

const JORNADAS: Array[int] = [
	ReglasDeLaPartida.PRIMERA_JORNADA,
	ReglasDeLaPartida.PRIMERA_JORNADA + 1,
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA - 1,
]


static func corresponde(jornada: int, obligatorias: Array[Tarea]) -> bool:
	if jornada not in JORNADAS:
		return false
	for tarea in obligatorias:
		if not tarea.completada():
			return false
	return true
