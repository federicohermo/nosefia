## Una línea punteada que mide un píxel de pantalla y ocupa una fila entera de píxeles.
##
## Con el lienzo escalado, una línea de 1 de alto mide menos de un píxel, o cae en el borde entre
## dos filas, y el motor no la pinta. Se calza sola cada vez que cambia su posición en pantalla,
## también cuando la lista se desplaza. Baja su borde inferior a la fila entera de abajo, así que
## nunca sale del renglón que la contiene.
class_name SeparadorDePixel
extends TextureRect

const LINEA := preload("res://assets/ui/manada/ticket_linea.svg")
const ANCHO := 344.0
const TOLERANCIA := 0.001


func _init() -> void:
	texture = LINEA
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(ANCHO, 1.0)
	set_notify_transform(true)


func _notification(que: int) -> void:
	if que == NOTIFICATION_TRANSFORM_CHANGED:
		_calzar()


func _calzar() -> void:
	var en_pantalla := get_global_transform_with_canvas()
	var escala := en_pantalla.get_scale().y
	if is_zero_approx(escala):
		return
	var fondo := en_pantalla.origin.y + size.y * escala
	var desvio := floorf(fondo + TOLERANCIA) - fondo
	var alto_justo := absf(size.y * escala - 1.0) <= TOLERANCIA
	if alto_justo and absf(desvio) <= TOLERANCIA:
		return
	var fondo_local := position.y + size.y + desvio / escala
	size.y = 1.0 / escala
	position.y = fondo_local - size.y
