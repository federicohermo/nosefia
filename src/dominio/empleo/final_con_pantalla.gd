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

## Lo que el despido muestra entre el título y los botones: uno, al azar (BR-SHF-070).
const TIPS: Array[String] = [
	(
		"Prestá atención a las pautas anotadas en el corcho. "
		+ "Dejar el local desordenado va a hacer que Enrique esté más inclinado a despedirte."
	),
	(
		"Tené en cuenta que podés agarrar directamente del depósito los productos que vendas. "
		+ "Así, no vas a necesitar reponerlos después."
	),
	(
		"Buscá manchas de suciedad en todos los rincones. "
		+ "A veces, pueden estar en los lugares que menos esperás."
	),
	(
		"¡No dejes de anotar los productos vendidos en la computadora! "
		+ "Podés hacerlo antes de dárselos al cliente, para no olvidarte."
	),
	(
		"¡Priorizá la atención al cliente! Tenés toda la noche para hacer las demás tareas, "
		+ "pero los compradores pueden cansarse e irse."
	),
]
## El texto de cierre de cada final narrativo. Un final que no está acá no lleva texto.
const CIERRES: Dictionary[Cual, String] = {
	Cual.EMPLEADO_ESTRESADO:
	(
		"Conseguiste ignorar tus instintos paranoicos.\n"
		+ "¿Pero a qué costo? ¿Es esta la “cordura” que querías preservar?"
	),
	Cual.LOCURA_PARANOICA:
	(
		"Perdiste el rastro. No pudiste encontrar suficientes pistas "
		+ "como para elaborar una hipótesis sólida. Tal vez la próxima…"
	),
	Cual.JEFE_SABOTEADOR: "La unión hace la fuerza. Pero no garantiza la estabilidad laboral…",
	Cual.JEFE_INCOMPETENTE: "El pueblo unido jamás será vencido.",
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


## El mensaje del final: un tip al azar si lo despidieron, el texto de cierre si llegó a un final
## narrativo, y nada si el final no lo tiene.
static func mensaje(final: Cual, azar: RandomNumberGenerator) -> String:
	if final == Cual.DESPEDIDO:
		return TIPS[azar.randi_range(0, TIPS.size() - 1)]
	return CIERRES.get(final, "")
