class_name SalidaVoluntaria
extends RefCounted

enum Etapa { INACTIVA, GIRANDO, ABRIENDO, TERMINADA }

const DURACION_DEL_GIRO := 0.8

var _etapa := Etapa.INACTIVA
var _desde := Vector2.ZERO
var _recorrido := Vector2.ZERO
var _orientacion := Vector2.ZERO
var _transcurrido := 0.0


func iniciar(desde: Vector2, hacia: Vector2) -> bool:
	if _etapa != Etapa.INACTIVA:
		return false
	_desde = desde
	_orientacion = desde
	_recorrido = Vector2(wrapf(hacia.x - desde.x, -PI, PI), hacia.y - desde.y)
	_etapa = Etapa.GIRANDO
	return true


func avanzar(segundos: float) -> void:
	if _etapa != Etapa.GIRANDO or segundos <= 0.0:
		return
	_transcurrido = minf(_transcurrido + segundos, DURACION_DEL_GIRO)
	var proporcion := _transcurrido / DURACION_DEL_GIRO
	var suavizado := proporcion * proporcion * (3.0 - 2.0 * proporcion)
	_orientacion = _desde + _recorrido * suavizado
	if _transcurrido == DURACION_DEL_GIRO:
		_etapa = Etapa.ABRIENDO


func confirmar_apertura() -> bool:
	if _etapa != Etapa.ABRIENDO:
		return false
	_etapa = Etapa.TERMINADA
	return true


func etapa() -> Etapa:
	return _etapa


func orientacion() -> Vector2:
	return _orientacion
