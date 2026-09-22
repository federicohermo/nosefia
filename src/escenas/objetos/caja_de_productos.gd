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
var _padre_de_origen: Node = null


func _ready() -> void:
	_lugar_de_origen = transform
	_padre_de_origen = get_parent()


func interactuar() -> ObjetoDelAlmacen:
	return datos


## El dominio se resetea y los nodos no: sin esto la jornada siguiente arranca con la caja donde
## la dejó la anterior.
##
## Vuelve también de padre, y no sólo de lugar: la noche puede terminar con la caja en la mano,
## y ahí `transform` es relativo al cuerpo del jugador. Escribirlo sin despegarla la deja
## flotando pegada a él toda la noche siguiente.
func volver_a_su_lugar() -> void:
	top_level = false
	reparent(_padre_de_origen, false)
	transform = _lugar_de_origen


## Se arrastra por el piso cuando el jugador la empuja al pasar. Cuánto recibe lo dice el
## dominio; acá sólo se mueve, en horizontal y sin dar vuelta nada.
func empujar(desplazamiento: Vector3) -> void:
	var arrastre := desplazamiento * ReglasDeLosObjetos.ARRASTRE_DE_LA_CAJA
	arrastre.y = 0.0
	move_and_collide(arrastre)
