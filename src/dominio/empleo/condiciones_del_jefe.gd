## Qué mensajes condicionales del guion de Enrique eligió la partida, según cómo cerraron las
## noches de prueba (BR-EMP-040).
##
## Un `Mensaje` con `condicion` sale en las instrucciones y en el chat sólo si su condición está
## en la lista que devuelve `elegidas()`. Cada jornada que abre con un mensaje según la noche
## anterior suma acá su tabla, en una función propia, y sus filas en el `.tres`.
class_name CondicionesDelJefe
extends RefCounted

const J2_SIN_FALLAS := &"J2_SIN_FALLAS"
const J2_REGISTRO_MAL := &"J2_REGISTRO_MAL"
const J2_UN_CLIENTE_MAL := &"J2_UN_CLIENTE_MAL"
const J2_NINGUNO_EN_CERO := &"J2_NINGUNO_EN_CERO"
const J2_NINGUNO_ANOTADO := &"J2_NINGUNO_ANOTADO"
## Por atención, registro y reposición, si cada una salió bien.
const J3_POR_RESULTADO := {
	[true, true, true]: &"J3_SIN_FALLAS",
	[true, true, false]: &"J3_REPOSICION_MAL",
	[true, false, true]: &"J3_REGISTRO_MAL",
	[true, false, false]: &"J3_REGISTRO_Y_REPOSICION_MAL",
	[false, true, true]: &"J3_ATENCION_MAL",
	[false, false, true]: &"J3_ATENCION_Y_REGISTRO_MAL",
	[false, true, false]: &"J3_ATENCION_Y_REPOSICION_MAL",
	[false, false, false]: &"J3_TODO_MAL",
}
const J4_SIN_FALLAS := &"J4_SIN_FALLAS"
const J4_REDIMIDO := &"J4_REDIMIDO"
const J4_CON_ALTIBAJOS := &"J4_CON_ALTIBAJOS"

const _TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA + 2


## Una condición por noche anotada que decide la apertura siguiente.
static func elegidas(noches: Dictionary[int, ResultadoDeLaNoche]) -> Array[StringName]:
	var condiciones: Array[StringName] = []
	if noches.has(ReglasDeLaPartida.PRIMERA_JORNADA):
		condiciones.append(_de_la_segunda(noches[ReglasDeLaPartida.PRIMERA_JORNADA]))
	if noches.has(ReglasDeLaPartida.PRIMERA_JORNADA + 1):
		condiciones.append(_de_la_tercera(noches[ReglasDeLaPartida.PRIMERA_JORNADA + 1]))
	if noches.has(_TERCERA):
		condiciones.append(_de_la_cuarta(noches))
	return condiciones


## Con dos clientes sin venta, la planilla cuadra sólo con todo en 0: registrar cumplida es la
## fila «dejó todo en 0». Un cliente mal atendido con registrar sin cumplir no tiene fila en la
## ficha, y manda la atención (OQ-EMP-010).
static func _de_la_segunda(primera: ResultadoDeLaNoche) -> StringName:
	var registro := primera.cumplio(Tarea.Tipo.REGISTRAR)
	if primera.mal_atendidos == 0:
		return J2_SIN_FALLAS if registro else J2_REGISTRO_MAL
	if primera.mal_atendidos == 1:
		return J2_UN_CLIENTE_MAL
	return J2_NINGUNO_EN_CERO if registro else J2_NINGUNO_ANOTADO


static func _de_la_tercera(segunda: ResultadoDeLaNoche) -> StringName:
	return J3_POR_RESULTADO[[
		segunda.mal_atendidos == 0,
		segunda.cumplio(Tarea.Tipo.REGISTRAR),
		segunda.cumplio(Tarea.Tipo.REPONER),
	]]


## La prueba perdida no llega acá: la despide el legajo al cerrar la tercera. Con menos fallas
## que ese umbral y la tercera cumplida, la ficha no tiene fila y van los altibajos (OQ-EMP-011).
static func _de_la_cuarta(noches: Dictionary[int, ResultadoDeLaNoche]) -> StringName:
	var fallas := 0
	for noche: ResultadoDeLaNoche in noches.values():
		fallas += noche.fallas()
	if fallas == 0:
		return J4_SIN_FALLAS
	if fallas >= Reglas.APERCIBIMIENTOS_QUE_PIERDEN_LA_PRUEBA and noches[_TERCERA].fallas() == 0:
		return J4_REDIMIDO
	return J4_CON_ALTIBAJOS
