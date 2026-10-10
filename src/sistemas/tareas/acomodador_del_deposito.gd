class_name AcomodadorDelDeposito
extends Node

@export var reloj: RelojDelTurno


func revisar(estados: Array[OrdenDelDeposito.Estado]) -> void:
	var tarea := reloj.obligatoria(Tarea.Tipo.ORDENAR_LAS_CAJAS)
	if OrdenDelDeposito.ordenadas(estados):
		reloj.completar(tarea)
	else:
		reloj.descumplir(tarea)
