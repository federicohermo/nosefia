## El nodo que limpia adentro del motor: recibe cada uso, se lo pasa al dominio y publica lo que el
## dominio contestó.
##
## **Traduce, no decide.** Qué hace cada útil sobre qué, qué jabón borra cada mancha y cuándo el
## piso está limpio son preguntas de `PisoDelLocal`, que es donde tienen test. Los `match` de este
## archivo son el valor que devolvió el dominio y el estado nulo del cableado.
##
## **No lleva un flag de «ya la conté»**: le pide al reloj que complete `Tarea.Tipo.LIMPIAR` cada
## vez que el piso queda limpio, y el `Turno` ya sabe que la segunda vez no cuenta. Un flag acá
## sería esa misma regla escrita en la capa que traduce.
class_name Limpiador
extends Node

## Un gesto que cambió algo. Se llaman por lo que pasó. El audio se ata por el nombre de la señal:
## una fila de la tabla de sonidos las hace sonar sin tocar este archivo.
signal balde_llenado
signal balde_tenido(agua: ReglasDeLaLimpieza.Agua)
signal balde_vaciado
signal mopa_mojada(agua: ReglasDeLaLimpieza.Agua)

## La pasada que borra una mancha. Es la que suena con la mopa en la tabla de sonidos.
signal pasada_dada(lugar: PisoDelLocal.Lugar)

## Un uso que no hizo nada, con el motivo que contestó el dominio.
signal uso_rechazado(motivo: ReglasDeLaLimpieza.Resultado)

## Entra por `@export` y no como autoload: está medido que `gate_de_capas.py` no ve un autoload
## nombrado por su nombre global, así que esa puerta cruzaría capas sin dejar rastro.
@export var reloj: RelojDelTurno

var _piso: PisoDelLocal = null


## Le entrega al limpiador el piso de la noche.
##
## El piso se recibe y no se construye acá para que cada jornada arranque sucia, con el balde vacío
## y la mopa seca, sin que este nodo sepa qué es una jornada.
func arrancar(piso: PisoDelLocal) -> void:
	_piso = piso


func piso() -> PisoDelLocal:
	return _piso


## El reloj sigue siendo el único que descuenta tiempo de la jornada.
func desgastar_mopa(segundos: float, metros: float) -> void:
	if _piso == null or reloj == null or not reloj.corriendo():
		return
	_piso.mopa().desgastar(segundos, metros)


## Usa lo que se lleva en la mano sobre el balde, el lavatorio o el inodoro.
##
## **Devuelve exactamente lo que contestó el dominio** en vez de traducirlo a un `bool`: los
## rechazos se leen distinto adelante del jugador —«el balde está vacío», «ya tiene jabón»— y
## aplanarlos daría un solo cartel para situaciones que se resuelven distinto.
func usar(en_la_mano: StringName, objetivo: StringName) -> ReglasDeLaLimpieza.Resultado:
	if not _cableado():
		return ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	var resultado := _piso.usar(en_la_mano, objetivo)
	match resultado:
		ReglasDeLaLimpieza.Resultado.BALDE_LLENADO:
			balde_llenado.emit()
		ReglasDeLaLimpieza.Resultado.BALDE_TENIDO:
			balde_tenido.emit(_piso.balde().agua())
		ReglasDeLaLimpieza.Resultado.BALDE_VACIADO:
			balde_vaciado.emit()
		ReglasDeLaLimpieza.Resultado.MOPA_MOJADA:
			mopa_mojada.emit(_piso.mopa().agua())
		_:
			uso_rechazado.emit(resultado)
	return resultado


## Pasa lo que se lleva en la mano por la mancha de ese lugar.
func pasar(en_la_mano: StringName, lugar: PisoDelLocal.Lugar) -> ReglasDeLaLimpieza.Resultado:
	if not _cableado():
		return ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	var resultado := _piso.pasar(en_la_mano, lugar)
	if resultado != ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA:
		uso_rechazado.emit(resultado)
		return resultado
	pasada_dada.emit(lugar)
	if _piso.esta_limpio():
		reloj.completar(reloj.obligatoria(Tarea.Tipo.LIMPIAR))
	return resultado


## Un cableado incompleto es un `.tscn` mal armado y no un rechazo del juego: sale por el panel de
## depuración, que es donde se lee.
func _cableado() -> bool:
	if _piso == null or reloj == null:
		push_error("Limpiador sin cablear: revisar almacen.tscn y almacen.gd")
		return false
	return true
