## Atiende las respuestas del jugador a las quejas de la jornada 7 y cuenta la obligatoria.
##
## **Traduce, no decide.** Si una respuesta vale, si es correcta y cuándo la tarea queda cumplida
## lo contesta `QuejasDeLaJornada`. Acá sólo se cablean el celular que muestra el chat abierto y
## el reloj que cuenta la obligatoria.
class_name RespondedorDeQuejas
extends Node

signal queja_respondida(quien: Conversacion.Interlocutor)

@export var reloj: RelojDelTurno
@export var celular: CelularDelEmpleado

var _quejas: QuejasDeLaJornada = null


## Las quejas de la noche que abre, o ninguna en una jornada que no las declara.
func arrancar(quejas: QuejasDeLaJornada) -> void:
	_quejas = quejas
	celular.usar_quejas(quejas)


func quejas() -> QuejasDeLaJornada:
	return _quejas


## Si el chat tiene una queja que todavía espera respuesta.
func admite_respuesta(quien: Conversacion.Interlocutor) -> bool:
	if _quejas == null:
		return false
	var indice := QuejasDeLaJornada.indice_de(quien)
	return indice >= 0 and not _quejas.respondida(indice)


## Responde la queja del chat que está abierto. Una queja respondida, o un chat que no es de un
## comprador, no cambia nada.
func pedir_responder(da_la_razon: bool) -> void:
	var abierto := celular.celular()
	if _quejas == null or not abierto.abierto() or abierto.pantalla() != Celular.Pantalla.CHAT:
		return
	var quien := abierto.chat()
	if not _quejas.responder(QuejasDeLaJornada.indice_de(quien), da_la_razon):
		return
	celular.bandeja().marcar_leida(quien)
	queja_respondida.emit(quien)
	if _quejas.cumplida():
		reloj.completar(reloj.obligatoria(Tarea.Tipo.RESPONDER_QUEJAS))
