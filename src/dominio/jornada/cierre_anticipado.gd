## Cuándo una noche deja de esperar las 08:00: el ciclo de compradores se cerró y no queda nada
## por hacer salvo cobrar, que con el último vencido ya no se puede cumplir.
##
## Registrar sin ventas recién se cumple al cierre. Por eso cuenta el registro como quedaría a las
## 08:00, y no la obligatoria: si no, una noche sin compras no aceleraría nunca.
class_name CierreAnticipado
extends RefCounted

const JORNADAS: Array[int] = [ReglasDeLaPartida.PRIMERA_JORNADA]

## Provisoria hasta que se decida jugando la primera noche (OQ-SHF-007).
const DURACION_DE_LA_ACELERACION := 10.0


static func corresponde(
	jornada: int, compras_cerradas: bool, registro_al_cierre: bool, obligatorias: Array[Tarea]
) -> bool:
	if jornada not in JORNADAS or not compras_cerradas:
		return false
	for tarea in obligatorias:
		if tarea.completada() or tarea.tipo() == Tarea.Tipo.CAJA:
			continue
		if tarea.tipo() != Tarea.Tipo.REGISTRAR or not registro_al_cierre:
			return false
	return true
