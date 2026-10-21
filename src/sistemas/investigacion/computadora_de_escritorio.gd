## El nodo que hace correr la computadora adentro del motor: recibe el pedido, se lo pasa al
## dominio y publica lo que el dominio contestó.
##
## Conserva el registro al cerrar la pantalla. La presentación recibe esa misma planilla
## cuando el jugador vuelve al escritorio.
##
## **Traduce, no decide.** Cuándo se puede abrir y si lo anotado coincide con lo
## vendido son preguntas de `dominio/`.
##
## **No consume tiempo del turno y no lo pausa.** Usar la computadora no descuenta un segundo: lo
## que cuesta es que el reloj no se detuvo mientras el jugador leía. Las dos formas de congelarlo
## desde afuera del dominio están prohibidas en este archivo y hay un caso que lo verifica sobre
## el texto — por eso tampoco se las nombra acá.
class_name ComputadoraDeEscritorio
extends Node

signal computadora_abierta
signal computadora_cerrada
signal registro_actualizado

## Entra por `@export` y no como autoload ni por `get_node()` hacia arriba: está medido que
## `gate_de_capas.py` no ve un autoload nombrado por su nombre global.
@export var reloj: RelojDelTurno

var _computadora := Computadora.new()

var _registro: RegistroDeVentas = null


## Le entrega a la computadora la planilla de la noche.
##
## La planilla se recibe y no se construye acá porque compara contra las ventas de la jornada, que
## son las de la ventanilla: una segunda atención daría otra noche sin ventas.
func arrancar(registro: RegistroDeVentas) -> void:
	_registro = registro
	if reloj != null and not reloj.cierre_iniciado.is_connected(_al_iniciar_el_cierre):
		reloj.cierre_iniciado.connect(_al_iniciar_el_cierre)
	revisar_registro()


func computadora() -> Computadora:
	return _computadora


func registro() -> RegistroDeVentas:
	return _registro


func bloquear_registro() -> void:
	if _registro == null or not _registro.editable():
		return
	_registro.bloquear()
	registro_actualizado.emit()


## Enciende la terminal de ventas.
func pedir_abrir() -> void:
	if not _computadora.abrir():
		return
	computadora_abierta.emit()


func pedir_cerrar() -> void:
	if not _computadora.cerrar():
		return
	computadora_cerrada.emit()


func pedir_sumar(producto: Producto) -> void:
	if _cableada() and _registro.sumar(producto):
		_al_cambiar_el_registro()


func pedir_restar(producto: Producto) -> void:
	if _cableada() and _registro.restar(producto):
		_al_cambiar_el_registro()


func revisar_registro(al_cerrar: bool = false) -> void:
	if not _cableada():
		return
	var registrar := reloj.obligatoria(Tarea.Tipo.REGISTRAR)
	if _registro.completada(al_cerrar):
		reloj.completar(registrar)
	else:
		reloj.descumplir(registrar)


func _al_iniciar_el_cierre() -> void:
	revisar_registro(true)


func _al_cambiar_el_registro() -> void:
	registro_actualizado.emit()
	revisar_registro()


func _cableada() -> bool:
	if _registro == null or reloj == null:
		# Un cableado incompleto es un `.tscn` mal armado y no un rechazo del juego: sale por el
		# panel de depuración, que es donde se lee.
		push_error("Computadora sin cablear: revisar almacen.tscn y almacen.gd")
		return false
	return true
