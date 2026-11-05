## La pantalla del final de la partida: su encabezado, su título y un solo botón para volver al
## menú. Dibuja el final que le piden y avisa el gesto; no decide cuál es: lo decide `Partida`.
##
## Se dibuja sobre la persiana ya baja de la devolución. El lugar del mensaje del jefe queda en
## el molde, vacío, hasta que el diseño lo defina (OQ-SHF-008).
class_name PantallaDeFinal
extends CanvasLayer

signal volver_al_menu_pedido

const ENCABEZADOS: Dictionary[FinalConPantalla.Cual, String] = {
	FinalConPantalla.Cual.DESPEDIDO: "/ FIN DEL JUEGO",
	FinalConPantalla.Cual.EMPLEADO_ESTRESADO: "/ FINAL 1",
}
const TITULOS: Dictionary[FinalConPantalla.Cual, String] = {
	FinalConPantalla.Cual.DESPEDIDO: "DESPEDIDO",
	FinalConPantalla.Cual.EMPLEADO_ESTRESADO: "EMPLEADO ESTRESADO",
}
const TEXTO_DEL_BOTON := MenuDePausa.TEXTO_DE_VOLVER_AL_MENU

@export var _marco: Control
@export var _encabezado: Label
@export var _titulo: Label
@export var _boton: Button

var _pedido := false


func _ready() -> void:
	visible = false
	_boton.text = TEXTO_DEL_BOTON
	_boton.pressed.connect(_pedir_el_menu)
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


## Un final sin pantalla no se dibuja: quien la abre ya lo decidió, y acá no se improvisa uno.
func mostrar(final: FinalConPantalla.Cual) -> void:
	if not ENCABEZADOS.has(final):
		push_error("Este final no tiene pantalla")
		return
	_encabezado.text = ENCABEZADOS[final]
	_titulo.text = TITULOS[final]
	_pedido = false
	visible = true
	_boton.grab_focus(true)


func encabezado() -> String:
	return _encabezado.text


func titulo() -> String:
	return _titulo.text


func boton() -> Button:
	return _boton


## Pulsarlo dos veces no pide dos veces el menú.
func _pedir_el_menu() -> void:
	if _pedido:
		return
	_pedido = true
	volver_al_menu_pedido.emit()


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
