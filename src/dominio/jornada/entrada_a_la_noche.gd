class_name EntradaALaNoche
extends RefCounted

const PLACA_ENTERA := 1.0
const FADE_DE_LA_PLACA := 0.5
const SUBIDA_DE_LA_PERSIANA := 1.0
const DURACION := PLACA_ENTERA + FADE_DE_LA_PLACA + SUBIDA_DE_LA_PERSIANA

var _jornada: int
var _transcurrido := 0.0


func _init(jornada: int) -> void:
	_jornada = jornada


func texto() -> String:
	return "NOCHE %d" % _jornada


func avanzar(segundos_reales: float) -> void:
	if segundos_reales > 0.0:
		_transcurrido = minf(DURACION, _transcurrido + segundos_reales)


func opacidad_de_la_placa() -> float:
	return 1.0 - clampf((_transcurrido - PLACA_ENTERA) / FADE_DE_LA_PLACA, 0.0, 1.0)


func apertura_de_la_persiana() -> float:
	return clampf(
		(_transcurrido - PLACA_ENTERA - FADE_DE_LA_PLACA) / SUBIDA_DE_LA_PERSIANA, 0.0, 1.0
	)


func terminada() -> bool:
	return _transcurrido >= DURACION
