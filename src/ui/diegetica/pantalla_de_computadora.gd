## La terminal de ventas. No pausa el turno: registrar cuesta minutos, igual que reponer.
class_name PantallaDeComputadora
extends CanvasLayer

signal boton_pulsado

const TEXTO_DEL_TITULO := "TERMINAL DE VENTAS  /  REGISTRO DE PRODUCTOS"

@export var _marco: Control
@export var _titulo: Label
@export var _caja: AppCaja


## Arranca apagada: la computadora se enciende cuando el jugador va al escritorio, no cuando
## empieza la noche.
func _ready() -> void:
	visible = false
	_titulo.text = TEXTO_DEL_TITULO
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()
	for boton in find_children("*", "BaseButton", true, false):
		_escuchar(boton)
	# El registro arma sus botones después de `_ready()`.
	get_tree().node_added.connect(_al_agregar_nodo)


func caja() -> AppCaja:
	return _caja


func mostrar() -> void:
	visible = true


func ocultar() -> void:
	visible = false


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
