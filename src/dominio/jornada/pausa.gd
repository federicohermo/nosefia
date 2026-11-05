## Qué hace el juego ante Esc y ante un cursor que se pierde: pausar, reanudar o nada.
##
## Esc pausa en cualquier momento del almacén, también con la devolución del cierre en pantalla:
## salir al menú con la partida en curso pasa por la pausa. El cursor que se pierde sobre la
## devolución, en cambio, no pausa: el cierre lo suelta a propósito. Las excepciones de Esc son las
## interfaces abiertas: el celular libre, la computadora, la caja y las notas. Las cierra a ellas.
class_name Pausa
extends RefCounted

enum Accion { NADA, PAUSAR, REANUDAR, CERRAR_CONFIGURACIONES, CERRAR_CELULAR, CERRAR_INTERFAZ }

## Cuánto después de un Esc que cerró una interfaz no cuenta un cursor perdido. En la web, Esc
## siempre suelta el cursor, y el aviso del navegador llega unos cuadros más tarde.
const GRACIA_TRAS_ESC := 0.5


## Con configuraciones abierta desde la pausa, Esc la cierra y deja la pausa: el Esc siguiente
## reanuda. Con el celular libre o con otra interfaz abierta, Esc la cierra a ella y no pausa.
static func ante_esc(
	en_pausa: bool,
	configuraciones_abierta: bool = false,
	celular_libre_abierto: bool = false,
	interfaz_abierta: bool = false
) -> Accion:
	if configuraciones_abierta:
		return Accion.CERRAR_CONFIGURACIONES
	if en_pausa:
		return Accion.REANUDAR
	if celular_libre_abierto:
		return Accion.CERRAR_CELULAR
	return Accion.CERRAR_INTERFAZ if interfaz_abierta else Accion.PAUSAR


## Pausa sólo si el cursor estaba tomado y quedó suelto sin que el juego lo soltara. Quien pregunta
## mide los dos estados a los dos lados de la escritura del juego, así que lo que cambia en el
## medio lo cambió el navegador. Si lo soltó el mismo Esc que cerró una interfaz, la interfaz ya
## atendió ese Esc: es `gracia_tras_esc`, y no pausa.
static func ante_el_cursor(
	en_pausa: bool,
	placa_en_pantalla: bool,
	tomado_antes: bool,
	tomado_ahora: bool,
	ventana_activa: bool = true,
	gracia_tras_esc: bool = false
) -> Accion:
	var perdido := ventana_activa and tomado_antes and not tomado_ahora and not gracia_tras_esc
	return Accion.PAUSAR if perdido and not en_pausa and not placa_en_pantalla else Accion.NADA
