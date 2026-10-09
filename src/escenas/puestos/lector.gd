## Traduce el uso del cuerpo del lector al objeto que la mano sostiene.
extends StaticBody3D

const JugadorDelLocal := preload("res://src/escenas/jugador.gd")

@export var jugador: JugadorDelLocal
@export var caja: CajaRegistradora
@export var mallas: Array[MeshInstance3D]


func _ready() -> void:
	jugador.uso_pedido.connect(_al_usar)


func _al_usar(objetivo: Node3D) -> void:
	if objetivo != self:
		return
	var objeto := jugador.agarre.manos().sostenido()
	if objeto != null:
		caja.pedir_anotar(objeto)
