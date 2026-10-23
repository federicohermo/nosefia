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
	var cuentas := partida.antecedentes().a_datos()
	var notas: Array = []
	for nota: Mensaje in partida.expediente.mensajes_de_notas():
		notas.append(nota.a_datos())
	var reflexion := partida.reflexion
	return (
		PartidaSerializada
		. sanear(
			{
				PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA): partida.jornada(),
				PartidaSerializada.clave(PartidaSerializada.Campo.MEDIOS): partida.medios(),
				PartidaSerializada.clave(PartidaSerializada.Campo.FALLAS):
				cuentas[Antecedentes.CLAVE_DE_FALLAS],
				PartidaSerializada.clave(PartidaSerializada.Campo.LLAMADOS):
				cuentas[Antecedentes.CLAVE_DE_LLAMADOS],
				PartidaSerializada.clave(PartidaSerializada.Campo.NOCHES_SIN_SUMAR):
				cuentas[Antecedentes.CLAVE_DE_NOCHES_SIN_SUMAR],
				PartidaSerializada.clave(PartidaSerializada.Campo.DEVOLUCIONES):
				partida.datos_de_devoluciones(),
				PartidaSerializada.clave(PartidaSerializada.Campo.MOPA_SECADA):
				partida.mopa_secada(),
				PartidaSerializada.clave(PartidaSerializada.Campo.EXPEDIENTE):
				Array(partida.expediente.identidades()),
				PartidaSerializada.clave(PartidaSerializada.Campo.NOTAS): notas,
				PartidaSerializada.clave(PartidaSerializada.Campo.CIERRE_PENDIENTE):
				reflexion.jornada() if reflexion != null and reflexion.pendiente() else 0,
				PartidaSerializada.clave(PartidaSerializada.Campo.ELECCIONES):
				partida.expediente.elecciones(),
				PartidaSerializada.clave(PartidaSerializada.Campo.NOCHES_DE_PRUEBA):
				_datos_de(partida.noches_de_prueba),
				PartidaSerializada.clave(PartidaSerializada.Campo.APERCIBIMIENTOS_DE_LA_PRUEBA):
				partida.legajo().apercibimientos_de_la_prueba(),
				PartidaSerializada.clave(PartidaSerializada.Campo.ULTIMA_DE_LA_PRUEBA_COMPLETA):
				partida.legajo().ultima_de_la_prueba_completa(),
				PartidaSerializada.clave(PartidaSerializada.Campo.SEMILLA): partida.semilla,
			}
		)
	)


static func _datos_de(noches: Dictionary[int, ResultadoDeLaNoche]) -> Dictionary:
	var datos := {}
	for jornada: int in noches:
		datos[jornada] = noches[jornada].a_datos()
	return datos
