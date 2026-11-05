## Qué final de la partida tiene pantalla propia (BR-SHF-027, BR-SHF-060, BR-SHF-061).
##
## El despido gana sobre los finales del contrato cumplido: «estresado» (sin pistas) y «locura
## paranoica» (con alguna) sólo valen si nadie lo echó (BR-INV-103). `Partida` ya eligió entre los
## dos. `NINGUNO` es la partida en curso.
class_name FinalConPantalla
extends RefCounted

enum Cual {
	NINGUNO,
	DESPEDIDO,
	EMPLEADO_ESTRESADO,
	LOCURA_PARANOICA,
	JEFE_SABOTEADOR,
	JEFE_INCOMPETENTE,
}


static func de(partida: Partida) -> Cual:
	if partida.final() == Partida.Final.DESPEDIDO:
		return Cual.DESPEDIDO
	if partida.final() == Partida.Final.JEFE_SABOTEADOR:
		return Cual.JEFE_SABOTEADOR
	if partida.final() == Partida.Final.JEFE_INCOMPETENTE:
		return Cual.JEFE_INCOMPETENTE
	if partida.final() == Partida.Final.LOCURA_PARANOICA:
		return Cual.LOCURA_PARANOICA
	if partida.final() == Partida.Final.CONTRATO_CUMPLIDO:
		return Cual.EMPLEADO_ESTRESADO
	return Cual.NINGUNO
