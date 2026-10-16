class_name Hipotesis
extends Resource

@export var identidad: String = ""
@export var jornada: int = 1
@export var titulo: String = ""
@export_multiline var texto: String = ""
@export var exigencias: PackedStringArray = PackedStringArray()


func habilitada_por(descubiertas: PackedStringArray) -> bool:
	for exigida: String in exigencias:
		if not descubiertas.has(exigida):
			return false
	return true
