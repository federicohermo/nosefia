## Una mancha: de qué tipo es y si ya se borró.
##
## Una mancha no sabe dónde está: eso lo lleva `PisoDelLocal`. Acá vive qué la borra, y vive acá y
## no en la escena porque «qué jabón pide» es una regla del juego — escrita en la mancha que se
## dibuja daría cero hallazgos en los dos gates.
class_name Mancha
extends RefCounted

var _tipo: ReglasDeLaLimpieza.TipoDeMancha
var _limpia := false


func _init(tipo: ReglasDeLaLimpieza.TipoDeMancha) -> void:
	_tipo = tipo


func tipo() -> ReglasDeLaLimpieza.TipoDeMancha:
	return _tipo


func esta_limpia() -> bool:
	return _limpia


## El color con que se ve, que es lo que le dice al jugador qué jabón ir a buscar.
func color() -> Color:
	return ReglasDeLaLimpieza.COLOR_DE_LA_MANCHA[_tipo]


## Pasa la mopa, y devuelve cómo salió. Sólo la borra la mopa mojada del jabón que le toca.
##
## **El orden de los rechazos es el de la regla**: primero si la mancha todavía está —es una
## propiedad de la mancha, y ninguna mopa la cambia—, después lo que le falta a la mopa, del
## rechazo que más pide al que menos: mojarla, echarle jabón al balde, cambiar el jabón.
func borrar_con(mopa: Mopa) -> ReglasDeLaLimpieza.Resultado:
	if _limpia:
		return ReglasDeLaLimpieza.Resultado.YA_ESTABA_LIMPIA
	if not mopa.esta_mojada():
		return ReglasDeLaLimpieza.Resultado.MOPA_SECA
	if mopa.agua() == ReglasDeLaLimpieza.Agua.LIMPIA:
		return ReglasDeLaLimpieza.Resultado.SIN_JABON
	if mopa.agua() != ReglasDeLaLimpieza.AGUA_QUE_BORRA[_tipo]:
		return ReglasDeLaLimpieza.Resultado.JABON_EQUIVOCADO
	_limpia = true
	return ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA
