## Traduce el uso del cuerpo del lector al objeto que la mano sostiene.
extends StaticBody3D

const JugadorDelLocal := preload("res://src/escenas/jugador.gd")

@export var jugador: JugadorDelLocal
@export var caja: CajaRegistradora
@export var malla_del_hueco: Mesh
@export var mallas: Array[MeshInstance3D]

var _malla_del_lector: Mesh


func _ready() -> void:
	_malla_del_lector = mallas[0].mesh
	caja.programa_arrancado.connect(_mostrar_modo)
	jugador.uso_pedido.connect(_al_usar)


func _al_usar(objetivo: Node3D) -> void:
	if objetivo != self:
		return
	var objeto := jugador.agarre.manos().sostenido()
	if objeto != null:
		caja.pedir_anotar(objeto)


func _mostrar_modo(manual: bool) -> void:
	mallas[0].mesh = malla_del_hueco if manual else _malla_del_lector
