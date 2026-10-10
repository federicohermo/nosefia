## El cuerpo permite accionar la misma tapa sin tener que apuntar a la hoja abierta.
extends StaticBody3D

const TapaDelLocal := preload("res://src/escenas/puestos/tapa_del_contenedor.gd")

@export var recolector: RecolectorDeBasura
@export var tapa: TapaDelLocal
@export var mallas: Array[MeshInstance3D] = []

var _tirados: Array[Node3D] = []


func usar() -> void:
	tapa.usar()


func interactuar() -> ObjetoDelAlmacen:
	recolector.pedir_tirar(tapa.recibe_objetos())
	return null


func recibir(nodo: Node3D) -> void:
	nodo.hide()
	if nodo is RigidBody3D:
		nodo.freeze = true
	if nodo is CollisionObject3D:
		nodo.collision_layer = 0
		nodo.collision_mask = 0
	nodo.reparent(self)
	_tirados.append(nodo)


func tirados() -> Array[Node3D]:
	return _tirados.duplicate()


func reiniciar() -> void:
	_tirados.clear()
