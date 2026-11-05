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

const HORA_DEL_MEDIODIA := 12
const TANDAS_POR_DIA := 2

@export var identidad: String = ""
@export var jornada: int = 1
@export var momento: Momento = Momento.APERTURA
@export var orden: int = 0
@export var tramo_de_pista: String = ""
@export var texto_del_tramo: String = ""
@export var pista: String = ""
@export var foto: Texture2D = null

@export var de_quien: String = ""

## Lo escribió el jugador: va del lado de quien lee, y no es contenido del guión.
@export var propio: bool = false

## Salió sin red: el chat lo muestra en rojo y nadie lo contestó.
@export var con_error: bool = false

## Lo creó la noche y se pierde al volver a abrirla: lo enviado y su respuesta no son del guión.
@export var de_la_noche: bool = false

## `H:MM` o `HH:MM`. Vacía cuando nadie la fijó: un dato guardado antes de que existiera carga así.
@export var hora: String = ""

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


## El día del calendario del mensaje, contado en jornadas. Lo que el jefe manda a la mañana
## siguiente de cerrar una noche es del día de la jornada que sigue.
func dia() -> int:
	return jornada + 1 if momento == Momento.CIERRE and _es_de_la_manana() else jornada


## Qué tanda del historial le toca: un día y su momento, mañana o tarde. Dos mensajes seguidos con
## la misma tanda van bajo el mismo separador. El legado sin fecha no tiene tanda.
func tanda() -> int:
	if momento == Momento.SIN_FECHA:
		return -1
	return dia() * TANDAS_POR_DIA + (0 if _es_de_la_manana() else 1)


func a_datos() -> Variant:
	if momento == Momento.SIN_FECHA:
		return texto
	return {
		"texto": texto, "identidad": identidad, "jornada": jornada, "orden": orden, "hora": hora
	}


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
	if dato.get("hora") is String:
		nuevo.hora = dato.hora
	return nuevo


## Sin hora, o con una que no es `H:MM`, el mensaje cuenta como de la tarde.
func _es_de_la_manana() -> bool:
	var partes := hora.split(":")
	if partes.size() != 2 or not partes[0].is_valid_int():
		return false
	return partes[0].to_int() < HORA_DEL_MEDIODIA
