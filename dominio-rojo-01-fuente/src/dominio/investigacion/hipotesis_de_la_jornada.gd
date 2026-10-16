class_name HipotesisDeLaJornada
extends Resource

@export var jornada: int = 1
@export var opciones: Array[Hipotesis] = []
@export var predeterminada: Hipotesis = null


func disponibles(_descubiertas: PackedStringArray) -> Array[Hipotesis]:
	return []
