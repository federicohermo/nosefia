## Los golpes de un objeto desde que se suelta: cuáles suenan, a qué volumen y con qué corte.
##
## Hay uno por objeto. Agarrar lo reinicia y colocar lo agota: lo colocado ya no está cayendo.
class_name ContadorDeGolpes
extends RefCounted

## Primer valor: un objeto apoyado que vibra queda por debajo, y uno que cae desde la mano llega
## a unos 4 m/s. Ver OQ-AMB-002.
const UMBRAL_DE_GOLPE := 0.8

## El volumen de cada golpe que suena, en dB. Del cuarto en adelante no suena.
const VOLUMEN_POR_GOLPE: Array[float] = [0.0, -6.0, -12.0]

## El corte del filtro pasa-altos de cada golpe, en Hz. `0` es sin filtro. Primer valor: ver
## OQ-AMB-003.
const CORTE_POR_GOLPE: Array[float] = [0.0, 400.0, 1200.0]

var _dados: int = 0


## Cómo suena un golpe.
class Golpe:
	extends RefCounted

	var volumen_db: float
	var corte_hz: float

	func _init(volumen: float, corte: float) -> void:
		volumen_db = volumen
		corte_hz = corte


## El golpe de lo que no cuenta golpes: 0 dB y sin filtro.
static func pleno() -> Golpe:
	return Golpe.new(0.0, 0.0)


## Cómo suena este evento para este objeto, o `null` si no suena.
func al_evento(evento: EntradaSonora.Evento, rapidez: float) -> Golpe:
	match evento:
		EntradaSonora.Evento.OBJETO_AGARRADO:
			reiniciar()
		EntradaSonora.Evento.OBJETO_SOLTADO:
			return contar(rapidez)
		EntradaSonora.Evento.PRODUCTO_COLOCADO:
			agotar()
	return pleno()


## El golpe de un contacto a esa rapidez, o `null` si no suena.
func contar(rapidez: float) -> Golpe:
	# El primero cuenta aunque sea lento: lo que se apoya donde se mira no cae.
	if (_dados > 0 and rapidez < UMBRAL_DE_GOLPE) or _dados >= VOLUMEN_POR_GOLPE.size():
		return null
	var golpe := Golpe.new(VOLUMEN_POR_GOLPE[_dados], CORTE_POR_GOLPE[_dados])
	_dados += 1
	return golpe


func reiniciar() -> void:
	_dados = 0


func agotar() -> void:
	_dados = VOLUMEN_POR_GOLPE.size()
