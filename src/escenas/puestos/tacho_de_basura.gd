## La bolsa visible pertenece al tacho hasta que el recolector entrega su cuerpo.
extends StaticBody3D

@export var tacho: TareaDeLaBasura.Tacho
@export var mallas: Array[MeshInstance3D] = []


## El izquierdo se consume acá, para no soltar genéricamente lo que se lleva.
func interactuar() -> ObjetoDelAlmacen:
	return null


func mostrar(bolsa: Node3D, con_bolsa: bool) -> void:
	bolsa.visible = con_bolsa


## Lo que dice el tacho, con bolsa o sin ella: examinarlo no la mira ni la saca.
func texto_al_examinar() -> String:
	return SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.id_del_tacho(tacho))
