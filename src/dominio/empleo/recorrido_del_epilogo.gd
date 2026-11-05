## El recorrido de un epílogo: qué placa se ve, cuánto oscurece la pantalla y cuándo termina
## (BR-SHF-070, BR-SHF-071, BR-SHF-072).
##
## Cada paso hacia una placa es un fundido a negro y un fundido de entrada, de un segundo cada uno.
## La primera placa entra así desde lo que hubiera en pantalla, y la pantalla de final entra igual
## desde la última placa: `cerrado` avisa en el instante en que la pantalla está del todo negra,
## y quien lo escucha puede poner debajo lo que viene. El tiempo entra por parámetro.
class_name RecorridoDelEpilogo
extends RefCounted

## La última placa ya se cerró y la pantalla está negra. Una sola vez.
signal cerrado

enum Fase { A_NEGRO, DESDE_NEGRO, LEYENDO, TERMINADO }

const SEGUNDOS_DEL_FUNDIDO := 1.0

var _placas: Array[EpilogosDeLosFinales.Placa]
var _siguiente := 0
var _a_la_vista: EpilogosDeLosFinales.Placa = null
var _fase := Fase.A_NEGRO
var _en_la_fase := 0.0


func _init(placas: Array[EpilogosDeLosFinales.Placa]) -> void:
	_placas = placas


## La placa a la vista, o `null` mientras la pantalla está negra o entra lo que sigue al epílogo.
func placa() -> EpilogosDeLosFinales.Placa:
	return _a_la_vista


## Cuánto cubre el negro: 0 con la placa a la vista, 1 en el medio de los dos fundidos.
func negro() -> float:
	if _fase == Fase.A_NEGRO:
		return _en_la_fase / SEGUNDOS_DEL_FUNDIDO
	if _fase == Fase.DESDE_NEGRO:
		return 1.0 - _en_la_fase / SEGUNDOS_DEL_FUNDIDO
	return 0.0


## Sólo con una placa a la vista y sin fundido en marcha se puede pasar a la siguiente.
func esperando_el_siguiente() -> bool:
	return _fase == Fase.LEYENDO


## El último fundido de entrada terminó: no queda nada que dibujar.
func terminado() -> bool:
	return _fase == Fase.TERMINADO


func avanzar(segundos: float) -> void:
	var resto := maxf(segundos, 0.0)
	while resto > 0.0 and _fase in [Fase.A_NEGRO, Fase.DESDE_NEGRO]:
		var falta := SEGUNDOS_DEL_FUNDIDO - _en_la_fase
		if resto < falta:
			_en_la_fase += resto
			return
		resto -= falta
		_en_la_fase = 0.0
		_terminar_el_fundido()


## Pasa a la placa siguiente, o al final si era la última. Durante un fundido, o dos veces
## seguidas, no hace nada. Devuelve si lo hizo.
func siguiente() -> bool:
	if _fase != Fase.LEYENDO:
		return false
	_fase = Fase.A_NEGRO
	return true


func _terminar_el_fundido() -> void:
	if _fase == Fase.DESDE_NEGRO:
		_fase = Fase.LEYENDO if _a_la_vista != null else Fase.TERMINADO
		return
	_fase = Fase.DESDE_NEGRO
	if _siguiente < _placas.size():
		_a_la_vista = _placas[_siguiente]
		_siguiente += 1
		return
	_a_la_vista = null
	cerrado.emit()
