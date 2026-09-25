## El nodo que repone adentro del motor: reserva una unidad del depósito, la pone en la mano y se
## la ofrece al estante cuando el jugador la deposita.
##
## **Traduce, no decide.** No sabe cuánto le entra a la góndola, ni qué productos van ahí, ni
## cuánto cuesta reponer: las tres son preguntas de `dominio/`, que es donde tienen test. Los
## `if` de este archivo son el valor que devolvió el estante y el estado nulo del cableado.
##
## **La unidad viaja en la mano y no en el inventario.** `pedir_retirar()` la reserva —el
## estante la anota en tránsito— y el stock recién se mueve cuando `pedir_colocar_de_la_mano()`
## la coloca. Al revés, soltar la unidad en el piso dejaría la góndola contando mercadería que
## el jugador nunca apoyó.
##
## **No lleva un flag de «ya la conté».** Le pide al reloj que complete la tarea cada vez que el
## estante queda lleno, y el `Turno` ya sabe que la segunda vez no cuenta —devuelve `false` sin
## descontar—. Un flag acá sería esa misma regla escrita en la capa que traduce, o sea una regla
## del juego sin test, y los dos gates darían verde sobre ella.
class_name Repositor
extends Node

signal producto_colocado(producto: Producto, completos: int)
signal colocacion_rechazada(motivo: Estante.Rechazo)
signal unidad_colocada(nodo: Node3D, producto: Producto, unidades: int)

## Los dos entran por `@export` y no como autoload ni por `get_node()` hacia arriba: está medido
## que `gate_de_capas.py` no ve un autoload nombrado por su nombre global, así que esa puerta
## cruzaría capas sin dejar rastro.
@export var reloj: RelojDelTurno
@export var agarre: Agarre

var _estante: Estante = null


## Le entrega al repositor el estante de la noche.
##
## La instancia se recibe y no se construye acá porque el estante necesita el inventario de la
## jornada, y quién abre una jornada es la escena. Es lo que permite que cada noche empiece sin
## nada repuesto sin que este nodo sepa qué es una jornada.
func arrancar(un_estante: Estante) -> void:
	if agarre != null and agarre.manos().sostenido() is UnidadDeProducto:
		agarre.entregar()
	_estante = un_estante


## El estante que se está reponiendo, para que quien dibuje pregunte en vez de copiar el estado.
func estante() -> Estante:
	return _estante


func pedir_retirar(id: Producto.Id, nodo: Node3D) -> bool:
	var producto := Catalogo.de(id)
	var candidato := UnidadDeProducto.new(producto)
	if agarre.manos().motivo_de_rechazo(candidato) != Manos.Rechazo.NINGUNO:
		return false
	var unidad := _estante.retirar(producto)
	if unidad == null:
		return false
	nodo.set("datos", unidad)
	return agarre.pedir_agarrar(unidad, nodo)


func pedir_colocar_de_la_mano(destino: Producto = null) -> void:
	var unidad := agarre.manos().sostenido() as UnidadDeProducto
	var motivo := _estante.colocar_unidad(unidad, destino)
	if motivo != Estante.Rechazo.NINGUNO:
		colocacion_rechazada.emit(motivo)
		return
	var nodo := agarre.entregar()
	unidad_colocada.emit(nodo, unidad.producto, _estante.unidades_en_gondola(unidad.producto))
	producto_colocado.emit(unidad.producto, _estante.productos_completos())
	if _estante.completada():
		reloj.completar(reloj.obligatoria(Tarea.Tipo.REPONER))
