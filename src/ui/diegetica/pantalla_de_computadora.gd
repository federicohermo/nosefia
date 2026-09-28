## La pantalla de la computadora, con la gráfica de Manada.
##
## No decide cuál app se ve: eso lo lleva `Computadora`, que tiene test. Acá se recibe cuál y se
## prende ésa. No pausa el turno: leer cuesta minutos, igual que reponer.
class_name PantallaDeComputadora
extends CanvasLayer

signal app_pedida(app: Computadora.App)
signal boton_pulsado

## Chats conserva su cableado para una entrega posterior, pero no ofrece acceso en esta UI.
const TITULOS := {Computadora.App.CAJA: "/ REGISTRO:", Computadora.App.NOTAS: "/ NOTAS:"}
const BORDE_DERECHO := {Computadora.App.CAJA: 1857.0, Computadora.App.NOTAS: 1743.5}
const ICONO_REGISTRO := preload("res://assets/ui/manada/computadora.svg")
const ICONO_NOTAS := preload("res://assets/ui/manada/registro.svg")

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
	_salida.text = LienzoDeManada.TEXTO_DE_SALIDA
	for app: Computadora.App in TITULOS:
		_opciones.add_child(_opcion_de(app))
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()
	for boton in find_children("*", "BaseButton", true, false):
		_escuchar(boton)
	# Las apps arman botones después de `_ready()`.
	get_tree().node_added.connect(_al_agregar_nodo)


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


func _al_agregar_nodo(nodo: Node) -> void:
	if nodo is BaseButton and is_ancestor_of(nodo):
		_escuchar(nodo)


func _escuchar(boton: BaseButton) -> void:
	var avisar := _al_pulsar.bind(boton)
	if not boton.pressed.is_connected(avisar):
		boton.pressed.connect(avisar)


func _al_pulsar(boton: BaseButton) -> void:
	if not boton.disabled:
		boton_pulsado.emit()


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
