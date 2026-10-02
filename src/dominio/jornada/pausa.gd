## Qué hace el juego ante Esc y ante un cursor que se pierde: pausar, reanudar o nada.
##
## La placa del cierre gana sobre todo: ya ofrece volver al menú, y el turno ya cerró.
class_name Pausa
extends RefCounted

enum Accion { NADA, PAUSAR, REANUDAR }


static func ante_esc(en_pausa: bool, placa_en_pantalla: bool) -> Accion:
	if placa_en_pantalla:
		return Accion.NADA
	return Accion.REANUDAR if en_pausa else Accion.PAUSAR


## Pausa sólo si el cursor estaba tomado y quedó suelto sin que el juego lo soltara. Quien pregunta
## mide los dos estados a los dos lados de la escritura del juego, así que lo que cambia en el
## medio lo cambió el navegador.
static func ante_el_cursor(
	en_pausa: bool, placa_en_pantalla: bool, tomado_antes: bool, tomado_ahora: bool
) -> Accion:
	var perdido := tomado_antes and not tomado_ahora
	return Accion.PAUSAR if perdido and not en_pausa and not placa_en_pantalla else Accion.NADA
