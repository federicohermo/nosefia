## El dibujo de un dispositivo en la pestaña de la pantalla de controles: un teclado o un mando.
## Se dibuja con formas, como `GlifoDeEntrada`.
class_name DibujoDeDispositivo
extends Control

enum Dispositivo { TECLADO, MANDO }

const COLOR_DEL_TRAZO := Color("f4e6b5")
const TAMANO := Vector2(64.0, 40.0)

var dispositivo: Dispositivo = Dispositivo.TECLADO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	return TAMANO


func _draw() -> void:
	var origen := (size - TAMANO) / 2.0
	if dispositivo == Dispositivo.TECLADO:
		_dibujar_teclado(origen)
	else:
		_dibujar_mando(origen)


func _dibujar_teclado(origen: Vector2) -> void:
	draw_rect(Rect2(origen + Vector2(1.0, 6.0), Vector2(62.0, 30.0)), COLOR_DEL_TRAZO, false, 2.0)
	for fila: int in 3:
		for columna: int in 8 - fila:
			var corrimiento := 8.0 + fila * 3.0 + columna * 6.5
			draw_rect(
				Rect2(origen + Vector2(corrimiento, 11.0 + fila * 7.0), Vector2(4.0, 4.0)),
				COLOR_DEL_TRAZO
			)


func _dibujar_mando(origen: Vector2) -> void:
	var cuerpo := PackedVector2Array(
		[
			origen + Vector2(14.0, 8.0),
			origen + Vector2(50.0, 8.0),
			origen + Vector2(62.0, 30.0),
			origen + Vector2(54.0, 36.0),
			origen + Vector2(42.0, 26.0),
			origen + Vector2(22.0, 26.0),
			origen + Vector2(10.0, 36.0),
			origen + Vector2(2.0, 30.0),
			origen + Vector2(14.0, 8.0),
		]
	)
	draw_polyline(cuerpo, COLOR_DEL_TRAZO, 2.0)
	draw_line(origen + Vector2(15.0, 14.0), origen + Vector2(15.0, 22.0), COLOR_DEL_TRAZO, 2.0)
	draw_line(origen + Vector2(11.0, 18.0), origen + Vector2(19.0, 18.0), COLOR_DEL_TRAZO, 2.0)
	for botones: Vector2 in [
		Vector2(46.0, 13.0), Vector2(46.0, 23.0), Vector2(41.0, 18.0), Vector2(51.0, 18.0)
	]:
		draw_circle(origen + botones, 2.0, COLOR_DEL_TRAZO)
