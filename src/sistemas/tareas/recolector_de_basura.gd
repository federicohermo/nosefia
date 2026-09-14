## El nodo que saca la basura adentro del motor: recibe la bolsa y la distancia, se los pasa al
## dominio y publica lo que el dominio contestó.
##
## **Traduce, no decide.** Cuántas bolsas hay, qué cuenta como basura y a qué distancia vale
## soltarla son preguntas de `TareaDeLaBasura` y de `Trayecto`, que es donde tienen test. Los `if`
## de este archivo son el valor que devolvió el dominio y el estado nulo del cableado.
##
## **No lleva estado propio.** Cuántas van depositadas lo sabe la tarea, y que la obligatoria no
## se cuente dos veces lo sabe el `Turno`: un contador acá sería esa regla escrita en la capa que
## traduce, o sea una regla del juego sin test.
class_name RecolectorDeBasura
extends Node

signal bolsa_depositada(depositadas: int)
signal deposito_rechazado(motivo: TareaDeLaBasura.Resultado)

## Entra por `@export` y no como autoload: está medido que `gate_de_capas.py` no ve un autoload
## nombrado por su nombre global, así que esa puerta cruzaría capas sin dejar rastro.
@export var reloj: RelojDelTurno

var _tarea: TareaDeLaBasura = null


## Le entrega al recolector la tarea de la noche.
func arrancar(tarea: TareaDeLaBasura) -> void:
	_tarea = tarea


func tarea() -> TareaDeLaBasura:
	return _tarea


## Intenta dejar una bolsa en el descarte, y **devuelve el `Resultado` del dominio tal cual**.
##
## No lo traduce a un `bool`: los tres rechazos se leen distinto adelante del jugador, y aplanarlos
## daría un solo cartel para «eso no es basura», «ésa ya la trajiste» y «esto no es el fondo».
func pedir_depositar(id: StringName, distancia: float) -> TareaDeLaBasura.Resultado:
	if _tarea == null or reloj == null:
		# Un cableado incompleto es un `.tscn` mal armado y no un rechazo del juego: sale por el
		# panel de depuración, que es donde se lee.
		push_error("Recolector sin cablear: revisar almacen.tscn y almacen.gd")
		return TareaDeLaBasura.Resultado.NO_ES_BASURA
	var resultado := _tarea.depositar(id, distancia)
	if resultado != TareaDeLaBasura.Resultado.DEPOSITADA:
		deposito_rechazado.emit(resultado)
		return resultado
	bolsa_depositada.emit(_tarea.depositadas())
	if not _tarea.completada():
		return resultado
	# La `Tarea` sale de `RelojDelTurno.obligatoria()` y nunca de una construida acá: una copia
	# devuelve `true`, descuenta el tiempo igual y deja el contador del HUD clavado.
	reloj.completar(reloj.obligatoria(Tarea.Tipo.SACAR_LA_BASURA))
	return resultado
