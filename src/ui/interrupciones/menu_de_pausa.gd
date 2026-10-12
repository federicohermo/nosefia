## El menú de pausa: dibuja cuatro botones y emite el pedido de cada uno. No decide nada.
##
## Corre sólo en pausa: aparece cuando el árbol se detiene, y sus botones tienen que recibir el
## clic justamente entonces. Configuraciones abre su pantalla encima, sin salir de la pausa; logros
## se ve deshabilitado, porque su pantalla no tiene el diseño cerrado.
class_name MenuDePausa
extends CanvasLayer

signal reanudar_pedido
signal volver_al_menu_pedido

const TEXTO_DEL_TITULO := "/ PAUSA:"
const TEXTO_DE_REANUDAR := "REANUDAR"
const TEXTO_DE_CONFIGURACIONES := "CONFIGURACIONES"
const TEXTO_DE_LOGROS := "LOGROS"
const TEXTO_DE_VOLVER_AL_MENU := "VOLVER AL MENÚ"

@export var _marco: Control
@export var _titulo: Label
@export var _reanudar: Button
@export var _configuraciones: Button
@export var _logros: Button
@export var _volver_al_menu: Button
@export var _pantalla: PantallaDeConfiguraciones


func _ready() -> void:
	visible = false
	_titulo.text = TEXTO_DEL_TITULO
	_reanudar.text = TEXTO_DE_REANUDAR
	_configuraciones.text = TEXTO_DE_CONFIGURACIONES
	_logros.text = TEXTO_DE_LOGROS
	_volver_al_menu.text = TEXTO_DE_VOLVER_AL_MENU
	_reanudar.pressed.connect(reanudar_pedido.emit)
	_volver_al_menu.pressed.connect(volver_al_menu_pedido.emit)
	_configuraciones.pressed.connect(abrir_configuraciones)
	_pantalla.cerrada.connect(_al_cerrar_configuraciones)
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


func mostrar() -> void:
	visible = true
	_reanudar.grab_focus()


## También baja configuraciones: es otra capa, y no se oculta con la del menú.
func ocultar() -> void:
	visible = false
	_pantalla.visible = false
	_marco.visible = true


func configuraciones() -> PantallaDeConfiguraciones:
	return _pantalla


func configuraciones_abierta() -> bool:
	return _pantalla.visible


func abrir_configuraciones() -> void:
	_marco.visible = false
	_pantalla.abrir()


func cerrar_configuraciones() -> void:
	_pantalla.cerrar()


func _al_cerrar_configuraciones() -> void:
	_marco.visible = true
	_reanudar.grab_focus()


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
