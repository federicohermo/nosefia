class_name CierreAnticipado
extends RefCounted

const JORNADAS: Array[int] = [
	ReglasDeLaPartida.PRIMERA_JORNADA,
	ReglasDeLaPartida.PRIMERA_JORNADA + 1,
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA - 1,
]


## Si la noche de prueba deja salir por la puerta.
##
## Cuando ya no queda comprador por atender, la atención se da por cumplida se lo haya atendido
## bien o no, y el registro con la planilla en cero también: sin ventas, su cero sólo cuenta al
## cierre, y esperarlo trabaría la puerta a quien se quedó sin nadie a quien vender. Las marcas de
## las tareas no cambian: la devolución y el puntaje siguen contando lo que pasó. Sin `atender` ni
## `registro` se mira la marca de cada tarea.
static func corresponde(
	jornada: int,
	obligatorias: Array[Tarea],
	atender: TareaDeAtender = null,
	registro: RegistroDeVentas = null
) -> bool:
	if jornada not in JORNADAS:
		return false
	for tarea in obligatorias:
		if not tarea.completada() and not _sin_nadie_por_atender(tarea, atender, registro):
			return false
	return true


static func _sin_nadie_por_atender(
	tarea: Tarea, atender: TareaDeAtender, registro: RegistroDeVentas
) -> bool:
	if atender == null or not atender.fisica() or not atender.compras_cerradas():
		return false
	match tarea.tipo():
		Tarea.Tipo.CAJA:
			return true
		Tarea.Tipo.REGISTRAR:
			return registro != null and registro.completada(true)
	return false
