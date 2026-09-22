## Presentación de Manada UI sobre las aplicaciones existentes. El turno sigue corriendo.
class_name PantallaDeComputadora
extends CanvasLayer

signal app_pedida(app: Computadora.App)

## Chats conserva su cableado para una entrega posterior, pero no ofrece acceso en esta UI.
const TITULOS := {Computadora.App.CAJA: "/ REGISTRO:", Computadora.App.NOTAS: "/ NOTAS:"}
const BORDE_DERECHO := {Computadora.App.CAJA: 1857.0, Computadora.App.NOTAS: 1743.5}
const ICONO_REGISTRO := preload("res://assets/ui/manada/computadora.svg")
const ICONO_NOTAS := preload("res://assets/ui/manada/registro.svg")
const TAMANO_DEL_DISENO := Vector2(1920, 1080)
const TEXTO_DE_SALIDA := "CLIC DERECHO / VOLVER AL LOCAL"

@export var _fondo: ColorRect
@export var _marco: Control
@export var _titulo: Label
@export var _opciones: HBoxContainer
@export var _salida: Label
@export var _caja: AppCaja
@export var _chats: AppChats
@export var _notas: AppNotas


## Arranca apagada: la computadora se enciende cuando el jugador va al escritorio, no cuando
## empieza la noche.
func _ready() -> void:
	visible = false
	_salida.text = TEXTO_DE_SALIDA
	for app: Computadora.App in TITULOS:
		_opciones.add_child(_opcion_de(app))
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


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
	_titulo.text = TITULOS.get(app, "")
	_salida.offset_right = BORDE_DERECHO.get(app, 1857.0)
	for indice in TITULOS.size():
		var boton: Button = _opciones.get_child(indice)
		boton.set_pressed_no_signal(TITULOS.keys()[indice] == app)


func ocultar() -> void:
	visible = false


func _opcion_de(app: Computadora.App) -> Button:
	var boton := Button.new()
	boton.tooltip_text = TITULOS[app].trim_prefix("/ ").trim_suffix(":")
	boton.icon = ICONO_REGISTRO if app == Computadora.App.CAJA else ICONO_NOTAS
	boton.toggle_mode = true
	boton.theme_type_variation = &"Pestana"
	boton.custom_minimum_size = Vector2(90, 72)
	boton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton.pressed.connect(func() -> void: app_pedida.emit(app))
	return boton


## Escala sólo esta interfaz; no cambia el viewport ni la cámara del juego.
func _ajustar_al_viewport() -> void:
	var disponible := get_viewport().get_visible_rect().size
	var factor := minf(disponible.x / TAMANO_DEL_DISENO.x, disponible.y / TAMANO_DEL_DISENO.y)
	_marco.scale = Vector2.ONE * factor
	_marco.position = (disponible - TAMANO_DEL_DISENO * factor) / 2.0
