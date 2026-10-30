## Qué mensajes condicionales del guion de Enrique eligió la partida, según cómo cerraron las
## noches de prueba (BR-EMP-040).
##
## Un `Mensaje` con `condicion` sale en las instrucciones y en el chat sólo si su condición está
## en la lista que devuelve `elegidas()`. Cada jornada que abre con un mensaje según las noches
## anteriores suma acá su tabla, en una función propia, y sus filas en el `.tres`.
class_name CondicionesDelJefe
extends RefCounted

const J2_SIN_FALLAS := &"J2_SIN_FALLAS"
const J2_REGISTRO_MAL := &"J2_REGISTRO_MAL"
const J2_REPOSICION_MAL := &"J2_REPOSICION_MAL"
const J2_UN_CLIENTE_MAL := &"J2_UN_CLIENTE_MAL"
const J2_UN_CLIENTE_Y_REPOSICION_MAL := &"J2_UN_CLIENTE_Y_REPOSICION_MAL"
const J2_UN_CLIENTE_Y_REGISTRO_MAL := &"J2_UN_CLIENTE_Y_REGISTRO_MAL"
const J2_UN_CLIENTE_Y_TODO_MAL := &"J2_UN_CLIENTE_Y_TODO_MAL"
const J2_NINGUNO_EN_CERO := &"J2_NINGUNO_EN_CERO"
const J2_NINGUNO_EN_CERO_Y_REPOSICION_MAL := &"J2_NINGUNO_EN_CERO_Y_REPOSICION_MAL"
const J2_NINGUNO_ANOTADO := &"J2_NINGUNO_ANOTADO"
const J2_NINGUNO_ANOTADO_Y_REPOSICION_MAL := &"J2_NINGUNO_ANOTADO_Y_REPOSICION_MAL"
## Por clientes mal atendidos (0, 1 o 2 o más), registro y reposición, si cada una salió bien. Con
## cero clientes mal atendidos, el registro y la reposición mal a la vez no tienen fila en la
## ficha, y manda el registro (OQ-EMP-014).
const J2_POR_RESULTADO := {
	[0, true, true]: J2_SIN_FALLAS,
	[0, false, true]: J2_REGISTRO_MAL,
	[0, false, false]: J2_REGISTRO_MAL,
	[0, true, false]: J2_REPOSICION_MAL,
	[1, true, true]: J2_UN_CLIENTE_MAL,
	[1, true, false]: J2_UN_CLIENTE_Y_REPOSICION_MAL,
	[1, false, true]: J2_UN_CLIENTE_Y_REGISTRO_MAL,
	[1, false, false]: J2_UN_CLIENTE_Y_TODO_MAL,
	[2, true, true]: J2_NINGUNO_EN_CERO,
	[2, true, false]: J2_NINGUNO_EN_CERO_Y_REPOSICION_MAL,
	[2, false, true]: J2_NINGUNO_ANOTADO,
	[2, false, false]: J2_NINGUNO_ANOTADO_Y_REPOSICION_MAL,
}
const J3_SIN_FALLAS := &"J3_SIN_FALLAS"
const J3_REDIMIDO := &"J3_REDIMIDO"
const J3_CON_ALTIBAJOS := &"J3_CON_ALTIBAJOS"

const _SEGUNDA := ReglasDeLaPartida.PRIMERA_JORNADA + 1


## Una condición por noche anotada que decide la apertura siguiente.
static func elegidas(noches: Dictionary[int, ResultadoDeLaNoche]) -> Array[StringName]:
	var condiciones: Array[StringName] = []
	if noches.has(ReglasDeLaPartida.PRIMERA_JORNADA):
		condiciones.append(_de_la_segunda(noches[ReglasDeLaPartida.PRIMERA_JORNADA]))
	if noches.has(_SEGUNDA):
		condiciones.append(_de_la_tercera(noches))
	return condiciones


## Con dos clientes sin venta, la planilla cuadra sólo con todo en 0: registrar cumplida es la
## fila «dejó todo en 0».
static func _de_la_segunda(primera: ResultadoDeLaNoche) -> StringName:
	return J2_POR_RESULTADO[[
		mini(primera.mal_atendidos, 2),
		primera.cumplio(Tarea.Tipo.REGISTRAR),
		primera.cumplio(Tarea.Tipo.REPONER),
	]]


## La prueba perdida no llega acá: la despide el legajo al cerrar la segunda. Con menos fallas que
## ese umbral y la segunda cumplida, la ficha no tiene fila y van los altibajos (OQ-EMP-011).
static func _de_la_tercera(noches: Dictionary[int, ResultadoDeLaNoche]) -> StringName:
	var fallas := 0
	for noche: ResultadoDeLaNoche in noches.values():
		fallas += noche.fallas()
	if fallas == 0:
		return J3_SIN_FALLAS
	if fallas >= Reglas.APERCIBIMIENTOS_QUE_PIERDEN_LA_PRUEBA and noches[_SEGUNDA].fallas() == 0:
		return J3_REDIMIDO
	return J3_CON_ALTIBAJOS
