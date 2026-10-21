## Qué puertas interiores están trabadas en una jornada.
##
## El depósito se traba la primera noche: el jugador la cumple sin entrar. El cuartito y el baño
## siguen a la limpieza, porque no hay nada que hacer adentro hasta que se pide limpiar.
class_name PuertasTrabadas
extends RefCounted

enum Puerta { DEPOSITO, BANO, CUARTITO }


static func trabada(puerta: Puerta, jornada: int) -> bool:
	if puerta == Puerta.DEPOSITO:
		return jornada <= ReglasDeLaPartida.PRIMERA_JORNADA
	return not Apertura.pide(jornada, Tarea.Tipo.LIMPIAR)
