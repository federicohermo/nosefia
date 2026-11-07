## El epílogo de un final en pantalla: la placa con su fondo, su texto y «SIGUIENTE», y el negro de
## los fundidos (BR-SHF-072 a BR-SHF-074). Dibuja lo que `RecorridoDelEpilogo` decide: cuál placa y
## cuánto negro.
##
## `terminado` avisa con la pantalla del todo negra, cuando la última placa se cerró: quien lo
## escucha pone debajo la pantalla de final, y el último fundido de entrada la descubre. La
## pantalla se libera sola al terminar ese fundido. Mientras el negro cubre algo, se queda con los
## clics; con la placa a la vista los deja pasar al botón.
class_name PantallaDeEpilogo
extends CanvasLayer

signal terminado

const TEXTO_DEL_BOTON := "SIGUIENTE"

@export var _placa: Control
@export var _fondo: TextureRect
@export var _marco: Control
@export var _lectura: TextureRect
@export var _texto: Label
@export var _boton: Button
@export var _negro: ColorRect

var _recorrido: RecorridoDelEpilogo
var _a_la_vista: EpilogosDeLosFinales.Placa = null


func _ready() -> void:
	visible = false
	set_process(false)
	_boton.text = TEXTO_DEL_BOTON
	_boton.pressed.connect(_pasar_a_la_siguiente)
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


## Empieza el recorrido: el fundido a negro sale de lo que haya en pantalla.
func mostrar(placas: Array[EpilogosDeLosFinales.Placa]) -> void:
	_recorrido = RecorridoDelEpilogo.new(placas)
	_recorrido.cerrado.connect(terminado.emit)
	_placa.visible = false
	visible = true
	set_process(true)
	_pintar()


func _process(delta: float) -> void:
	avanzar(minf(delta, CabeceraConSolapa.PASO_MAXIMO))


## El tiempo del epílogo. `_process` lo llama con el del cuadro, sin dejar que un cuadro largo se
## coma un fundido.
func avanzar(segundos: float) -> void:
	_recorrido.avanzar(segundos)
	_pintar()
	if _recorrido.terminado():
		visible = false
		set_process(false)
		queue_free()


func placa_a_la_vista() -> EpilogosDeLosFinales.Placa:
	return _a_la_vista


func boton() -> Button:
	return _boton


func negro() -> float:
	return _negro.color.a


func _pasar_a_la_siguiente() -> void:
	_recorrido.siguiente()


func _pintar() -> void:
	var placa := _recorrido.placa()
	if placa != _a_la_vista:
		_a_la_vista = placa
		_placa.visible = placa != null
		if placa != null:
			_fondo.texture = placa.fondo
			_texto.text = placa.texto
			_boton.grab_focus(true)
	var oscuridad := _recorrido.negro()
	_negro.color.a = oscuridad
	_negro.mouse_filter = (
		Control.MOUSE_FILTER_STOP if oscuridad > 0.0 else Control.MOUSE_FILTER_IGNORE
	)


## Acomoda el marco en `disponible`. La franja de lectura sale del marco hasta los dos bordes: con
## una ventana más ancha que el diseño, la sombra no se corta a los costados.
func ajustar_a(disponible: Vector2) -> void:
	LienzoDeManada.ajustar(_marco, disponible)
	_lectura.offset_left = -_marco.position.x / _marco.scale.x
	_lectura.offset_right = (disponible.x - _marco.position.x) / _marco.scale.x


func _ajustar_al_viewport() -> void:
	ajustar_a(get_viewport().get_visible_rect().size)
