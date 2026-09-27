## Qué variante de una fila suena: cualquiera menos la anterior, para que no parezca un bucle.
##
## El sorteo entra por parámetro: con una semilla fija, la secuencia se puede afirmar.
class_name EleccionDeVariante
extends RefCounted


## El índice de la variante siguiente, o `-1` si no hay ninguna. Con una sola, la repite.
static func siguiente(cantidad: int, anterior: int, azar: RandomNumberGenerator) -> int:
	if cantidad <= 0:
		return -1
	if cantidad == 1 or anterior < 0 or anterior >= cantidad:
		return azar.randi_range(0, cantidad - 1)
	# Se sortea entre las otras y se saltea la anterior: un solo sorteo, sin reintentos.
	var elegida := azar.randi_range(0, cantidad - 2)
	return elegida + 1 if elegida >= anterior else elegida
