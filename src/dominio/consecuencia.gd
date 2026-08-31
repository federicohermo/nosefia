## Cuántas tareas se cumplieron al cerrar la noche, traducido a la reacción que dispara.
##
## La clase se llama `Consecuencias` y el `enum`, `Banda`, y no pueden llamarse igual: en Godot 4
## un `class_name X` con un miembro `X` adentro no compila, y el script queda sin cargar con un
## error que no nombra la causa. El archivo se sigue llamando `consecuencia.gd` en singular
## porque su espejo en el gate de tests es `test/dominio/consecuencia_test.gd`.
##
## No nombra a `Reglas` ni a `Turno`: lo único que cruza desde el turno son dos enteros, y quien
## los pasa es el llamador.
class_name Consecuencias
extends RefCounted

enum Banda { NINGUNA, AVISO, GRAVE }

## El corte entre el aviso y lo grave, en **tareas** y no en porcentaje: con 6 obligatorias y 5
## cumplidas la banda sigue siendo `AVISO`, porque falta una.
##
## Vive acá y no en `reglas.gd` por el criterio de `.claude/rules/dominio.md`, que no es de qué
## trata el número sino cuántos archivos lo necesitan: éste lo lee `consecuencia_de()` y nadie
## más. El legajo justamente **no** lo lee — pide la banda en vez de recalcularla.
const CUMPLIDAS_MINIMAS_PARA_AVISO := 3


## La banda del cierre.
##
## «Cumplió todas» es `cumplidas == obligatorias` y nunca `cumplidas == 5`: el día que aparezca
## una sexta tarea esta función no se toca. Es la misma decisión que `Turno.todas_cumplidas()`,
## y las dos tienen que decidir igual o el juego se contradice.
static func consecuencia_de(cumplidas: int, obligatorias: int) -> Banda:
	if cumplidas >= obligatorias:
		return Banda.NINGUNA
	if cumplidas >= CUMPLIDAS_MINIMAS_PARA_AVISO:
		return Banda.AVISO
	return Banda.GRAVE
