## Conecta el dep?sito, las manos y el estante. El dominio valida cada movimiento.
class_name Repositor
extends Node

signal producto_colocado(producto: Producto, completos: int)
signal colocacion_rechazada(motivo: Estante.Rechazo)
signal unidad_colocada(nodo: Node3D, producto: Producto, unidades: int)

## Los dos entran por `@export` y no como autoload ni por `get_node()` hacia arriba: está medido
## que `gate_de_capas.py` no ve un autoload nombrado por su nombre global, así que esa puerta
## cruzaría capas sin dejar rastro.
@export var reloj: RelojDelTurno
@export var carga: CargaDeLaCaja
@export var agarre: Agarre

var _estante: Estante = null


## Le entrega al repositor el estante de la noche.
##
## La instancia se recibe y no se construye acá porque el estante necesita el inventario de la
## jornada, y quién abre una jornada es la escena. Es lo que permite que cada noche empiece con
## la góndola vacía sin que este nodo sepa qué es una jornada.
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
