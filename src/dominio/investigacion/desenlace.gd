class_name Desenlace
extends Resource

@export var identidad: String = ""
@export var umbral: int = 0
@export var exigencias: PackedStringArray = PackedStringArray()


func alcanzado_por(descubiertas: PackedStringArray) -> bool:
	if descubiertas.size() < umbral:
		return false
	for exigida: String in exigencias:
		if not descubiertas.has(exigida):
			return false
	return true
