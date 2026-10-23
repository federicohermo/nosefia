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

enum Momento { APERTURA, CIERRE, SIN_FECHA }

@export var identidad: String = ""
@export var jornada: int = 1
@export var momento: Momento = Momento.APERTURA
@export var orden: int = 0
@export var tramo_de_pista: String = ""
@export var texto_del_tramo: String = ""
@export var pista: String = ""
@export var foto: Texture2D = null

@export var de_quien: String = ""

## Vacía en un mensaje fijo. Con valor, el mensaje sale sólo si la partida eligió esa condición.
@export var condicion: StringName = &""

## El cuerpo va como texto multilínea porque un chat del GDD es un párrafo, no un renglón.
@export_multiline var texto: String = ""


## Si el mensaje tiene algo para leer.
##
## Recorta antes de mirar: sin eso un renglón de espacios pasaría por contenido y la conversación
## parecería tener algo donde no hay nada — que es contenido que el jugador paga en minutos de
## turno y no le devuelve nada.
func dice_algo() -> bool:
	return foto != null or not texto.strip_edges().is_empty()


func vale_para(condiciones: Array[StringName]) -> bool:
	return condicion.is_empty() or condiciones.has(condicion)


func pista_del_tramo(tramo: String) -> String:
	if tramo.is_empty() or tramo != tramo_de_pista or texto_del_tramo.is_empty():
		return ""
	return pista if texto.contains(texto_del_tramo) else ""


func a_datos() -> Variant:
	if momento == Momento.SIN_FECHA:
		return texto
	return {"texto": texto, "identidad": identidad, "jornada": jornada, "orden": orden}


static func desde_datos(dato: Variant) -> Mensaje:
	var nuevo := Mensaje.new()
	if dato is String:
		nuevo.texto = dato
		nuevo.jornada = 0
		nuevo.momento = Momento.SIN_FECHA
		return nuevo
	if not dato is Dictionary:
		return null
	if not dato.get("texto") is String or not dato.get("identidad") is String:
		return null
	if not dato.get("jornada") is int or not dato.get("orden") is int:
		return null
	if dato.jornada <= 0 or dato.orden < 0 or dato.identidad.is_empty():
		return null
	nuevo.texto = dato.texto
	nuevo.identidad = dato.identidad
	nuevo.jornada = dato.jornada
	nuevo.orden = dato.orden
	nuevo.momento = Momento.CIERRE
	return nuevo
