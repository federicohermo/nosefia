## El balde: se llena en el lavatorio, lo tiñe un jabón y se vacía en el inodoro.
##
## **Cambiar de jabón es vaciarlo y volver a llenarlo**, y de eso sale lo que limpiar le cuesta a
## la noche: cada tipo de mancha pide su mezcla, y cada mezcla pide un viaje al inodoro y otro a la
## canilla. Por eso llenar un balde que ya tiene agua no lava el jabón, y echarle un segundo jabón
## no cambia el color: cualquiera de los dos atajos borraría el viaje sin que nada lo dijera.
##
## Cada gesto que no hace nada contesta por qué, y ninguno cambia el balde.
class_name Balde
extends RefCounted

var _agua := ReglasDeLaLimpieza.Agua.NINGUNA


func agua() -> ReglasDeLaLimpieza.Agua:
	return _agua


func tiene_agua() -> bool:
	return _agua != ReglasDeLaLimpieza.Agua.NINGUNA


## El color del agua, que es el que el jugador lee para saber qué jabón tiene. Vacío, transparente.
func color() -> Color:
	return ReglasDeLaLimpieza.COLOR_DEL_AGUA[_agua]


func llenar() -> ReglasDeLaLimpieza.Resultado:
	if tiene_agua():
		return ReglasDeLaLimpieza.Resultado.BALDE_YA_LLENO
	_agua = ReglasDeLaLimpieza.Agua.LIMPIA
	return ReglasDeLaLimpieza.Resultado.BALDE_LLENADO


## Tiñe el agua sin jabón con la de ese jabón.
##
## Recibe el agua que deja el jabón y no su `id`: el balde no sabe qué se lleva en la mano. Algo
## que no es el agua de un jabón no tiñe: teñir de «ninguna» vaciaría el balde por la puerta de
## atrás.
func tenir(agua_del_jabon: ReglasDeLaLimpieza.Agua) -> ReglasDeLaLimpieza.Resultado:
	if not ReglasDeLaLimpieza.JABONES.values().has(agua_del_jabon):
		return ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	if not tiene_agua():
		return ReglasDeLaLimpieza.Resultado.BALDE_VACIO
	if _agua != ReglasDeLaLimpieza.Agua.LIMPIA:
		return ReglasDeLaLimpieza.Resultado.BALDE_YA_TENIDO
	_agua = agua_del_jabon
	return ReglasDeLaLimpieza.Resultado.BALDE_TENIDO


func vaciar() -> ReglasDeLaLimpieza.Resultado:
	if not tiene_agua():
		return ReglasDeLaLimpieza.Resultado.BALDE_VACIO
	_agua = ReglasDeLaLimpieza.Agua.NINGUNA
	return ReglasDeLaLimpieza.Resultado.BALDE_VACIADO
