## La pantalla del final de la partida: su encabezado, su título, el mensaje del final y dos
## botones, uno para comenzar de nuevo y otro para volver al menú. Dibuja el final que le piden y
## avisa el gesto; no decide cuál es: lo decide `Partida`.
##
## Se dibuja sobre la persiana ya baja de la devolución.
class_name PantallaDeFinal
extends CanvasLayer

signal volver_al_menu_pedido
signal nueva_partida_pedida

const ENCABEZADOS: Dictionary[FinalConPantalla.Cual, String] = {
	FinalConPantalla.Cual.DESPEDIDO: "/ FIN DEL JUEGO",
	FinalConPantalla.Cual.EMPLEADO_ESTRESADO: "/ FINAL 1",
	FinalConPantalla.Cual.LOCURA_PARANOICA: "/ FINAL 2",
	FinalConPantalla.Cual.JEFE_SABOTEADOR: "/ FINAL 4",
	FinalConPantalla.Cual.JEFE_INCOMPETENTE: "/ FINAL 5",
}
const TITULOS: Dictionary[FinalConPantalla.Cual, String] = {
	FinalConPantalla.Cual.DESPEDIDO: "DESPEDIDO",
	FinalConPantalla.Cual.EMPLEADO_ESTRESADO: "EMPLEADO EXPLOTADO",
	FinalConPantalla.Cual.LOCURA_PARANOICA: "LOCURA PARANOICA",
	FinalConPantalla.Cual.JEFE_SABOTEADOR: "JEFE SABOTEADOR",
	FinalConPantalla.Cual.JEFE_INCOMPETENTE: "JEFE INCOMPETENTE",
}
const TEXTO_DE_NUEVA_PARTIDA := "COMENZAR NUEVA PARTIDA"
const TEXTO_DE_VOLVER := MenuDePausa.TEXTO_DE_VOLVER_AL_MENU

@export var _marco: Control
@export var _encabezado: Label
@export var _titulo: Label
@export var _mensaje: Label
@export var _boton_de_nueva_partida: Button
@export var _boton_de_volver: Button

var _pedido := false
var _azar := RandomNumberGenerator.new()


func _ready() -> void:
	visible = false
	_azar.randomize()
	_boton_de_nueva_partida.text = TEXTO_DE_NUEVA_PARTIDA
	_boton_de_volver.text = TEXTO_DE_VOLVER
	_boton_de_nueva_partida.pressed.connect(_pedir.bind(nueva_partida_pedida))
	_boton_de_volver.pressed.connect(_pedir.bind(volver_al_menu_pedido))
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


## Un final sin pantalla no se dibuja: quien la abre ya lo decidió, y acá no se improvisa uno.
func mostrar(final: FinalConPantalla.Cual) -> void:
	if not ENCABEZADOS.has(final):
		push_error("Este final no tiene pantalla")
		return
	_encabezado.text = ENCABEZADOS[final]
	_titulo.text = TITULOS[final]
	_mensaje.text = FinalConPantalla.mensaje(final, _azar)
	_pedido = false
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func encabezado() -> String:
	return _encabezado.text


func titulo() -> String:
	return _titulo.text


func mensaje() -> String:
	return _mensaje.text


func boton_de_nueva_partida() -> Button:
	return _boton_de_nueva_partida


func boton_de_volver() -> Button:
	return _boton_de_volver


## Se sale una sola vez: pulsar dos veces, o un botón y después el otro, no pide una segunda salida.
func _pedir(salida: Signal) -> void:
	if _pedido:
		return
	_pedido = true
	salida.emit()


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
