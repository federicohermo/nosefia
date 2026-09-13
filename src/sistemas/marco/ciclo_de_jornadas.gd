## El nodo que hace correr una partida adentro del motor: abre la noche, escucha al reloj y
## publica lo que la partida contesta.
##
## **Traduce, no decide.** No sabe cuántas noches hay, ni cuánto pesa una noche mala, ni cuándo
## echan a alguien: todo eso se lo pregunta a `Partida`, que es donde tiene test. Los dos `if`
## de este archivo son preguntas al dominio y no decisiones propias.
##
## **No conoce la pantalla.** Emite hacia arriba y no pregunta nada: quien quiera dibujar el
## cierre de la noche —la pantalla del 017— se conecta a `jornada_cerrada` y vuelve a llamar a
## `abrir_la_jornada()` cuando el jugador la despacha. Reabrir no pasa solo a propósito: entre
## una noche y la siguiente hay una placa que leer.
class_name CicloDeJornadas
extends Node

signal jornada_abierta(jornada: int)
signal jornada_cerrada(jornada: int, cumplidas: int)
signal partida_terminada(final: Partida.Final)

var _partida: Partida = null
var _reloj: RelojDelTurno = null


## Le entrega al ciclo la partida y el reloj con el que va a correr, y abre la primera noche.
##
## El reloj entra por parámetro en vez de buscarse en el árbol: es lo que permite ejercer el
## ciclo entero sin levantar una escena, que es la única forma de correr cinco noches en un test.
func arrancar(partida: Partida, reloj: RelojDelTurno) -> void:
	_partida = partida
	_reloj = reloj
	_reloj.turno_cerrado.connect(_al_cerrar_el_turno)
	abrir_la_jornada()


## La partida que el ciclo está corriendo, o `null` si todavía no arrancó.
func partida() -> Partida:
	return _partida


## Abre la noche siguiente y devuelve si pudo.
##
## El guard cubre los dos estados en que no hay nada que abrir: el ciclo que todavía no arrancó
## —la escena existe antes de que alguien le pase una partida— y la partida que ya terminó. Sin
## el segundo, la pantalla del 017 reabriría una jornada después del despido.
func abrir_la_jornada() -> bool:
	if _partida == null or _partida.terminada():
		return false
	var turno := _partida.abrir_la_jornada()
	_reloj.arrancar(turno, _partida.obligatorias())
	jornada_abierta.emit(_partida.jornada())
	return true


## El número de la jornada se lee **antes** de cerrarla: cerrar avanza el contador, y quien
## escuche quiere saber cuál noche terminó, no cuál empieza.
func _al_cerrar_el_turno(cumplidas: int) -> void:
	var jornada := _partida.jornada()
	_partida.cerrar_la_jornada(cumplidas)
	jornada_cerrada.emit(jornada, cumplidas)
	if _partida.terminada():
		partida_terminada.emit(_partida.final())
