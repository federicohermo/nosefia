## Qué puertas interiores están trabadas en una jornada.
##
## El cuartito sigue a la limpieza, porque no hay nada que hacer adentro hasta que se pide limpiar.
## El depósito no se traba nunca: la primera noche ya pide reponer desde sus cajas.
class_name PuertasTrabadas
extends RefCounted


static func cuartito_trabado(jornada: int) -> bool:
	return not Apertura.pide(jornada, Tarea.Tipo.LIMPIAR)
