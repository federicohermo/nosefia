## Qué hace el guardado al cerrar una jornada: escribir la partida, o borrarla si terminó.
##
## No hay una tercera acción: un disco que falla no interrumpe la partida.
class_name PoliticaDeGuardado
extends RefCounted

enum Accion { ESCRIBIR, BORRAR }


static func accion(partida: Partida) -> Accion:
	return Accion.BORRAR if partida.terminada() else Accion.ESCRIBIR


## La jornada que se guarda es la que la partida tiene por abrir: la cerrada ya está en el legajo.
static func datos(partida: Partida) -> Dictionary:
	return (
		PartidaSerializada
		. sanear(
			{
				PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA): partida.jornada(),
				PartidaSerializada.clave(PartidaSerializada.Campo.APERCIBIMIENTOS):
				partida.apercibimientos(),
			}
		)
	)
