## El borde de un control, de un píxel de pantalla por lado y sobre filas y columnas enteras.
##
## Con el lienzo escalado, un borde de 1 de diseño mide menos de un píxel, o cae en el límite entre
## dos filas, y el motor no lo pinta entero. Cada lado ocupa una fila o columna entera de píxeles
## adentro del control, así que el recorte del control no lo corta. Se vuelve a calzar cada vez que
## el control cambia de tamaño o de posición en pantalla.
class_name BordeDePixel
extends Control

const TOLERANCIA := 0.001

var color := Color.WHITE:
	set(valor):
		color = valor
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_notify_transform(true)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Arriba, abajo, izquierda y derecha, en las coordenadas locales.
func lados() -> Array[Rect2]:
	var en_pantalla := get_global_transform_with_canvas()
	var rectangulo := en_pantalla * Rect2(Vector2.ZERO, size)
	var izquierda := ceilf(rectangulo.position.x - TOLERANCIA)
	var arriba := ceilf(rectangulo.position.y - TOLERANCIA)
	var derecha := floorf(rectangulo.end.x + TOLERANCIA)
	var abajo := floorf(rectangulo.end.y + TOLERANCIA)
	var ancho := derecha - izquierda
	var alto := abajo - arriba
	var a_local := en_pantalla.affine_inverse()
	return [
		a_local * Rect2(izquierda, arriba, ancho, 1.0),
		a_local * Rect2(izquierda, abajo - 1.0, ancho, 1.0),
		a_local * Rect2(izquierda, arriba, 1.0, alto),
		a_local * Rect2(derecha - 1.0, arriba, 1.0, alto),
	]


func _notification(que: int) -> void:
	if que == NOTIFICATION_TRANSFORM_CHANGED or que == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	for lado in lados():
		draw_rect(lado, color)
