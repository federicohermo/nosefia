## La mopa: se moja de lo que tiene el balde, y con eso borra.
##
## La carga se pierde con el tiempo y el recorrido; remojarla la recupera sin vaciar el balde.
class_name Mopa
extends RefCounted

var _agua := ReglasDeLaLimpieza.Agua.NINGUNA
var _carga := 0.0


func carga_restante() -> float:
	return _carga


func desgastar(segundos: float, metros: float) -> void:
	_carga = maxf(
		0.0,
		(
			_carga
			- maxf(0.0, segundos) / ReglasDeLaLimpieza.DURACION_DE_LA_CARGA
			- maxf(0.0, metros) / ReglasDeLaLimpieza.RECORRIDO_DE_LA_CARGA
		)
	)
	if _carga <= 0.000001:
		_carga = 0.0
		_agua = ReglasDeLaLimpieza.Agua.NINGUNA


## De qué está mojada: `NINGUNA` si está seca.
func agua() -> ReglasDeLaLimpieza.Agua:
	return _agua


func esta_mojada() -> bool:
	return _agua != ReglasDeLaLimpieza.Agua.NINGUNA


## El color de la punta, que es el del agua que la mojó. Seca, transparente.
func color() -> Color:
	return ReglasDeLaLimpieza.COLOR_DEL_AGUA[_agua]


## La deja mojada de lo mismo que tiene el balde, aunque antes estuviera mojada de otra cosa. Un
## balde vacío no la moja ni la seca: la deja como estaba.
func mojar_en(balde: Balde) -> ReglasDeLaLimpieza.Resultado:
	if not balde.tiene_agua():
		return ReglasDeLaLimpieza.Resultado.BALDE_VACIO
	_agua = balde.agua()
	_carga = 1.0
	return ReglasDeLaLimpieza.Resultado.MOPA_MOJADA
