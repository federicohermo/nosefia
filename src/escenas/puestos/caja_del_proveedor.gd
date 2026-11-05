## Una de las dos cajas que el proveedor dejó junto al portón: la de cartón o la de madera.
##
## No se levanta ni se empuja, no suena, y se le puede apoyar encima lo levantable. Es cáscara:
## dice qué es al examinarla y deja que el marco la marque al enfocarla. Qué dice lo decide
## `SubtitulosAlExaminar`.
##
## **No tiene `interactuar()` ni `accionar()`, y es a propósito.** Al grupo `interactuable` sí
## pertenece, que es lo que la deja enfocar y examinar. Con la mano vacía el clic izquierdo se
## rechaza por no levantable, y con algo en la mano lo suelta.
extends StaticBody3D

## Cuál de las dos es: el `id` con que la nombra `SubtitulosAlExaminar`.
@export var identidad: StringName

## Lo que se marca al enfocarla.
@export var mallas: Array[MeshInstance3D] = []


func texto_al_examinar() -> String:
	return SubtitulosAlExaminar.de_lo_fijo(identidad)
