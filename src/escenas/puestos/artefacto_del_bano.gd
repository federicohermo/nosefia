## Un artefacto del baño —el lavatorio o el inodoro—: no se levanta, y recibe el balde.
##
## Es cáscara: dice qué es para limpiar y qué se marca al enfocarlo. Qué pasa al usar el balde
## sobre él lo decide `PisoDelLocal`.
##
## **No tiene `interactuar()`, y es a propósito.** El clic izquierdo no es suyo: con algo en la
## mano ese clic lo suelta, y con la mano vacía se rechaza por no levantable. Al grupo
## `interactuable` sí pertenece, que es lo que lo deja enfocar y recibir el clic derecho.
extends StaticBody3D

## Qué es para limpiar: el `id` con que lo nombra el dominio.
@export var destino: StringName

## Lo que se marca al enfocarlo. El cuerpo cuelga de la malla del modelo, así que sin esto el marco
## buscaría mallas entre sus hijos y no marcaría nada.
@export var mallas: Array[MeshInstance3D] = []

## Centro de la cuba sobre el desagüe, en las coordenadas del modelo importado.
@export var punto_de_enjuague := Vector3(-0.01408, 0.153435, 1.35)


func destino_del_uso() -> StringName:
	return destino


func punto_para_la_mopa() -> Vector3:
	return to_global(punto_de_enjuague)
