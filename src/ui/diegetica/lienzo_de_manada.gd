## Lo que las pantallas de Manada comparten: el lienzo de Figma y la salida al local.
##
## Vive una sola vez porque lo usan dos pantallas. Se escala el marco entero, y no cada control,
## para conservar las proporciones del diseño sin tocar el viewport ni la cámara del juego.
class_name LienzoDeManada
extends RefCounted

const TAMANO_DEL_DISENO := Vector2(1920, 1080)
const TEXTO_DE_SALIDA := "CLIC DERECHO / VOLVER AL LOCAL"


## Escala `marco` para que el lienzo entre en `disponible`, y lo centra.
static func ajustar(marco: Control, disponible: Vector2) -> void:
	var factor := minf(disponible.x / TAMANO_DEL_DISENO.x, disponible.y / TAMANO_DEL_DISENO.y)
	marco.scale = Vector2.ONE * factor
	marco.position = (disponible - TAMANO_DEL_DISENO * factor) / 2.0
