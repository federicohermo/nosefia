## El nodo que repone adentro del motor: saca una unidad de la caja de traslado, se la ofrece al
## estante y publica lo que el estante contestó.
##
## **Traduce, no decide.** No sabe cuánto le entra a la góndola, ni qué productos van ahí, ni
## cuánto cuesta reponer: las tres son preguntas de `dominio/`, que es donde tienen test. Los
## `if` de este archivo son el valor que devolvió el estante y el estado nulo del cableado.
##
## **No lleva un flag de «ya la conté».** Le pide al reloj que complete la tarea cada vez que el
## estante queda lleno, y el `Turno` ya sabe que la segunda vez no cuenta —devuelve `false` sin
## descontar—. Un flag acá sería esa misma regla escrita en la capa que traduce, o sea una regla
## del juego sin test, y los dos gates darían verde sobre ella.
##
## **Es el cliente que le faltaba a `CargaDeLaCaja`.** La caja del 033 es dónde viaja la
## mercadería y este nodo es quien la descarga: sin él la caja se podía llenar y no había nada
## que la vaciara, y eso no lo dice ningún gate.
class_name Repositor
extends Node

signal producto_colocado(producto: Producto, completos: int)
signal colocacion_rechazada(motivo: Estante.Rechazo)

## Los dos entran por `@export` y no como autoload ni por `get_node()` hacia arriba: está medido
## que `gate_de_capas.py` no ve un autoload nombrado por su nombre global, así que esa puerta
## cruzaría capas sin dejar rastro.
@export var reloj: RelojDelTurno
@export var carga: CargaDeLaCaja

var _estante: Estante = null


## Le entrega al repositor el estante de la noche.
##
## La instancia se recibe y no se construye acá porque el estante necesita el inventario de la
## jornada, y quién abre una jornada es la escena. Es lo que permite que cada noche empiece con
## la góndola vacía sin que este nodo sepa qué es una jornada.
func arrancar(un_estante: Estante) -> void:
	_estante = un_estante


## El estante que se está reponiendo, para que quien dibuje pregunte en vez de copiar el estado.
func estante() -> Estante:
	return _estante


## Intenta colocar una unidad de lo que haya arriba de la caja, y avisa cómo salió.
##
## Emite **una** de las dos señales y nunca las dos: emitirlas juntas dejaría a la escena
## pintando un hueco nuevo y un cartel de «no entra» al mismo tiempo.
##
## La unidad se saca de la caja **después** de que el estante la aceptó. Al revés, un rechazo
## dejaría al jugador con la caja vacía y el estante sin llenar, sin un solo error.
func pedir_colocar() -> void:
	if _estante == null or reloj == null or carga == null:
		# Un cableado incompleto es un `.tscn` mal armado y no un rechazo del juego: emitir
		# `colocacion_rechazada` acá le diría al jugador que eso no va en el estante, que sería
		# falso. Quien caza esto es `test/escenas/almacen_test.gd`.
		push_error("Repositor sin cablear: revisar almacen.tscn")
		return
	var producto := _proximo_de_la_caja()
	var motivo := _estante.colocar(producto)
	if motivo != Estante.Rechazo.NINGUNO:
		colocacion_rechazada.emit(motivo)
		return
	carga.caja().sacar()
	producto_colocado.emit(producto, _estante.productos_completos())
	if _estante.completada():
		reloj.completar(reloj.obligatoria(Tarea.Tipo.REPONER))


## Lo que está arriba de todo en la caja, **sin sacarlo**, o `null` si la caja está vacía.
##
## Ese `null` no es un caso especial: el estante lo rechaza por el mismo camino que a un producto
## que no acepta, así que acá no hay que decidir nada.
func _proximo_de_la_caja() -> Producto:
	var contenido := carga.caja().contenido()
	if contenido.is_empty():
		return null
	return contenido[-1]
