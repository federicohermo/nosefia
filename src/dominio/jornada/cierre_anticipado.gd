class_name CierreAnticipado
extends RefCounted

const JORNADAS: Array[int] = [
	ReglasDeLaPartida.PRIMERA_JORNADA,
	ReglasDeLaPartida.PRIMERA_JORNADA + 1,
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA - 1,
]


## Si la noche de prueba deja salir por la puerta.
##
## La atención se da por cumplida cuando ya no queda comprador por atender, se lo haya atendido
## bien o no: la tarea sigue incompleta para la devolución y el puntaje, y esto sólo decide el
## permiso. Sin `atender` se mira la marca de la tarea, como las demás.
static func corresponde(
	jornada: int, obligatorias: Array[Tarea], atender: TareaDeAtender = null
) -> bool:
	if jornada not in JORNADAS:
		return false
	for tarea in obligatorias:
		if tarea.completada():
			continue
		var sin_nadie_por_atender := atender != null and atender.compras_cerradas()
		if tarea.tipo() != Tarea.Tipo.CAJA or not sin_nadie_por_atender:
			return false
	return true
