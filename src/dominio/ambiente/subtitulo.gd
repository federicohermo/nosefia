## La línea de subtítulo: qué dice y cuánto se ve, sin el motor.
##
## Un **pensamiento** se ve entero un tiempo que crece con su largo y después se desvanece. El
## texto **fijo** es el del examen: no se consume, y se va recién cuando lo sueltan. Hay una sola
## línea, así que lo que llega reemplaza a lo que se ve.
##
## El tiempo entra por `avanzar()`: quien tiene el reloj es la cáscara, y la pausa lo detiene
## porque deja de llamarlo.
class_name Subtitulo
extends RefCounted

## `D(n) = máx(PISO; BASE + n / CARACTERES_POR_SEGUNDO)`. Los decidió el diseño como aproximados:
## se corrigen jugando.
const PISO := 2.0
const BASE := 1.5
const CARACTERES_POR_SEGUNDO := 25.0

## Cuánto tarda en desvanecerse, en segundos.
const DESVANECIDO := 0.5

## Cuántos metros más lejos de su lugar que al aparecer aguanta un pensamiento antes de irse.
const DISTANCIA_PARA_IRSE := 0.75

var _texto: String = ""
var _fijo: bool = false
var _transcurrido: float = 0.0
var _duracion: float = 0.0


## Cuánto se ve entero un pensamiento. `length()` cuenta caracteres y no bytes: una letra con
## tilde cuenta uno.
static func duracion(texto: String) -> float:
	return maxf(PISO, BASE + texto.length() / CARACTERES_POR_SEGUNDO)


## Un subtítulo temporal. Reemplaza al que haya y empieza entero, aunque sea el mismo texto: los
## tiempos no se suman. Un texto vacío no cambia nada.
func pensar(texto: String) -> void:
	if texto.is_empty():
		return
	_texto = texto
	_fijo = false
	_transcurrido = 0.0
	_duracion = duracion(texto)


## El texto del examen: queda entero hasta `soltar()`. Un texto vacío deja la línea vacía, que
## es lo que el examen de algo sin texto muestra.
func fijar(texto: String) -> void:
	_texto = texto
	_fijo = true
	_transcurrido = 0.0


## Vacía la línea en el acto, sea lo que sea que se vea.
func soltar() -> void:
	_texto = ""
	_fijo = false
	_transcurrido = 0.0


func avanzar(segundos: float) -> void:
	if segundos <= 0.0 or _fijo or _texto.is_empty():
		return
	_transcurrido += segundos
	if _transcurrido >= _duracion + DESVANECIDO:
		soltar()


## Cuánto se alejó el jugador del lugar del pensamiento desde que apareció. Pasado el límite,
## empieza a desvanecerse ya; si ya se desvanecía, sigue igual: volver no le devuelve nada.
func alejarse(metros: float) -> void:
	if _fijo or _texto.is_empty() or metros <= DISTANCIA_PARA_IRSE:
		return
	_transcurrido = maxf(_transcurrido, _duracion)


func texto() -> String:
	return _texto


func opacidad() -> float:
	if _texto.is_empty():
		return 0.0
	if _fijo or _transcurrido <= _duracion:
		return 1.0
	return clampf(1.0 - (_transcurrido - _duracion) / DESVANECIDO, 0.0, 1.0)
