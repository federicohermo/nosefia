## Qué dice el jefe en cada celda: una tabla de claves a archivos, y nada más.
##
## **No decide: indexa.** No hay una sola condición acá adentro, y es a propósito — el día que
## haga falta una, lo que falta es una fila. Una decisión escrita en el catálogo sería la regla
## del juego repartida entre la tabla y el código que la lee.
##
## El estado de la tarea se traduce con una tabla de dos entradas en vez de una condición, y el
## tope se satura con `clampi()`: las dos son la misma decisión, que es no volver a decidir acá
## lo que ya está decidido en `reglas.gd`.
class_name CatalogoDeReacciones
extends RefCounted

## La celda de cada tarea con la obligatoria sin hacer. La clave es el `Tarea.Tipo`, y cada
## archivo la vuelve a decir adentro: es lo que deja al test cruzarlas y cazar una fila movida.
const SIN_CUMPLIR := {
	Tarea.Tipo.CAJA: preload("res://assets/reacciones/caja_pendiente.tres"),
	Tarea.Tipo.REPONER: preload("res://assets/reacciones/reponer_pendiente.tres"),
	Tarea.Tipo.REGISTRAR: preload("res://assets/reacciones/registrar_pendiente.tres"),
	Tarea.Tipo.LIMPIAR: preload("res://assets/reacciones/limpiar_pendiente.tres"),
	Tarea.Tipo.SACAR_LA_BASURA: preload("res://assets/reacciones/basura_pendiente.tres"),
}

const CUMPLIDA := {
	Tarea.Tipo.CAJA: preload("res://assets/reacciones/caja_cumplida.tres"),
	Tarea.Tipo.REPONER: preload("res://assets/reacciones/reponer_cumplida.tres"),
	Tarea.Tipo.REGISTRAR: preload("res://assets/reacciones/registrar_cumplida.tres"),
	Tarea.Tipo.LIMPIAR: preload("res://assets/reacciones/limpiar_cumplida.tres"),
	Tarea.Tipo.SACAR_LA_BASURA: preload("res://assets/reacciones/basura_cumplida.tres"),
}

## El estado de la tarea, indexado como un entero. `int(false)` es cero, así que el orden de
## estas dos entradas es el que le da sentido a `Reaccion.Sobre`.
const SEGUN_EL_ESTADO := [SIN_CUMPLIR, CUMPLIDA]

## El comentario general, indexado por apercibimientos. Va de cero al tope inclusive: «cero
## apercibimientos» y «cumplió las cinco» son el mismo estado, no dos filas.
const POR_APERCIBIMIENTOS := [
	preload("res://assets/reacciones/apercibimientos_0.tres"),
	preload("res://assets/reacciones/apercibimientos_1.tres"),
	preload("res://assets/reacciones/apercibimientos_2.tres"),
	preload("res://assets/reacciones/apercibimientos_3.tres"),
	preload("res://assets/reacciones/apercibimientos_4.tres"),
]


## Lo que el jefe dice de una obligatoria según cómo quedó.
static func de_la_tarea(tipo: Tarea.Tipo, cumplida: bool) -> Reaccion:
	return SEGUN_EL_ESTADO[int(cumplida)][tipo]


## El comentario general, **saturado en el tope**.
##
## Satura porque una jornada grave sube de a dos: con tres apercibimientos encima, una noche
## mala deja cinco y el contador pasa el tope sin pisarlo. Sin `clampi()` la placa del despido
## saldría vacía justo el día que importa.
static func del_comentario(apercibimientos: int) -> Reaccion:
	return POR_APERCIBIMIENTOS[clampi(apercibimientos, 0, Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO)]
