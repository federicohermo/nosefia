## Cuáles emisores del ambiente suenan: los más cercanos al jugador, hasta el tope.
##
## El tope existe porque el ambiente sale de muchos lugares a la vez, y sonarlos todos sumaría
## un zumbido que no es sutil.
class_name EmisoresDelAmbiente
extends RefCounted

## Cuántos emisores suenan a la vez. Primer valor: ver OQ-AMB-005.
const TOPE := 3

## El volumen de cada emisor, en dB. Primer valor: ver OQ-AMB-004.
const VOLUMEN_DB := -12.0

## A cuántos metros un emisor deja de oírse. Primer valor: ver OQ-AMB-006.
const ALCANCE := 10.0


## Los índices de las distancias que suenan, en orden. Un empate lo gana el índice menor, para
## que dos emisores a la misma distancia no se alternen entre cuadros.
static func que_suenan(distancias: Array, tope: int) -> Array[int]:
	var indices: Array[int] = []
	for indice in range(distancias.size()):
		indices.append(indice)
	indices.sort_custom(
		func(a: int, b: int) -> bool:
			if distancias[a] == distancias[b]:
				return a < b
			return distancias[a] < distancias[b]
	)
	var suenan := indices.slice(0, maxi(tope, 0))
	suenan.sort()
	return suenan
