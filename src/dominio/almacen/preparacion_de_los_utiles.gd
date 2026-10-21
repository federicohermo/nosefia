## En qué carga se preparan los útiles de limpieza, antes de la primera noche que los pide.
##
## Cada útil compila decenas de variantes, una por cada combinación de luces que cruza en la mano.
## El driver guarda lo que ya compiló: preparadas en una carga anterior, la noche que limpia entra
## sin espera extra. La de «Nuevo juego» no las lleva: es la que espera quien recién llega, y la
## web le pone un tope de programas. Mientras tanto el cuartito está trabado, y nada sale de ahí.
## Quien juega de corrido no vuelve a cargar: los prepara la transición entre noches.
class_name PreparacionDeLosUtiles
extends RefCounted

## Desde qué jornada se prepara cada útil.
const DESDE: Dictionary[StringName, int] = {
	&"balde": ReglasDeLaPartida.PRIMERA_JORNADA + 1,
	&"mopa": ReglasDeLaPartida.PRIMERA_JORNADA + 1,
	&"jabon_azul": ReglasDeLaPartida.PRIMERA_JORNADA + 1,
	&"jabon_rosa": ReglasDeLaPartida.PRIMERA_JORNADA + 1,
	&"jabon_amarillo": ReglasDeLaPartida.PRIMERA_JORNADA + 1,
}


static func se_prepara(identidad: StringName, jornada: int) -> bool:
	return jornada >= DESDE.get(identidad, ReglasDeLaPartida.PRIMERA_JORNADA)


## Si la transición de la jornada `preparada` a la `siguiente` tiene que preparar el útil. Entre
## noches no hay carga: la siguiente abre en la misma escena, con lo que dejó la anterior.
static func por_preparar(identidad: StringName, preparada: int, siguiente: int) -> bool:
	return se_prepara(identidad, siguiente) and not se_prepara(identidad, preparada)
