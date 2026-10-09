## Traduce el uso del cuerpo del lector al objeto que la mano sostiene.
extends StaticBody3D

const JugadorDelLocal := preload("res://src/escenas/jugador.gd")

@export var jugador: JugadorDelLocal
@export var caja: CajaRegistradora
@export var malla_del_hueco: Mesh
@export var mallas: Array[MeshInstance3D]
@export var forma: CollisionShape3D
@export var forma_del_hueco: Shape3D
@export var posicion_del_hueco := Vector3.ZERO

var _malla_del_lector: Mesh
var _forma_del_lector: Shape3D


func _ready() -> void:
	_malla_del_lector = mallas[0].mesh
	_forma_del_lector = forma.shape
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
	mallas[0].position = posicion_del_hueco if manual else Vector3.ZERO
	forma.set_deferred("shape", forma_del_hueco if manual else _forma_del_lector)
