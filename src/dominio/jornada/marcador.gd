## Los números del turno, ya formateados.
##
## **La frontera con quien dibuja se dice en una línea: acá viven los números, allá las
## palabras.** `"20:00"` y `"3/4"` son números formateados; «Apercibimientos» es de arriba.
##
## Con la hora fuera del HUD, `hora()` tiene un solo cliente, el reloj de mesa del dominio, que
## decide si esta noche se puede leer. La aritmética está acá y no en el nodo que pinta porque es
## **una regla que decide**, y una regla en `escenas/` nace sin test: es la trampa que describe
## `.claude/rules/presentacion.md`.
class_name Marcador
extends RefCounted

const SEGUNDOS_POR_MINUTO := 60
const MINUTOS_POR_HORA := 60
const HORAS_POR_DIA := 24

## La hora de la noche, en `HH:MM` de 24 horas: la apertura más lo que ya se gastó del turno.
##
## **Trunca al minuto y no redondea**: mostrar `20:01` cuando todavía no pasó un minuto entero es
## adelantarle la hora al jugador. Y lo gastado se acota al turno entero: con el turno en cero o
## por debajo se lee la hora de cierre, nunca una pasada del cierre.
@warning_ignore("integer_division")
static func hora(restante: float) -> String:
	var turno := Reglas.DURACION_DEL_TURNO
	var transcurrido := int(turno - clampf(restante, 0.0, turno))
	var minutos := transcurrido / SEGUNDOS_POR_MINUTO
	var horas := (Reglas.HORA_DE_APERTURA + minutos / MINUTOS_POR_HORA) % HORAS_POR_DIA
	return "%02d:%02d" % [horas, minutos % MINUTOS_POR_HORA]


## Cuántas obligatorias van sobre cuántas se declararon.
##
## La cantidad declarada entra por argumento y nunca está escrita acá: cuántas obligatorias pide
## una jornada lo decide quien arma la lista, y este archivo no lo vuelve a decidir. Hoy son las
## cinco de `Tarea.Tipo`; una sexta no toca esta función.
static func tareas(cumplidas: int, obligatorias: int) -> String:
	return "%d/%d" % [cumplidas, obligatorias]
