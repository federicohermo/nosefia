class_name HipotesisDeLaJornada
extends Resource

@export var jornada: int = 1
@export var opciones: Array[Hipotesis] = []
## La P: sin pistas en la jornada, y ninguna antes en la partida.
@export var predeterminada: Hipotesis = null
## La L: sin pistas en la jornada, pero con alguna en una anterior.
@export var con_antecedentes: Hipotesis = null
## Si la jornada termina sin pistas, la siguiente sortea entre las hipótesis que habría abierto.
@export var sortea_la_siguiente: bool = false


func opcion_de(identidad: String) -> Hipotesis:
	for opcion: Hipotesis in opciones:
		if opcion != null and opcion.identidad == identidad:
			return opcion
	return null


func disponibles(
	descubiertas: PackedStringArray, hay_antecedentes: bool = false
) -> Array[Hipotesis]:
	var habilitadas: Array[Hipotesis] = []
	for opcion: Hipotesis in opciones:
		if opcion != null and opcion.habilitada_por(descubiertas):
			habilitadas.append(opcion)
	var por_defecto := con_antecedentes if hay_antecedentes else predeterminada
	if habilitadas.is_empty() and por_defecto != null:
		habilitadas.append(por_defecto)
	return habilitadas
