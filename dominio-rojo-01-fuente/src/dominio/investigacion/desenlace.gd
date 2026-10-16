class_name Desenlace
extends Resource

@export var identidad: String = ""
@export var umbral: int = 0
@export var exigencias: PackedStringArray = PackedStringArray()


func alcanzado_por(_descubiertas: PackedStringArray) -> bool:
	return false
