## La bolsa visible pertenece al tacho hasta que el recolector entrega su cuerpo.
extends StaticBody3D

@export var tacho: TareaDeLaBasura.Tacho
@export var mallas: Array[MeshInstance3D] = []


## El izquierdo se consume acá, para no soltar genéricamente lo que se lleva.
func interactuar() -> ObjetoDelAlmacen:
	return null


func mostrar(bolsa: Node3D, con_bolsa: bool) -> void:
	bolsa.visible = con_bolsa
