## En qué carga se preparan las cajas del depósito, antes de la primera noche que lo abre.
##
## Mientras el depósito está trabado nadie las toca, y las variantes de luz que compilan cuentan
## contra el tope de programas de la web. La carga de «Nuevo juego» no las lleva. Quien juega de
## corrido no vuelve a cargar: las prepara la transición entre noches, como a los útiles.
class_name PreparacionDelDeposito
extends RefCounted

const DESDE := ReglasDeLaPartida.PRIMERA_JORNADA + 1


static func se_prepara(jornada: int) -> bool:
	return jornada >= DESDE


## Si la transición de la jornada `preparada` a la `siguiente` tiene que preparar las cajas.
static func por_preparar(preparada: int, siguiente: int) -> bool:
	return se_prepara(siguiente) and not se_prepara(preparada)
