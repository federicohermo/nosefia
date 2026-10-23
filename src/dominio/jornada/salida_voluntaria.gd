class_name SalidaVoluntaria
extends RefCounted

enum Etapa { INACTIVA, GIRANDO, ABRIENDO, TERMINADA }

const DURACION_DEL_GIRO := 0.8

var _etapa := Etapa.INACTIVA
var _desde: PoseDeLaVista
var _hacia: PoseDeLaVista
var _pose := PoseDeLaVista.new()
var _transcurrido := 0.0


func iniciar(desde: PoseDeLaVista, hacia: PoseDeLaVista) -> bool:
	if _etapa != Etapa.INACTIVA:
		return false
	_desde = desde
	_hacia = hacia
	_pose = desde
	_etapa = Etapa.GIRANDO
	return true


func avanzar(segundos: float) -> void:
	if _etapa != Etapa.GIRANDO or segundos <= 0.0:
		return
	_transcurrido = minf(_transcurrido + segundos, DURACION_DEL_GIRO)
	var proporcion := _transcurrido / DURACION_DEL_GIRO
	var suavizado := proporcion * proporcion * (3.0 - 2.0 * proporcion)
	_pose = _desde.mezclada_con(_hacia, suavizado)
	if _transcurrido == DURACION_DEL_GIRO:
		_etapa = Etapa.ABRIENDO


func confirmar_apertura() -> bool:
	if _etapa != Etapa.ABRIENDO:
		return false
	_etapa = Etapa.TERMINADA
	return true


func etapa() -> Etapa:
	return _etapa


func pose() -> PoseDeLaVista:
	return _pose
