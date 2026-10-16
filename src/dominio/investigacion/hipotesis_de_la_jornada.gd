class_name HipotesisDeLaJornada
extends Resource

@export var jornada: int = 1
@export var opciones: Array[Hipotesis] = []
@export var predeterminada: Hipotesis = null


func disponibles(descubiertas: PackedStringArray) -> Array[Hipotesis]:
	var habilitadas: Array[Hipotesis] = []
	for opcion: Hipotesis in opciones:
		if opcion != null and opcion.habilitada_por(descubiertas):
			habilitadas.append(opcion)
	if habilitadas.is_empty() and predeterminada != null:
		habilitadas.append(predeterminada)
	return habilitadas
