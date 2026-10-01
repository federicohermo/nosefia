## La mopa: se moja de lo que tiene el balde, y con eso borra.
##
## **Mojarla no gasta el agua del balde, y borrar no la seca.** Ninguna de las dos está en la
## ficha, que lista todo lo que cambia cada paso: con una mojada de amarillo se borran las dos
## manchas de polvo de la jornada sin volver al baño, y el viaje que limpiar cuesta es el de
## cambiar de jabón.
class_name Mopa
extends RefCounted

var _agua := ReglasDeLaLimpieza.Agua.NINGUNA


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
	return ReglasDeLaLimpieza.Resultado.MOPA_MOJADA
