## Qué hace el juego ante Esc y ante un cursor que se pierde: pausar, reanudar o nada.
##
## Esc pausa en cualquier momento del almacén, también con la placa del cierre en pantalla: salir
## al menú con la partida en curso pasa por la pausa. El cursor que se pierde sobre la placa, en
## cambio, no pausa: la placa lo suelta a propósito.
class_name Pausa
extends RefCounted

enum Accion { NADA, PAUSAR, REANUDAR, CERRAR_CONFIGURACIONES }


## Con configuraciones abierta desde la pausa, Esc la cierra y deja la pausa: el Esc siguiente
## reanuda.
static func ante_esc(en_pausa: bool, configuraciones_abierta: bool = false) -> Accion:
	if configuraciones_abierta:
		return Accion.CERRAR_CONFIGURACIONES
	return Accion.REANUDAR if en_pausa else Accion.PAUSAR


## Pausa sólo si el cursor estaba tomado y quedó suelto sin que el juego lo soltara. Quien pregunta
## mide los dos estados a los dos lados de la escritura del juego, así que lo que cambia en el
## medio lo cambió el navegador.
static func ante_el_cursor(
	en_pausa: bool,
	placa_en_pantalla: bool,
	tomado_antes: bool,
	tomado_ahora: bool,
	ventana_activa: bool = true
) -> Accion:
	var perdido := ventana_activa and tomado_antes and not tomado_ahora
	return Accion.PAUSAR if perdido and not en_pausa and not placa_en_pantalla else Accion.NADA
