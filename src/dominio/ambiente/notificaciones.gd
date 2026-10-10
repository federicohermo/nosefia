class_name Notificaciones
extends RefCounted

enum Tipo { CLIENTE, LECTURA_FALLIDA, CLIENTE_CANSADO }

const DURACION := 3.0

var _compradores: Array[Comprador] = []
var _salidos: Array[Comprador] = []
var _orden: Array[Tipo] = []
var _transcurrido: Dictionary[Tipo, float] = {}
var _esperando: Comprador = null


func atendido(comprador: Comprador) -> void:
	if comprador == null or comprador != _esperando:
		return
	_esperando = null
	_orden.erase(Tipo.CLIENTE)
	_transcurrido.erase(Tipo.CLIENTE)


func se_fue(comprador: Comprador) -> void:
	if comprador == null or _salidos.has(comprador):
		return
	_salidos.append(comprador)
	atendido(comprador)
	_avisar(Tipo.CLIENTE_CANSADO)


func llego(comprador: Comprador) -> void:
	if comprador == null or _compradores.has(comprador):
		return
	_compradores.append(comprador)
	_esperando = comprador if comprador.tiene_horario() else null
	_avisar(Tipo.CLIENTE)


func lectura_rechazada(motivo: GeneradorDeTickets.Resultado) -> void:
	if motivo == GeneradorDeTickets.Resultado.LLENO:
		_avisar(Tipo.LECTURA_FALLIDA)


func avanzar(segundos: float) -> void:
	if segundos <= 0.0:
		return
	for tipo in visibles():
		if tipo == Tipo.CLIENTE and _esperando != null:
			continue
		_transcurrido[tipo] += segundos
		if _transcurrido[tipo] >= DURACION:
			_orden.erase(tipo)
			_transcurrido.erase(tipo)


func visibles() -> Array[Tipo]:
	return _orden.duplicate()


func vaciar() -> void:
	_orden.clear()
	_transcurrido.clear()
	_compradores.clear()
	_salidos.clear()
	_esperando = null


func _avisar(tipo: Tipo) -> void:
	_orden.erase(tipo)
	_orden.push_front(tipo)
	_transcurrido[tipo] = 0.0
