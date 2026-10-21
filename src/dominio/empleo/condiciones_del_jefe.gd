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


## Una condición por noche anotada que decide la apertura siguiente.
static func elegidas(noches: Dictionary[int, ResultadoDeLaNoche]) -> Array[StringName]:
	var condiciones: Array[StringName] = []
	if noches.has(ReglasDeLaPartida.PRIMERA_JORNADA):
		condiciones.append(_de_la_segunda(noches[ReglasDeLaPartida.PRIMERA_JORNADA]))
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
