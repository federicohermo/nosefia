## El nodo que hace correr el turno adentro del motor: le pasa el `delta` y publica lo que el
## dominio contesta.
##
## **Traduce, no decide.** El único `if` sobre el juego que hay acá es `_turno.cerrado()`, y no
## es una decisión: es una pregunta al dominio. El reloj no sabe cuándo se agota un turno ni
## cuánto cuesta una tarea.
##
## **Es el único dueño de la instancia de `Turno` mientras la escena corre, y no la expone.** De
## ahí que `completar()` y `obligatoria()` existan: quien quiera cumplir una tarea —el 008, el
## 009— llama acá, o no tiene a qué llamarle. El modo de falla de saltearse esta puerta es
## silencioso: `tarea_completada` no se emite, el HUD se queda en cero toda la jornada, y los
## nodos de `verificar.py` quedan en verde, porque ninguna regla se rompió.
##
## **No conoce la pantalla.** Emite hacia arriba y no pregunta nada: quien quiera mostrar algo se
## conecta a las señales.
class_name RelojDelTurno
extends Node

signal tiempo_consumido(restante: float)
signal cierre_iniciado
signal tarea_completada(cumplidas: int)
signal tarea_descumplida(cumplidas: int)
signal turno_cerrado(cumplidas: int)

var _turno: Turno = null
var _obligatorias: Array[Tarea] = []
var _ritmo: float = Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL
var _ultimo_cuadro_usec: int = 0
var _retenido := false
var _cierre_reservado := false


## El navegador puede suspender los cuadros de una pestaña oculta. El reloj monotónico sigue
## contando: al volver se recibe todo el intervalo, sin depender del delta limitado del motor.
func _process(_delta: float) -> void:
	var ahora := _ahora_usec()
	var transcurrido := (ahora - _ultimo_cuadro_usec) / 1000000.0
	_ultimo_cuadro_usec = ahora
	if not _retenido:
		avanzar(transcurrido)


## La pausa manual excluye su intervalo; perder el foco no manda estas notificaciones.
func _notification(aviso: int) -> void:
	if aviso == NOTIFICATION_PAUSED or aviso == NOTIFICATION_UNPAUSED:
		_ultimo_cuadro_usec = _ahora_usec()


func _ahora_usec() -> int:
	return Time.get_ticks_usec()


func retener() -> void:
	_retenido = true


func soltar() -> void:
	_retenido = false
	# La entrada puede terminar sin haber entregado un cuadro del reloj en mucho tiempo.
	_ultimo_cuadro_usec = _ahora_usec()


## Los segundos reales recibidos, convertidos en tiempo de turno.
func avanzar(segundos_reales: float) -> void:
	if _cierre_reservado:
		return
	_consumir(maxf(0.0, Ritmo.escalar(segundos_reales, _ritmo)))


func terminar() -> void:
	if corriendo() and not _cierre_reservado:
		_consumir(_turno.tiempo_restante())


func reservar_cierre() -> bool:
	if not corriendo() or _cierre_reservado:
		return false
	_cierre_reservado = true
	return true


func terminar_cierre_reservado() -> void:
	if not _cierre_reservado:
		return
	_consumir(_turno.tiempo_restante())
	_cierre_reservado = false


func _consumir(segundos: float) -> void:
	if not corriendo():
		return
	if _turno.se_agota_con(segundos):
		cierre_iniciado.emit()
	_turno.consumir(segundos)
	tiempo_consumido.emit(_turno.tiempo_restante())
	if _turno.cerrado():
		turno_cerrado.emit(_turno.tareas_cumplidas())


## Le entrega al reloj el turno de la jornada y la lista con la que se armó.
##
## La lista se recibe además del turno porque el `Turno` no la expone, y `obligatoria()` la
## necesita para contestar con la misma instancia que el turno está contando.
func arrancar(
	turno: Turno,
	obligatorias: Array[Tarea],
	ritmo: float = Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL
) -> void:
	_turno = turno
	_cierre_reservado = false
	_obligatorias = obligatorias
	_ritmo = ritmo
	_ultimo_cuadro_usec = _ahora_usec()


## Si hay un turno en curso que todavía no se agotó.
##
## Sin turno también es `false`: la escena existe antes de que alguien le pase uno, así que el
## primer cuadro llega igual y sin esto el arranque del juego moriría con un error de nulo.
func corriendo() -> bool:
	return _turno != null and not _turno.cerrado()


## Hace una tarea, y devuelve lo mismo que contestó el dominio.
##
## Emite **sólo** cuando el dominio dijo que sí. Los dos motivos de fallo —ya estaba hecha, o el
## turno cerró— son del `Turno` y no se distinguen acá.
##
## El guard no es una regla del juego: es el mismo estado nulo que ya guarda `_process()`. Sin
## turno no hay a quién preguntarle, y `obligatoria()` devuelve `null` **por diseño** cuando la
## jornada no pidió ese tipo, así que devolverlo derecho acá es la llamada natural. Que
## el turno esté cerrado, en cambio, **no** se guarda: el dominio ya contesta `false`.
func completar(tarea: Tarea) -> bool:
	if _turno == null or tarea == null or _cierre_reservado:
		return false
	if not _turno.completar(tarea):
		return false
	tarea_completada.emit(_turno.tareas_cumplidas())
	return true


## Deshace una tarea, con el mismo guard que `completar()`. La señal es aparte de
## `tarea_completada` para que la tabla de sonidos no suene al descumplir.
func descumplir(tarea: Tarea) -> bool:
	if _turno == null or tarea == null or _cierre_reservado:
		return false
	if not _turno.descumplir(tarea):
		return false
	tarea_descumplida.emit(_turno.tareas_cumplidas())
	return true


## La obligatoria de este tipo, o `null` si la jornada no la pidió.
##
## Es la única forma que tiene el resto del juego de nombrar la `Tarea` que va a completar:
## construir una copia devolvería `true` sin subir `tareas_cumplidas()`, y eso pasa en verde.
func obligatoria(tipo: Tarea.Tipo) -> Tarea:
	for tarea in _obligatorias:
		if tarea.tipo() == tipo:
			return tarea
	return null
