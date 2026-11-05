## Lo que el ícono del celular del HUD le dice al jugador: cuántos mensajes nuevos hay y cuándo
## vibra. Nace retenido, porque la persiana está baja: lo que cambie mientras tanto se junta y se
## pinta recién al soltarlo.
class_name AvisoDeMensajesNuevos
extends RefCounted

## Cuánto se aleja el ícono de su lugar, en píxeles del lienzo.
const AMPLITUD_DE_LA_VIBRACION := 6.0

## Idas y vueltas por segundo.
const FRECUENCIA_DE_LA_VIBRACION := 18.0

var _total: int = 0
var _mostrado: int = 0
var _retenido: bool = true


## Cuánto dura el sonido de mensaje recibido, que es lo que dura la vibración. Sin fila o sin
## audio es cero: no vibra.
static func duracion_de_la_vibracion(tabla: TablaDeSonidos) -> float:
	var fila := tabla.alguna_de(EntradaSonora.Evento.MENSAJE_DEL_CELULAR)
	if fila == null or fila.stream == null:
		return 0.0
	return fila.stream.get_length()


## Dónde está el ícono respecto de su lugar. Pasada la duración vuelve exactamente a él.
static func desplazamiento(transcurrido: float, duracion: float) -> Vector2:
	if transcurrido <= 0.0 or transcurrido >= duracion:
		return Vector2.ZERO
	var fase := TAU * FRECUENCIA_DE_LA_VIBRACION * transcurrido
	return Vector2(AMPLITUD_DE_LA_VIBRACION * sin(fase), 0.0)


func retener() -> void:
	_retenido = true


## Devuelve si el ícono vibra: sólo cuando lo que ahora se ve supera lo que se veía.
func soltar() -> bool:
	_retenido = false
	return _mostrar(_total)


## Devuelve si el ícono vibra: sólo cuando el total sube y nada lo retiene.
func cambiar(total: int) -> bool:
	_total = maxi(0, total)
	if _retenido:
		return false
	return _mostrar(_total)


func numero() -> int:
	return _mostrado


func se_ve() -> bool:
	return _mostrado > 0


func _mostrar(total: int) -> bool:
	var sube := total > _mostrado
	_mostrado = total
	return sube
