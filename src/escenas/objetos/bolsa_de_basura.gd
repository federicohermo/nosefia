## Modelo provisorio: en el tacho es basura que desborda; en la mano o en el piso, una bolsa
## cerrada.
extends ObjetoAgarrable

@onready var _desborde: Node3D = $Desborde
@onready var _cerrada: Node3D = $Cerrada


func en_el_tacho(adentro: bool) -> void:
	_desborde.visible = adentro
	_cerrada.visible = not adentro
