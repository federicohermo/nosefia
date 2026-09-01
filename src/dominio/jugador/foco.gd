## Qué está enfocando la mira, y —lo que importa— cuándo eso cambió.
##
## Existe por una medición: el rayo se lee en `_physics_process` y `physics_ticks_per_second`
## vale 60 en este proyecto, así que una señal por lectura son 60 emisiones por segundo mirando
## fijo una estantería. `observar()` devuelve si hubo cambio, y la señal sale sólo ahí.
class_name Foco
extends RefCounted

## Sirve de centinela porque el `get_instance_id()` de un `Node` real nunca es cero: medido,
## `26558334344`.
const SIN_OBJETIVO := 0

## El objetivo se guarda como `int` —el `get_instance_id()` del cuerpo— y no como nodo. No es
## una preferencia: declarar `var objetivo: Estanteria` pondría en rojo el gate de capas por
## `src/dominio → src/escenas` sin que haya un solo `preload`. Un `int` no conoce a nadie.
var _objetivo: int = SIN_OBJETIVO
var _distancia: float = 0.0
var _hay_interactuable: bool = false


## Devuelve si cambió qué se está mirando, y ése es todo el valor de esta pieza.
func observar(id: int, distancia: float, interactuable: bool) -> bool:
	# Los dos motivos de cambio son la identidad y la interactuabilidad. Que la distancia cambie
	# mientras el jugador camina hacia el mismo objeto NO es un cambio: es justamente lo que
	# pasa sesenta veces por segundo y lo que esta pieza existe para no avisar.
	var cambio := id != _objetivo or interactuable != _hay_interactuable
	_objetivo = id
	_distancia = distancia
	_hay_interactuable = interactuable
	return cambio


func objetivo() -> int:
	return _objetivo


func distancia() -> float:
	return _distancia


func hay_interactuable() -> bool:
	return _hay_interactuable
