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
	LOGRO,
}

const DURACION := 3.0
## Cada logro es su propio aviso: la clave de un logro empieza donde terminan los valores de `Tipo`.
const _CLAVE_DEL_PRIMER_LOGRO := 1000
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
var _orden: Array[int] = []
var _transcurrido: Dictionary[int, float] = {}
var _esperando: Comprador = null
var _cierre_avisado := false
var _permiso := false
var _en_la_computadora := false


## La clave de un aviso: el valor del tipo, o el del logro desde `_CLAVE_DEL_PRIMER_LOGRO`.
static func clave_del_logro(logro: Logros.Logro) -> int:
	return _CLAVE_DEL_PRIMER_LOGRO + logro


static func tipo_de(clave: int) -> Tipo:
	return Tipo.LOGRO if clave >= _CLAVE_DEL_PRIMER_LOGRO else clave as Tipo


## Sólo vale para la clave de un aviso de logro.
static func logro_de(clave: int) -> Logros.Logro:
	return (clave - _CLAVE_DEL_PRIMER_LOGRO) as Logros.Logro


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


## Un logro nunca avisa dos veces: el dominio lo desbloquea una sola.
func logro_desbloqueado(logro: Logros.Logro) -> void:
	_avisar_clave(clave_del_logro(logro))


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
	for clave in avisos():
		if _persiste(tipo_de(clave)):
			continue
		_transcurrido[clave] += segundos
		if _transcurrido[clave] >= DURACION:
			_orden.erase(clave)
			_transcurrido.erase(clave)


func visibles() -> Array[Tipo]:
	var tipos: Array[Tipo] = []
	for clave in _orden:
		tipos.append(tipo_de(clave))
	return tipos


## Lo mismo que `visibles`, con la identidad de cada logro: dos logros son dos avisos.
func avisos() -> Array[int]:
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
	_avisar_clave(tipo)


func _avisar_clave(clave: int) -> void:
	_orden.erase(clave)
	_orden.push_front(clave)
	_transcurrido[clave] = 0.0


func _avisar_salida(disponible: bool) -> void:
	if not disponible:
		_retirar(Tipo.TAREAS_TERMINADAS)
	elif not _orden.has(Tipo.TAREAS_TERMINADAS):
		_avisar(Tipo.TAREAS_TERMINADAS)
