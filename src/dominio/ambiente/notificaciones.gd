class_name Notificaciones
extends RefCounted

enum Tipo { CLIENTE, LECTURA_FALLIDA, CLIENTE_CANSADO, CIERRE_PROXIMO, PISTA, TAREAS_TERMINADAS }

const DURACION := 3.0
const HORA_DEL_AVISO := 7
const UMBRAL_DEL_AVISO := (
	Reglas.DURACION_DEL_TURNO
	- (
		(Marcador.HORAS_POR_DIA - Reglas.HORA_DE_APERTURA + HORA_DEL_AVISO)
		* Marcador.MINUTOS_POR_HORA
		* Marcador.SEGUNDOS_POR_MINUTO
	)
)

var _compradores: Array[Comprador] = []
var _salidos: Array[Comprador] = []
var _orden: Array[Tipo] = []
var _transcurrido: Dictionary[Tipo, float] = {}
var _esperando: Comprador = null
var _cierre_avisado := false
var _tareas_avisadas := false


func actualizar_tiempo(restante: float) -> void:
	if _cierre_avisado or restante <= 0.0 or restante > UMBRAL_DEL_AVISO:
		return
	_cierre_avisado = true
	_avisar(Tipo.CIERRE_PROXIMO)


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


func pista_anotada() -> void:
	_avisar(Tipo.PISTA)


func tareas_terminadas() -> void:
	if _tareas_avisadas:
		return
	_tareas_avisadas = true
	_avisar(Tipo.TAREAS_TERMINADAS)


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
	_cierre_avisado = false
	_tareas_avisadas = false


func _avisar(tipo: Tipo) -> void:
	_orden.erase(tipo)
	_orden.push_front(tipo)
	_transcurrido[tipo] = 0.0
