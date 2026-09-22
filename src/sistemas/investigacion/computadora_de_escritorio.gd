## El nodo que hace correr la computadora adentro del motor: recibe el pedido, se lo pasa al
## dominio y publica lo que el dominio contestó.
##
## **Es dueño de las cuatro piezas del dominio, y ésa es la decisión del spec.** Si las
## construyera la pantalla, esconder el panel al cambiar de app tiraría lo leído y lo anotado —
## sin un solo error, y con los seis nodos en verde, porque `ui/` no lleva test obligatorio.
##
## **Traduce, no decide.** Cuándo se puede abrir, qué app sigue, qué cuenta como faltante y cuándo
## `REGISTRAR` está cumplida son preguntas de `dominio/`. Los `if` de este archivo son valores que
## devolvió el dominio y el estado nulo del cableado.
##
## **No consume tiempo del turno y no lo pausa.** Usar la computadora no descuenta un segundo: lo
## que cuesta es que el reloj no se detuvo mientras el jugador leía. Las dos formas de congelarlo
## desde afuera del dominio están prohibidas en este archivo y hay un caso que lo verifica sobre
## el texto — por eso tampoco se las nombra acá.
class_name ComputadoraDeEscritorio
extends Node

signal computadora_abierta(app: Computadora.App)
signal computadora_cerrada
signal app_cambiada(app: Computadora.App)
signal chats_actualizados(sin_leer: int)
signal nota_escrita(nota: Nota)
signal caja_actualizada(registrados: int)

## Entra por `@export` y no como autoload ni por `get_node()` hacia arriba: está medido que
## `gate_de_capas.py` no ve un autoload nombrado por su nombre global.
@export var reloj: RelojDelTurno

var _computadora := Computadora.new()

## La bandeja y el cuaderno se arman en la declaración y **una sola vez**: son el estado que tiene
## que sobrevivir a cerrar y a cambiar de app.
var _bandeja := Bandeja.new(Conversacion.desde_disco())
var _cuaderno := Cuaderno.new()

var _caja: CajaRegistradora = null


## Le entrega a la computadora la caja de la noche.
##
## La caja se recibe y no se construye acá porque necesita el inventario de la jornada, que es el
## mismo que reponen el 008 y vacía la ventanilla del 013: un segundo inventario sería un segundo
## stock, y las dos pantallas dirían números distintos del mismo producto.
func arrancar(caja: CajaRegistradora) -> void:
	_caja = caja


func computadora() -> Computadora:
	return _computadora


func bandeja() -> Bandeja:
	return _bandeja


func cuaderno() -> Cuaderno:
	return _cuaderno


func caja() -> CajaRegistradora:
	return _caja


## Enciende la pantalla en la app donde se dejó, y avisa cuál es.
func pedir_abrir() -> void:
	if not _computadora.abrir():
		return
	computadora_abierta.emit(_computadora.app())


func pedir_cerrar() -> void:
	if not _computadora.cerrar():
		return
	computadora_cerrada.emit()


func pedir_cambiar_a(app: Computadora.App) -> void:
	if not _computadora.cambiar_a(app):
		return
	app_cambiada.emit(app)


## Marca una conversación como leída y publica cuántos mensajes quedan sin leer en total.
func pedir_marcar_leida(quien: Conversacion.Interlocutor) -> void:
	if not _bandeja.marcar_leida(quien):
		return
	chats_actualizados.emit(_bandeja.no_leidos_totales())


## Anota en el cuaderno y avisa. Lo que no llega a ser una nota no emite nada: qué llega y qué no
## lo decide `Cuaderno`, que es donde tiene test.
func pedir_escribir(titulo: String, texto: String) -> void:
	var nota := _cuaderno.escribir(titulo, texto)
	if nota == null:
		return
	nota_escrita.emit(nota)


## Pasa un producto por la caja y, si no queda ninguno, le pide al reloj que cuente la obligatoria.
##
## La `Tarea` sale de `RelojDelTurno.obligatoria()` y nunca de una construida acá: una copia
## devuelve `true`, descuenta el tiempo igual y deja el `"3/5"` del HUD diciendo que no — sin
## error y en verde.
func pedir_registrar(producto: Producto) -> void:
	if _caja == null or reloj == null:
		# Un cableado incompleto es un `.tscn` mal armado y no un rechazo del juego: sale por el
		# panel de depuración, que es donde se lee.
		push_error("Computadora sin cablear: revisar almacen.tscn y almacen.gd")
		return
	if not _caja.registrar(producto):
		return
	caja_actualizada.emit(_caja.registrados())
	if not _caja.completada():
		return
	reloj.completar(reloj.obligatoria(Tarea.Tipo.REGISTRAR))
