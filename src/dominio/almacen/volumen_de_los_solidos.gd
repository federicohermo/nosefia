## Qué pieza de un sólido fijo puede quedar sin volumen.
##
## Una forma cóncava es hueca: lo que queda del todo adentro no toca ninguna cara y no choca con
## nada. Por eso cada pieza donde cabe un objeto necesita una forma con volumen detrás, o una razón
## escrita para no tenerla.
class_name VolumenDeLosSolidos
extends RefCounted

## La clave de metadata que exime a una pieza cóncava. Su valor es la razón, como texto.
const CLAVE_DE_EXENCION := &"sin_volumen"


## Sólo exime una razón escrita: una clave vacía es un olvido, no una decisión.
static func exime(valor: Variant) -> bool:
	return valor is String and not (valor as String).strip_edges().is_empty()
