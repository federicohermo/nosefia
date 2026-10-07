## El cuerpo permite accionar la misma tapa sin tener que apuntar a la hoja abierta.
extends StaticBody3D

const TapaDelLocal := preload("res://src/escenas/puestos/tapa_del_contenedor.gd")

@export var tapa: TapaDelLocal
@export var mallas: Array[MeshInstance3D] = []


func usar() -> void:
	tapa.usar()
