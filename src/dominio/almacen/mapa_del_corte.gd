## Cuándo se baja el mapa de la noche del corte, que en la web viaja en su propio paquete.
##
## El local tiene dos horneados: el de siempre y el de la noche sin luz. El segundo pesa más que
## todo lo demás que la noche necesita junto, así que se baja aparte y sólo cuando la partida sabe
## que lo va a usar. **Esta es la regla**: cuándo hace falta, cuándo la oscuridad tiene que
## esperarlo y cuánto se espera entre intentos. De la red y de los paquetes se ocupa el sistema
## que la ejecuta.
##
## **La noche del corte no se rompe nunca.** Sin el mapa, el local se quedaría sin horneado: la
## oscuridad no se aplica hasta que esté, y mientras falta el juego espera.
class_name MapaDelCorte
extends RefCounted

enum Estado {
	## Ya está: vino con el juego o se montó su paquete.
	LISTO,
	## Hace falta y todavía no se pidió.
	ESPERANDO,
	## Hay un pedido en curso.
	PIDIENDO,
	## El último intento no llegó: se espera antes de volver a pedir.
	FALLO,
}

## Cuánto crece la espera con cada intento fallido, y el piso de la primera.
const CRECIMIENTO_DE_LA_ESPERA := 2.0
const ESPERA_MINIMA := 1.0

var _estado: Estado
var _fallos := 0


func _init(ya_esta: bool = false) -> void:
	_estado = Estado.LISTO if ya_esta else Estado.ESPERANDO


## Si esta jornada lo va a necesitar y todavía no lo tiene.
func hace_falta(jornada: int) -> bool:
	if _estado == Estado.LISTO:
		return false
	return jornada == AnomaliasDeLaJornada.JORNADA_DEL_CORTE


func listo() -> bool:
	return _estado == Estado.LISTO


func estado() -> Estado:
	return _estado


## Si la oscuridad tiene que esperar: sin el mapa, el local se queda sin horneado.
func la_oscuridad_espera() -> bool:
	return _estado != Estado.LISTO


## Cuánto se espera antes del próximo intento. Crece con los fallos.
func espera_para_reintentar() -> float:
	return ESPERA_MINIMA * pow(CRECIMIENTO_DE_LA_ESPERA, float(maxi(_fallos - 1, 0)))


## Pide el mapa. Devuelve si arrancó un pedido: con uno en curso no se pide otro.
func empezar() -> bool:
	if _estado == Estado.LISTO or _estado == Estado.PIDIENDO:
		return false
	_estado = Estado.PIDIENDO
	return true


## Llegó y se montó.
func terminar() -> void:
	_estado = Estado.LISTO
	_fallos = 0


## El intento no llegó. Cuenta un fallo y arranca la espera.
func fallar() -> void:
	_fallos += 1
	_estado = Estado.FALLO


## Si ya pasó la espera del último fallo.
func toca_reintentar(transcurrido: float) -> bool:
	return _estado == Estado.FALLO and transcurrido >= espera_para_reintentar()
