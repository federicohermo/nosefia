## Cuándo una noche deja de esperar las 08:00: el ciclo de compradores se cerró y no queda nada
## por hacer salvo cobrar, que con el último vencido ya no se puede cumplir.
class_name CierreAnticipado
extends RefCounted

const JORNADAS: Array[int] = [ReglasDeLaPartida.PRIMERA_JORNADA]

## Provisoria hasta que se decida jugando la primera noche (OQ-SHF-007).
const DURACION_DE_LA_ACELERACION := 10.0


static func corresponde(jornada: int, compras_cerradas: bool, obligatorias: Array[Tarea]) -> bool:
	if jornada not in JORNADAS or not compras_cerradas:
		return false
	for tarea in obligatorias:
		if tarea.tipo() != Tarea.Tipo.CAJA and not tarea.completada():
			return false
	return true
