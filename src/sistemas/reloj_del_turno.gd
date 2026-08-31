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
## seis nodos de `verificar.py` quedan en verde, porque ninguna regla se rompió.
##
## **No conoce la pantalla.** Emite hacia arriba y no pregunta nada: quien quiera mostrar algo se
## conecta a las señales.
class_name RelojDelTurno
extends Node

signal tiempo_consumido(restante: float)
signal tarea_completada(cumplidas: int)
signal turno_cerrado(cumplidas: int)

var _turno: Turno = null
var _obligatorias: Array[Tarea] = []


## Un cuadro de motor convertido en tiempo de turno.
##
## El guard es lo que hace que `turno_cerrado` se emita **una sola vez**: en cuanto el turno
## cierra, `corriendo()` pasa a `false` y el cuadro siguiente sale por acá. Se hace con el estado
## del dominio y no con `set_process(false)` para que el mismo código se pueda ejercer llamando
## `_process()` a mano, sin árbol de escena.
func _process(delta: float) -> void:
	if not corriendo():
		return
	_turno.consumir(Ritmo.escalar(delta))
	tiempo_consumido.emit(_turno.tiempo_restante())
	if _turno.cerrado():
		turno_cerrado.emit(_turno.tareas_cumplidas())


## Le entrega al reloj el turno de la jornada y la lista con la que se armó.
##
## La lista se recibe además del turno porque el `Turno` no la expone, y `obligatoria()` la
## necesita para contestar con la misma instancia que el turno está contando.
func arrancar(turno: Turno, obligatorias: Array[Tarea]) -> void:
	_turno = turno
	_obligatorias = obligatorias


## Si hay un turno en curso que todavía no se agotó.
##
## Sin turno también es `false`: la escena existe antes de que alguien le pase uno, así que el
## primer cuadro llega igual y sin esto el arranque del juego moriría con un error de nulo.
func corriendo() -> bool:
	return _turno != null and not _turno.cerrado()


## Hace una tarea, y devuelve lo mismo que contestó el dominio.
##
## Emite **sólo** cuando el dominio dijo que sí. Los dos motivos de fallo —ya estaba hecha, o no
## entra en lo que queda— son del `Turno` y no se distinguen acá.
func completar(tarea: Tarea) -> bool:
	if not _turno.completar(tarea):
		return false
	tarea_completada.emit(_turno.tareas_cumplidas())
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
