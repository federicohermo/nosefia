## En qué carga se preparan los útiles de limpieza, antes de la primera noche que los pide.
##
## Cada útil compila decenas de variantes, una por cada combinación de luces que cruza en la mano.
## El driver guarda lo que ya compiló: preparadas antes de la noche que limpia, esa noche entra sin
## espera extra. Hasta entonces el cuartito está trabado y nada sale de ahí, así que ni la carga de
## «Nuevo juego» ni las transiciones previas las llevan: la web le pone un tope de programas a
## la primera, y a las otras les suma una espera que esas noches no cobran.
## Quien juega de corrido no vuelve a cargar: los prepara la transición hacia esa noche.
class_name PreparacionDeLosUtiles
extends RefCounted

## Desde qué jornada se prepara cada útil.
const DESDE: Dictionary[StringName, int] = {
	&"balde": ReglasDeLaPartida.PRIMERA_JORNADA + 2,
	&"mopa": ReglasDeLaPartida.PRIMERA_JORNADA + 2,
	&"jabon_azul": ReglasDeLaPartida.PRIMERA_JORNADA + 2,
	&"jabon_rosa": ReglasDeLaPartida.PRIMERA_JORNADA + 2,
	&"jabon_amarillo": ReglasDeLaPartida.PRIMERA_JORNADA + 2,
}


static func se_prepara(identidad: StringName, jornada: int) -> bool:
	return jornada >= DESDE.get(identidad, ReglasDeLaPartida.PRIMERA_JORNADA)


## Si la transición de la jornada `preparada` a la `siguiente` tiene que preparar el útil. Entre
## noches no hay carga: la siguiente abre en la misma escena, con lo que dejó la anterior.
static func por_preparar(identidad: StringName, preparada: int, siguiente: int) -> bool:
	return se_prepara(identidad, siguiente) and not se_prepara(identidad, preparada)
