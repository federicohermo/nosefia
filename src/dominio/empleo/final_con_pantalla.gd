## Qué final de la partida tiene pantalla propia (BR-SHF-027, BR-SHF-060).
##
## El despido gana sobre la falta de pistas: el contrato sólo es «estresado» si nadie lo echó. Una
## hipótesis elegida sin pista no entra en `identidades()`, así que no cuenta como pista
## (BR-INV-103). `NINGUNO` es cualquier otro final, y también la partida en curso.
class_name FinalConPantalla
extends RefCounted

enum Cual { NINGUNO, DESPEDIDO, EMPLEADO_ESTRESADO, JEFE_SABOTEADOR }


static func de(partida: Partida) -> Cual:
	if partida.final() == Partida.Final.DESPEDIDO:
		return Cual.DESPEDIDO
	if partida.final() == Partida.Final.JEFE_SABOTEADOR:
		return Cual.JEFE_SABOTEADOR
	if partida.final() == Partida.Final.CONTRATO_CUMPLIDO:
		if partida.expediente.identidades().is_empty():
			return Cual.EMPLEADO_ESTRESADO
	return Cual.NINGUNO
