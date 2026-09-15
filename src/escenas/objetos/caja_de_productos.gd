## La caja del depósito: se lleva, se apoya, y declara qué producto guarda.
##
## No decide nada. Qué sale de ella y desde dónde lo resuelve `reposicion_manual.gd`. Su cuerpo
## es estático y no rígido: una caja se apoya, no rebota ni rueda.
extends StaticBody3D

@export var producto: Producto.Id = Producto.Id.ACTRONCITO
@export var datos: ObjetoDelAlmacen
@export var mallas: Array[MeshInstance3D] = []

## Cómo queda en la mano: de frente y mostrando su cara rotulada. La lee `Agarre` al colgarla.
@export var orientacion_en_mano := Basis.IDENTITY

var _lugar_de_origen: Transform3D


func _ready() -> void:
	_lugar_de_origen = transform


func interactuar() -> ObjetoDelAlmacen:
	return datos


## El dominio se resetea y los nodos no: sin esto la jornada siguiente arranca con la caja donde
## la dejó la anterior.
func volver_a_su_lugar() -> void:
	top_level = false
	transform = _lugar_de_origen
