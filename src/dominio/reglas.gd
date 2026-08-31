## Los valores fijos del turno, en un solo lugar.
##
## Viven acá y no adentro de `turno.gd` porque son los números que se van a tocar todas las
## semanas balanceando, y un valor que vive al lado de la lógica que lo usa termina copiado en
## el segundo lugar que lo necesita. Dos copias de un número no son dos números: son un bug
## esperando a que alguien cambie una.
##
## Son un **primer valor**, no una medición: el GDD no dice cuánto dura un turno ni cuánto
## consume cada tarea. Se ajustan jugando, y ajustarlos no debe obligar a tocar `turno.gd`.
class_name Reglas
extends RefCounted

## Ocho horas de ficción. El reloj de la escena escala esto a los minutos reales de sesión, así
## que cambiarlo cambia también cuánto dura jugar una noche.
const DURACION_DEL_TURNO := 28800.0

const COSTO_DE_LA_CAJA := 1800.0
const COSTO_DE_REPONER := 3600.0
const COSTO_DE_REGISTRAR := 2700.0
const COSTO_DE_LIMPIAR := 3600.0

## Es la más barata en manipulación y la más cara en trayecto: obliga a cruzar el almacén hasta
## el fondo, que es una zona que ninguna otra obligatoria visita.
const COSTO_DE_SACAR_LA_BASURA := 1200.0


## Cuántos segundos de turno consume hacer una tarea de este tipo.
##
## Un tipo sin costo devuelve `0.0`, y eso pone en rojo a `reglas_test.gd`: es la forma de que
## agregar un sexto valor al enum sin darle costo no pase en silencio.
static func costo_de(tipo: Tarea.Tipo) -> float:
	match tipo:
		Tarea.Tipo.CAJA:
			return COSTO_DE_LA_CAJA
		Tarea.Tipo.REPONER:
			return COSTO_DE_REPONER
		Tarea.Tipo.REGISTRAR:
			return COSTO_DE_REGISTRAR
		Tarea.Tipo.LIMPIAR:
			return COSTO_DE_LIMPIAR
		Tarea.Tipo.SACAR_LA_BASURA:
			return COSTO_DE_SACAR_LA_BASURA
	return 0.0
