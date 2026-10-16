## La bolsa visible pertenece al tacho hasta que el recolector entrega su cuerpo.
extends StaticBody3D

const BolsaDeBasura := preload("res://src/escenas/objetos/bolsa_de_basura.gd")
const ANGULO_ABIERTA := deg_to_rad(105.0)

@export var tacho: TareaDeLaBasura.Tacho
@export var mallas: Array[MeshInstance3D] = []

## La bisagra viene del modelo, al lado del cuerpo del tacho. La tapa no tiene.
var _bisagra: Node3D
var _cerrada: Transform3D


func _ready() -> void:
	_bisagra = get_parent().find_child("*bisagra*", false, false) as Node3D
	if _bisagra != null:
		_cerrada = _bisagra.transform


## El izquierdo se consume acá, para no soltar genéricamente lo que se lleva.
func interactuar() -> ObjetoDelAlmacen:
	return null


func mostrar(bolsa: BolsaDeBasura, con_bolsa: bool) -> void:
	bolsa.visible = con_bolsa
	bolsa.en_el_tacho(con_bolsa)
	abrir(con_bolsa)


## Con la bolsa adentro la tapa queda abierta y la basura desborda.
func abrir(abierta: bool) -> void:
	if _bisagra == null:
		return
	var giro := -ANGULO_ABIERTA if abierta else 0.0
	_bisagra.transform = _cerrada * Transform3D(Basis(Vector3.RIGHT, giro), Vector3.ZERO)


## Lo que dice el tacho, con bolsa o sin ella: examinarlo no la mira ni la saca.
func texto_al_examinar() -> String:
	return SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.id_del_tacho(tacho))
