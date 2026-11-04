class_name Notificaciones
extends RefCounted

enum Tipo {
	CLIENTE,
	LECTURA_FALLIDA,
	CLIENTE_CANSADO,
	CIERRE_PROXIMO,
	PISTA,
	TAREAS_TERMINADAS,
	CLIENTE_CANSADO_CON_PRODUCTOS,
}

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
var _permiso := false
var _en_la_computadora := false


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


func se_fue(comprador: Comprador, dejo_productos := false) -> void:
	if comprador == null or _salidos.has(comprador):
		return
	_salidos.append(comprador)
	atendido(comprador)
	_avisar(Tipo.CLIENTE_CANSADO_CON_PRODUCTOS if dejo_productos else Tipo.CLIENTE_CANSADO)


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


func actualizar_salida(disponible: bool) -> void:
	_permiso = disponible
	if disponible and _en_la_computadora:
		return
	_avisar_salida(disponible)


func actualizar_computadora(abierta: bool) -> void:
	_en_la_computadora = abierta
	if not abierta:
		_avisar_salida(_permiso)


func avanzar(segundos: float) -> void:
	if segundos <= 0.0:
		return
	for tipo in visibles():
		if _persiste(tipo):
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
	_permiso = false


func _persiste(tipo: Tipo) -> bool:
	return tipo == Tipo.TAREAS_TERMINADAS or (tipo == Tipo.CLIENTE and _esperando != null)


func _retirar(tipo: Tipo) -> void:
	_orden.erase(tipo)
	_transcurrido.erase(tipo)


func _avisar(tipo: Tipo) -> void:
	_orden.erase(tipo)
	_orden.push_front(tipo)
	_transcurrido[tipo] = 0.0


func _avisar_salida(disponible: bool) -> void:
	if not disponible:
		_retirar(Tipo.TAREAS_TERMINADAS)
	elif not _orden.has(Tipo.TAREAS_TERMINADAS):
		_avisar(Tipo.TAREAS_TERMINADAS)
