## El nodo que atiende adentro del motor: llama al siguiente comprador, cobra y publica lo que el
## dominio contestó.
##
## **Traduce, no decide.** No sabe cuánto marca la caja, ni si hay stock, ni cuándo la obligatoria
## está cumplida: las tres son preguntas de `Atencion` y `TareaDeAtender`, que es donde tienen
## test. Los `if` de este archivo son valores que devolvió el dominio y el estado nulo del
## cableado.
##
## **No pausa nada, y ésa es la decisión del spec.** El turno sigue corriendo con la ventanilla
## abierta: atender cuesta minutos, y un reloj congelado la volvería gratis. Las dos formas de
## congelarlo desde afuera del dominio están prohibidas en este archivo, y hay un caso que lo
## verifica sobre el texto — por eso no se las nombra ni acá: ese caso no distingue código de
## prosa, y hacerlo pasar comentando distinto sería trampa.
##
## **No lleva un flag de «ya la conté»**: le pide al reloj que complete `Tarea.Tipo.CAJA` cada vez
## que la tarea queda completa, y el `Turno` ya sabe que la segunda vez no cuenta.
class_name Ventanilla
extends Node

signal comprador_llegado(comprador: Comprador)
signal atencion_despachada(despachados: int)
signal cobro_rechazado(faltantes: Array[Producto])
signal ventanilla_vacia

## Entra por `@export` y no como autoload ni por `get_node()` hacia arriba: está medido que
## `gate_de_capas.py` no ve un autoload nombrado por su nombre global.
@export var reloj: RelojDelTurno

var _tarea: TareaDeAtender = null


## Le entrega a la ventanilla la tarea de la noche.
##
## La tarea se recibe y no se construye acá porque necesita el inventario de la jornada, que es
## **el mismo** que repone el 008: un segundo inventario sería un segundo stock, y las dos
## ventanas dirían números distintos del mismo producto.
func arrancar(tarea: TareaDeAtender) -> void:
	_tarea = tarea


func tarea() -> TareaDeAtender:
	return _tarea


## La atención en curso, o `null`.
func atencion() -> Atencion:
	if _tarea == null:
		return null
	return _tarea.atencion()


## Abre la ventanilla: sigue con quien esté esperando y sólo llama al siguiente si no hay nadie.
##
## Sin esta distinción, cerrar y reabrir el panel saltearía al comprador que estaba en la
## ventanilla — se iría sin despachar y la obligatoria quedaría imposible, sin un solo error.
## Quién está esperando lo contesta el dominio; acá sólo se rutea.
func pedir_abrir() -> void:
	if _sin_cablear():
		return
	var esperando := _tarea.en_ventanilla()
	if esperando == null:
		pedir_atender()
		return
	comprador_llegado.emit(esperando)


## Llama al siguiente comprador y avisa quién llegó, o que no queda nadie.
func pedir_atender() -> void:
	if _sin_cablear():
		return
	var comprador := _tarea.atender()
	if comprador == null:
		ventanilla_vacia.emit()
		return
	comprador_llegado.emit(comprador)


## Cobra el pedido del que está en la ventanilla y avisa cómo salió.
##
## Emite **una** de las dos señales y nunca las dos: emitirlas juntas dejaría a la pantalla
## despachando al comprador y avisando que falta mercadería al mismo tiempo.
func pedir_cobrar() -> void:
	if _sin_cablear():
		return
	var en_curso := atencion()
	if en_curso == null:
		return
	var resultado := en_curso.cobrar()
	if resultado == Atencion.Resultado.SIN_STOCK:
		cobro_rechazado.emit(en_curso.faltantes_del_pedido())
		return
	if resultado != Atencion.Resultado.COBRADA:
		return
	_al_despachar()


## Lo despacha sin cobrarle. Es lo que deja cumplir la obligatoria con la góndola vacía.
func pedir_despachar_sin_vender() -> void:
	if _sin_cablear():
		return
	var en_curso := atencion()
	if en_curso == null or not en_curso.despachar_sin_vender():
		return
	_al_despachar()


## Publica el despacho y, si no quedó nadie, le pide al reloj que cuente la obligatoria.
##
## La `Tarea` sale de `RelojDelTurno.obligatoria()` y nunca de una construida acá: una copia
## devuelve `true`, descuenta el tiempo igual y deja el contador del HUD clavado — la tarea hecha
## y la pantalla diciendo que no, sin error y en verde.
func _al_despachar() -> void:
	atencion_despachada.emit(_tarea.despachados())
	if not _tarea.completada():
		return
	reloj.completar(reloj.obligatoria(Tarea.Tipo.CAJA))


## Si falta algo del cableado. Un `.tscn` mal armado no es un rechazo del juego, así que no sale
## por las señales de rechazo: sale por el panel de depuración, que es donde se lee.
func _sin_cablear() -> bool:
	if _tarea != null and reloj != null:
		return false
	push_error("Ventanilla sin cablear: revisar almacen.tscn y almacen.gd")
	return true
