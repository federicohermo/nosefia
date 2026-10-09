## Cuántos viajes hacen falta para mover las bolsas con las manos disponibles.
class_name Trayecto
extends RefCounted


static func viajes(bolsas: int, manos: int) -> int:
	if manos <= 0 or bolsas <= 0:
		return 0
	return ceili(float(bolsas) / float(manos))
