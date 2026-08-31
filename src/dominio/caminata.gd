## El vector de entrada normalizado y rotado por el yaw.
##
## Las dos funciones son estáticas porque la caminata no tiene estado: es una cuenta sobre lo
## que se está apretando ahora. Guardarla en una instancia sería inventar un estado que después
## hay que acordarse de limpiar.
class_name Caminata
extends RefCounted


## `entrada.x` es la derecha y `entrada.y` el adelante, que es la convención de
## `Input.get_vector` — quien traduce el `Input` es `src/escenas/jugador.gd`, y acá llega ya
## traducido a dos números.
static func direccion(entrada: Vector2, yaw: float) -> Vector3:
	# `normalized()` es lo que hace que la diagonal no camine más rápido, que es el bug clásico
	# del controlador de primera persona y no se nota jugando hasta que alguien lo aprovecha.
	# Con el vector nulo Godot devuelve `(0, 0, 0)` y no `NAN`: está medido, así que no hace
	# falta un caso especial.
	return Vector3(entrada.x, 0.0, -entrada.y).normalized().rotated(Vector3.UP, yaw)


## El adelante gira con la mirada, que es lo que hace que caminar sea en primera persona y no en
## un sistema de coordenadas fijo.
static func velocidad(entrada: Vector2, yaw: float, velocidad_maxima: float) -> Vector3:
	return direccion(entrada, yaw) * velocidad_maxima
