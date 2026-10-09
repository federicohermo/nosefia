## Convierte un punto mundial al espacio local de las habitaciones declaradas.
extends Node3D

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")

@export var local: Array[AABB] = []
@export var deposito: Array[AABB] = []
@export var bano: Array[AABB] = []


func de(punto_mundial: Vector3) -> ReglasDelCierre.Habitacion:
	return ReglasDelCierre.habitacion_de(to_local(punto_mundial), local, deposito, bano)
