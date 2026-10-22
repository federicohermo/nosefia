class_name SalidaDelAlmacen
extends Node

signal vista_cambiada(pose: PoseDeLaVista)
signal apertura_pedida

var _salida := SalidaVoluntaria.new()
var _reloj: RelojDelTurno
var _puertas: Array[Puerta]


func configurar(reloj: RelojDelTurno, puertas: Array[Puerta]) -> void:
	_reloj = reloj
	_puertas = puertas


func iniciar(desde: PoseDeLaVista, hacia: PoseDeLaVista) -> bool:
	if _salida.etapa() != SalidaVoluntaria.Etapa.INACTIVA or not _reloj.reservar_cierre():
		return false
	_salida.iniciar(desde, hacia)
	vista_cambiada.emit(_salida.pose())
	return true


func _process(delta: float) -> void:
	if _salida.etapa() != SalidaVoluntaria.Etapa.GIRANDO:
		return
	_salida.avanzar(delta)
	vista_cambiada.emit(_salida.pose())
	if _salida.etapa() == SalidaVoluntaria.Etapa.ABRIENDO:
		apertura_pedida.emit()


func confirmar_apertura() -> void:
	for puerta: Puerta in _puertas:
		if not puerta.abierta() or not is_equal_approx(puerta.angulo(), Puerta.ANGULO_ABIERTA):
			return
	if _salida.confirmar_apertura():
		_reloj.terminar_cierre_reservado()


func reiniciar() -> void:
	_salida = SalidaVoluntaria.new()
