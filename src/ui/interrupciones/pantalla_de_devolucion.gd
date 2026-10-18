## La devolución de Enrique en pantalla: el celular fijo en su chat, un mensaje más por segundo,
## y la opción debajo del último cuando ése está a la vista.
##
## Qué dice cada mensaje y qué se ofrece lo decidió `DevolucionDelJefe`; acá se cuenta el tiempo
## y se entregan los mensajes al chat. El tiempo es el del árbol: con la pausa en pantalla no
## corre, y al reanudar sigue desde el mismo mensaje.
##
## No dibuja nada propio: el celular tiene su capa. Está visible desde que llega la devolución
## hasta que el cierre termina, reflexión incluida, y por eso la pausa la mira como placa.
class_name PantallaDeDevolucion
extends CanvasLayer

signal devolucion_despachada(opcion: DevolucionDelJefe.Opcion)

## Las palabras de cada opción viven acá.
const TEXTOS: Dictionary[DevolucionDelJefe.Opcion, String] = {
	DevolucionDelJefe.Opcion.CONTINUAR: "CONTINUAR",
	DevolucionDelJefe.Opcion.VOLVER_AL_MENU: MenuDePausa.TEXTO_DE_VOLVER_AL_MENU,
}

var _celular: CelularDelEmpleado
var _pantalla_del_celular: PantallaDelCelular
var _mensajes: Array[Mensaje] = []
var _opcion: DevolucionDelJefe.Opcion = DevolucionDelJefe.Opcion.CONTINUAR
var _tiempo_de_la_entrega: float = 0.0
var _entregados: int = 0
var _esperando_el_centro := false
var _despachada := false


func _ready() -> void:
	visible = false
	set_process(false)


## El celular y su pantalla llegan del cableado de la escena: son de otro puesto.
func preparar(celular: CelularDelEmpleado, pantalla_del_celular: PantallaDelCelular) -> void:
	_celular = celular
	_pantalla_del_celular = pantalla_del_celular
	_pantalla_del_celular.opcion_elegida.connect(elegir)


## Sube el celular fijo en el chat de Enrique y entrega el primer mensaje.
func mostrar(devolucion: DevolucionDelJefe) -> void:
	_mensajes = devolucion.mensajes_fechados()
	_opcion = devolucion.opciones()[0]
	_tiempo_de_la_entrega = 0.0
	_entregados = 0
	_esperando_el_centro = true
	_despachada = false
	visible = true
	_celular.mostrar_fijo(Conversacion.Interlocutor.JEFE)
	_entregar()
	set_process(true)


## Cuántos mensajes de la devolución ya llegaron al chat.
func a_la_vista() -> int:
	return _entregados


## La opción ofrecida, recién cuando el último mensaje está a la vista.
func opcion_a_la_vista() -> bool:
	return visible and not _despachada and _entregados == _mensajes.size()


func _process(delta: float) -> void:
	if _esperando_el_centro:
		if _pantalla_del_celular.centrado():
			_esperando_el_centro = false
		return
	_tiempo_de_la_entrega += delta
	_entregar()


func _entregar() -> void:
	var visibles := DevolucionDelJefe.a_la_vista(_tiempo_de_la_entrega, _mensajes.size())
	if _entregados < visibles:
		_entregados += 1
		_tiempo_de_la_entrega = (_entregados - 1) * DevolucionDelJefe.SEGUNDOS_ENTRE_MENSAJES
		_celular.recibir(Conversacion.Interlocutor.JEFE, _mensajes[_entregados - 1])
	if _entregados == _mensajes.size():
		set_process(false)
		_pantalla_del_celular.mostrar_opcion(TEXTOS[_opcion])


## Elegir antes de tiempo o dos veces no despacha nada. El celular sigue fijo: quien despacha
## decide si pasa a las notas o lo suelta con `cerrar()`.
func elegir() -> void:
	if not opcion_a_la_vista():
		return
	_despachada = true
	_pantalla_del_celular.quitar_opcion()
	devolucion_despachada.emit(_opcion)


## Termina el cierre: suelta el celular y deja de ser la placa de la pausa.
func cerrar() -> void:
	visible = false
	_celular.soltar()
