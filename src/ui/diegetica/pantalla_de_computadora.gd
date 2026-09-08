## La pantalla de la computadora: las tres apps y las pestañas para cambiar entre ellas.
##
## **No decide cuál se ve.** Qué app está abierta lo lleva `Computadora`, que es de `dominio/` y
## tiene test: acá se recibe cuál y se prende ésa. Es la trampa que este spec vino a esquivar —
## `src/ui/` no lleva test obligatorio, así que un `if` sobre el juego escrito acá nace sin
## ninguno y los seis nodos dan verde.
##
## **No pausa nada, y es deliberado**: mientras la pantalla está arriba el turno sigue corriendo.
## Leer cuesta lo mismo que reponer, y el jugador se entera porque el reloj no se detuvo.
##
## Va en `diegetica/` y no en `interrupciones/`, que es exactamente ese criterio.
class_name PantallaDeComputadora
extends CanvasLayer

signal app_pedida(app: Computadora.App)

## Las palabras de las tres pestañas, en el orden del `enum` del dominio. Es la única lista de
## este archivo, y se recorre contra `Computadora.App.values()`: una pestaña de más o de menos se
## ve enseguida porque no le toca ninguna app.
const TEXTOS_DE_LAS_PESTANAS := ["Caja", "Chats", "Notas"]

@export var _fondo: ColorRect
@export var _pestanas: HBoxContainer
@export var _caja: AppCaja
@export var _chats: AppChats
@export var _notas: AppNotas


## Arranca apagada: la computadora se enciende cuando el jugador va al escritorio, no cuando
## empieza la noche.
func _ready() -> void:
	visible = false
	for app: Computadora.App in Computadora.App.values():
		_pestanas.add_child(_pestana_de(app))


func caja() -> AppCaja:
	return _caja


func chats() -> AppChats:
	return _chats


func notas() -> AppNotas:
	return _notas


## Enciende la pantalla en esa app.
func mostrar(app: Computadora.App) -> void:
	visible = true
	cambiar_a(app)


## Prende una de las tres y apaga las otras dos. Recibe cuál: cuál corresponde lo decidió el
## dominio.
func cambiar_a(app: Computadora.App) -> void:
	_caja.visible = app == Computadora.App.CAJA
	_chats.visible = app == Computadora.App.CHATS
	_notas.visible = app == Computadora.App.NOTAS


func ocultar() -> void:
	visible = false


func _pestana_de(app: Computadora.App) -> Button:
	var boton := Button.new()
	boton.text = TEXTOS_DE_LAS_PESTANAS[app]
	boton.pressed.connect(func() -> void: app_pedida.emit(app))
	return boton
