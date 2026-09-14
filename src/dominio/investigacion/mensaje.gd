## Un mensaje de un chat: quién lo mandó y qué dice.
##
## Es un `Resource` **en su propio archivo**, y eso es una medición y no un gusto: con el
## `Resource` declarado como clase interna de otra, el `.tres` guarda una referencia a un script
## que no se puede resolver y leerle un campo contesta `<null>` — sin un solo error, y con el
## caso de gdUnit4 en verde por haber abortado antes de afirmar.
##
## Un mensaje no hace nada, **es**: qué está leído lo lleva `Bandeja`, y el `.tres` es el guión y
## no se toca.
class_name Mensaje
extends Resource

@export var de_quien: String = ""

## El cuerpo va como texto multilínea porque un chat del GDD es un párrafo, no un renglón.
@export_multiline var texto: String = ""


## Si el mensaje tiene algo para leer.
##
## Recorta antes de mirar: sin eso un renglón de espacios pasaría por contenido y la conversación
## parecería tener algo donde no hay nada — que es contenido que el jugador paga en minutos de
## turno y no le devuelve nada.
func dice_algo() -> bool:
	return not texto.strip_edges().is_empty()
