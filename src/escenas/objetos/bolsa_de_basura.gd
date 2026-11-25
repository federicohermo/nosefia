## Modelo provisorio: en el tacho es basura que desborda; en la mano o en el piso, una bolsa
## cerrada.
extends ObjetoAgarrable

@onready var _desborde: Node3D = $Desborde
@onready var _cerrada: Node3D = $Cerrada


func _ready() -> void:
	super()
	oclusion.activa = not _desborde.visible


func en_el_tacho(adentro: bool) -> void:
	_desborde.visible = adentro
	_cerrada.visible = not adentro
	if oclusion != null:
		oclusion.activa = not adentro


## Lo que apoya es la bolsa cerrada: lo que desborda del tacho no toca el piso.
func _mallas_de_contacto() -> Array[MeshInstance3D]:
	return [$Cerrada/Bulto]


## El jugador la empuja al caminar contra ella.
func empujar(desplazamiento: Vector3) -> void:
	_correrse(desplazamiento)
