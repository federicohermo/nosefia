## Encuadra el dintel cercano y el borde inferior lejano en una vista de perspectiva.
class_name EncuadreDeLaVentanilla
extends RefCounted


static func distancia(
	tamano: Vector2, profundidad: float, campo_vertical: float, aspecto: float
) -> float:
	if (
		tamano.x <= 0.0
		or tamano.y <= 0.0
		or profundidad < 0.0
		or campo_vertical <= 0.0
		or campo_vertical >= 180.0
		or aspecto <= 0.0
	):
		return 0.0
	var tangente := tan(deg_to_rad(campo_vertical) / 2.0)
	return maxf(
		tamano.y / (2.0 * tangente), tamano.x / (2.0 * tangente * aspecto) + profundidad / 2.0
	)


static func elevacion(tamano: Vector2, profundidad: float, distancia_del_marco: float) -> float:
	if tamano.y <= 0.0 or profundidad < 0.0 or distancia_del_marco <= 0.0:
		return 0.0
	return tamano.y * profundidad / (4.0 * distancia_del_marco)
