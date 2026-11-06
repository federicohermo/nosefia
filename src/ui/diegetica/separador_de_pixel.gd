## Una línea punteada que mide un píxel de pantalla y ocupa una fila entera de píxeles.
##
## Con el lienzo escalado, una línea de 1 de alto mide menos de un píxel, o cae en el borde entre
## dos filas, y el motor no la pinta. Se calza sola cada vez que cambia su posición en pantalla,
## también cuando la lista se desplaza. Baja su borde inferior a la fila entera de abajo, así que
## nunca sale del renglón que la contiene.
##
## Se calza siempre desde el borde inferior que se le pidió con `colocar`, no desde donde quedó la
## última vez: si no, cada desplazamiento sumaría su redondeo y la línea subiría hasta cruzar el
## texto de la opción.
class_name SeparadorDePixel
extends TextureRect

const LINEA := preload("res://assets/ui/manada/ticket_linea.svg")
const ANCHO := 344.0
const ALTO := 1.0
const TOLERANCIA := 0.001

var _fondo_pedido := ALTO


func _init() -> void:
	texture = LINEA
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(ANCHO, ALTO)
	set_notify_transform(true)


## La esquina de arriba a la izquierda de una línea de un píxel, sin calzar.
func colocar(esquina: Vector2) -> void:
	_fondo_pedido = esquina.y + ALTO
	position = esquina


func _notification(que: int) -> void:
	if que == NOTIFICATION_TRANSFORM_CHANGED:
		_calzar()


func _calzar() -> void:
	var en_pantalla := get_global_transform_with_canvas()
	var escala := en_pantalla.get_scale().y
	if is_zero_approx(escala):
		return
	var fondo_pedido := en_pantalla.origin.y + (_fondo_pedido - position.y) * escala
	var desvio := floorf(fondo_pedido + TOLERANCIA) - fondo_pedido
	var alto := ALTO / escala
	var fondo_local := _fondo_pedido + desvio / escala
	if is_equal_approx(size.y, alto) and is_equal_approx(position.y, fondo_local - alto):
		return
	size.y = alto
	position.y = fondo_local - alto
