## Conecta el uso sobre una mancha con el limpiador.
extends Node3D

## El script del jugador se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name`.
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")
const ManchaQueSeVe := preload("res://src/escenas/objetos/mancha_en_el_piso.gd")

@export var jugador: JugadorDelLocal
@export var limpiador: Limpiador


func _ready() -> void:
	jugador.uso_pedido.connect(_al_pedir_uso)
	limpiador.pasada_dada.connect(_al_dar_una_pasada)
	# **No se repinta acá.** El `_ready()` de un hijo corre ANTES que el de la raíz, así que el
	# limpiador todavía no tiene piso y `repintar()` moriría con un `Nonexistent function … in
	# base 'Nil'` que no nombra ni a este archivo ni al orden. Quien repinta es el cableado, al
	# abrir la jornada.


## Deja las cuatro manchas como las ve el dominio. Lo llama el cableado al abrir la jornada.
func repintar() -> void:
	for mancha in manchas():
		mancha.mostrar(
			limpiador.piso().pasadas_restantes(mancha.zona_de_la_mancha()),
			ReglasDeLaLimpieza.PASADAS_POR_MANCHA
		)


## Las manchas que cuelgan de este puesto, en el orden del `.tscn`.
func manchas() -> Array[ManchaQueSeVe]:
	var encontradas: Array[ManchaQueSeVe] = []
	for hijo in get_children():
		var mancha := hijo as ManchaQueSeVe
		if mancha == null:
			continue
		encontradas.append(mancha)
	return encontradas


func _al_pedir_uso(objetivo: Node3D) -> void:
	var mancha := objetivo as ManchaQueSeVe
	if mancha != null:
		limpiador.pedir_pasada(mancha.zona_de_la_mancha(), jugador.id_en_la_mano())


func _al_dar_una_pasada(_zona: PisoDelLocal.Zona, _restantes: int) -> void:
	repintar()
