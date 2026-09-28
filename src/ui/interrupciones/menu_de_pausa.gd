## El menú de pausa: dibuja cuatro botones y emite el pedido de cada uno. No decide nada.
##
## Corre sólo en pausa: aparece cuando el árbol se detiene, y sus botones tienen que recibir el
## clic justamente entonces. Configuraciones y logros se ven deshabilitados: sus pantallas no
## tienen el diseño cerrado.
class_name MenuDePausa
extends CanvasLayer

signal reanudar_pedido
signal volver_al_menu_pedido

const TEXTO_DE_REANUDAR := "REANUDAR"
const TEXTO_DE_CONFIGURACIONES := "CONFIGURACIONES"
const TEXTO_DE_LOGROS := "LOGROS"
const TEXTO_DE_VOLVER_AL_MENU := "VOLVER AL MENÚ"

@export var _marco: Control
@export var _reanudar: Button
@export var _configuraciones: Button
@export var _logros: Button
@export var _volver_al_menu: Button


func _ready() -> void:
	visible = false
	_reanudar.text = TEXTO_DE_REANUDAR
	_configuraciones.text = TEXTO_DE_CONFIGURACIONES
	_logros.text = TEXTO_DE_LOGROS
	_volver_al_menu.text = TEXTO_DE_VOLVER_AL_MENU
	_reanudar.pressed.connect(reanudar_pedido.emit)
	_volver_al_menu.pressed.connect(volver_al_menu_pedido.emit)
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


func mostrar() -> void:
	visible = true
	_reanudar.grab_focus()


func ocultar() -> void:
	visible = false


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
