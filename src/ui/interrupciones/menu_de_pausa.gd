## El menú de pausa: dibuja cuatro botones y emite el pedido de cada uno. No decide nada.
##
## Corre sólo en pausa: aparece cuando el árbol se detiene, y sus botones tienen que recibir el
## clic justamente entonces. Configuraciones y logros abren su pantalla encima, sin salir de la
## pausa.
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
@export var _pantalla_de_logros: PantallaDeLogros


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
	_logros.pressed.connect(abrir_logros)
	_pantalla.cerrada.connect(_al_cerrar_configuraciones)
	_pantalla_de_logros.cerrada.connect(_al_cerrar_logros)
	# Una capa hija no hereda el orden de la madre: sin esto, el almacén sube la pausa por encima
	# de configuraciones y su fondo tapa la pantalla y se come los clics.
	_pantalla.layer = layer + 1
	_pantalla_de_logros.layer = layer + 1
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


func mostrar() -> void:
	visible = true
	_reanudar.grab_focus(true)


## También baja configuraciones y logros: son otras capas, y no se ocultan con la del menú.
func ocultar() -> void:
	visible = false
	_pantalla.visible = false
	_pantalla_de_logros.visible = false
	_marco.visible = true


func configuraciones() -> PantallaDeConfiguraciones:
	return _pantalla


func configuraciones_abierta() -> bool:
	return _pantalla.visible


func pantalla_de_logros() -> PantallaDeLogros:
	return _pantalla_de_logros


func logros_abierta() -> bool:
	return _pantalla_de_logros.visible


func abrir_logros() -> void:
	_marco.visible = false
	_pantalla_de_logros.abrir()


func cerrar_logros() -> void:
	_pantalla_de_logros.cerrar()


func abrir_configuraciones() -> void:
	_marco.visible = false
	_pantalla.abrir()


func cerrar_configuraciones() -> void:
	_pantalla.cerrar()


func _al_cerrar_configuraciones() -> void:
	_marco.visible = true
	_reanudar.grab_focus(true)


func _al_cerrar_logros() -> void:
	_marco.visible = true
	_logros.grab_focus(true)


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
