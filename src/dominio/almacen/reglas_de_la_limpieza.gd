## Los valores fijos de limpiar el local: qué jabón borra cada mancha, cómo se llama cada cosa que
## interviene y de qué color se ve.
##
## Es un archivo aparte de `reglas.gd` por el mismo criterio que separa a los otros `reglas_de_*`
## de esta carpeta: no es de qué trata el número, es quién lo toca y probando qué. `reglas.gd` se
## toca discutiendo cuánto dura la noche; esto, probando si limpiar obliga a ir al baño.
class_name ReglasDeLaLimpieza
extends RefCounted

## Qué tiene el balde, o de qué está mojada la mopa: nada, agua limpia, o agua teñida de uno de
## los tres jabones.
##
## **Es un solo `enum` para los dos, y es a propósito**: mojar la mopa es copiarle el agua del
## balde, y borrar es comparar la de la mopa con la que pide la mancha. Con un estado por objeto,
## esas dos reglas serían dos traducciones que se pueden separar sin que nada lo diga.
enum Agua { NINGUNA, LIMPIA, AZUL, ROSA, AMARILLO }

## Los tres tipos de mancha. Cada uno lo borra un solo jabón: ver `AGUA_QUE_BORRA`.
enum TipoDeMancha { MOHO, CACA, POLVO }

## Cómo salió un uso. Los resultados nuevos se agregan al final para conservar los números
## anteriores de los gestos aceptados y los rechazos.
##
## **Son distintos a propósito**: adelante del jugador, «el balde está vacío» y «ese jabón no es»
## son dos cosas que resuelve distinto, y aplanarlas daría un solo cartel para las dos.
enum Resultado {
	SIN_EFECTO,
	BALDE_LLENADO,
	BALDE_TENIDO,
	BALDE_VACIADO,
	MOPA_MOJADA,
	MANCHA_BORRADA,
	BALDE_VACIO,
	BALDE_YA_LLENO,
	BALDE_YA_TENIDO,
	MOPA_SECA,
	SIN_JABON,
	JABON_EQUIVOCADO,
	YA_ESTABA_LIMPIA,
	CHARCO_DEJADO,
}

## Tiempo real y recorrido adicionales: la caminata combina ambas pérdidas.
const DURACION_DE_LA_CARGA := 12.0
const RECORRIDO_DE_LA_CARGA := 7.5

## Agua temporal sobre suelo despejado: sólo presentación, sin convertirla en una mancha.
const DURACION_DEL_CHARCO := 4.0
const RADIO_DEL_CHARCO := 0.25
const MAXIMO_DE_CHARCOS := 8

## Los `id` de lo que interviene en limpiar. Los dos útiles son los mismos `StringName` que
## declaran sus `.tres`, y los dos artefactos del baño los declara la estructura del local: hay
## un caso de cada lado que afirma que coinciden, porque un `id` que no coincide no rompe nada —el
## gesto simplemente no pasa nunca—.
const ID_DE_LA_MOPA := &"mopa"
const ID_DEL_BALDE := &"balde"
const ID_DEL_LAVATORIO := &"lavatorio"
const ID_DEL_INODORO := &"inodoro"

## Lo que dura el gesto visible de mojar la mopa, en segundos.
const DURACION_DE_LA_MOJADA := 0.4

## El `id` de cada bidón, con el agua que deja al echarlo en el balde.
const JABONES: Dictionary[StringName, Agua] = {
	&"jabon_azul": Agua.AZUL,
	&"jabon_rosa": Agua.ROSA,
	&"jabon_amarillo": Agua.AMARILLO,
}

## Qué agua borra cada tipo de mancha: la del jabón que le corresponde, según la ficha.
const AGUA_QUE_BORRA: Dictionary[TipoDeMancha, Agua] = {
	TipoDeMancha.MOHO: Agua.AZUL,
	TipoDeMancha.CACA: Agua.ROSA,
	TipoDeMancha.POLVO: Agua.AMARILLO,
}

## De qué color se ve el agua: en el balde y en la punta de la mopa, que es la misma.
##
## **El color es lo único que le dice al jugador qué jabón tiene el balde**, y por eso vive acá y
## no en la escena: la escena pinta lo que esto contesta. Los tres jabones son los de sus bidones.
## Sin agua no hay color: `NINGUNA` es transparente.
const COLOR_DEL_AGUA: Dictionary[Agua, Color] = {
	Agua.NINGUNA: Color(0.0, 0.0, 0.0, 0.0),
	Agua.LIMPIA: Color(0.74, 0.89, 0.98),
	Agua.AZUL: Color(0.16, 0.45, 0.92),
	Agua.ROSA: Color(0.93, 0.3, 0.62),
	Agua.AMARILLO: Color(0.97, 0.84, 0.2),
}

## De qué color se ve cada tipo de mancha: es lo que le dice al jugador qué jabón ir a buscar.
##
## Mientras el arte no tenga una textura por tipo, las tres son la misma mancha teñida de esto.
const COLOR_DE_LA_MANCHA: Dictionary[TipoDeMancha, Color] = {
	TipoDeMancha.MOHO: Color(0.3, 0.46, 0.16),
	TipoDeMancha.CACA: Color(0.38, 0.24, 0.1),
	TipoDeMancha.POLVO: Color(0.07, 0.075, 0.07),
}


## El agua que deja en el balde lo que se lleva en la mano, o `NINGUNA` si no es un jabón.
##
## Lo que se lleva entra como `id` y no como objeto: es lo que evita que el dominio de la limpieza
## tenga que conocer al de agarrar.
static func agua_del_jabon(id: StringName) -> Agua:
	var agua: Agua = JABONES.get(id, Agua.NINGUNA)
	return agua
