## El presupuesto de una noche: un tiempo finito que las tareas y la investigación se disputan.
##
## **El tiempo entra como parámetro.** `consumir()` recibe cuántos segundos pasaron; no los va a
## buscar al reloj del motor. Es lo que permite escribir «al agotarse el tiempo el turno cierra»
## sin esperar una noche, y lo que hace que esta clase se pueda ejercer sin levantar una escena.
##
## **Las obligatorias se reciben, no se construyen acá.** El turno no sabe que son cinco: cuenta
## contra las que le declararon. Una sexta tarea es un dato y no un cambio de código, y un turno
## de prueba se arma con una sola.
class_name Turno
extends RefCounted

var _tiempo_restante: float
var _obligatorias: Array[Tarea]


func _init(presupuesto: float, obligatorias: Array[Tarea]) -> void:
	_tiempo_restante = presupuesto
	_obligatorias = obligatorias


func tiempo_restante() -> float:
	return _tiempo_restante


## Los valores negativos se ignoran en silencio: el tiempo del turno sólo avanza, y el dominio
## no habla —ni con `push_error`— porque no tiene con quién.
func consumir(segundos: float) -> void:
	if segundos <= 0.0:
		return
	_tiempo_restante = maxf(0.0, _tiempo_restante - segundos)


func cerrado() -> bool:
	return _tiempo_restante <= 0.0


## Hace la tarea si el turno puede pagarla, y devuelve si pudo.
##
## Los dos motivos de fallo —ya estaba hecha, o no entra en lo que queda— devuelven lo mismo, y
## en los dos casos **no se consume nada**: una tarea a medias deja un estado que el jugador no
## puede distinguir de haberla hecho.
func completar(tarea: Tarea) -> bool:
	if tarea.completada():
		return false
	var costo := tarea.costo()
	if costo > _tiempo_restante:
		return false
	# El costo ya se verificó arriba, así que entre marcar y descontar no queda nada que pueda
	# fallar. El `false` de acá no lo produce ninguno de los dos motivos de rechazo de este
	# método: se chequea para que un motivo que `Tarea` sume más adelante no se cuele cobrado.
	if not tarea.completar():
		return false
	consumir(costo)
	return true


## Cuántas de las **obligatorias declaradas** están hechas. Una tarea completada que no estaba
## declarada consumió tiempo pero no cuenta: el jefe pide las que pidió.
func tareas_cumplidas() -> int:
	var cumplidas := 0
	for tarea in _obligatorias:
		if tarea.completada():
			cumplidas += 1
	return cumplidas


## Se compara contra las que se declararon y nunca contra un `5` escrito acá: es lo que hace que
## una sexta tarea sea un dato. Un turno sin obligatorias está completo por vacuidad, que es lo
## que corresponde: no quedó nada sin hacer.
func todas_cumplidas() -> bool:
	return tareas_cumplidas() == _obligatorias.size()
