## Copia a las luces de la escena lo que `Iluminacion` ya resolvió.
##
## **Traduce y no decide.** Qué luminaria corresponde apagar es una regla del juego y vive en
## `dominio/`; acá sólo se convierte un `bool` por luminaria en `visible`. Si en este archivo
## aparece una tarea o una jornada, la regla se subió de capa.
##
## El emparejamiento es **por posición**: la luz `n` de `luces` es la luminaria `n` del dominio.
## Es lo que permite que el dominio no nombre un solo nodo del motor.
class_name LucesDelAlmacen
extends Node

## Las luces del salón, en el orden en que el dominio las cuenta.
@export var luces: Array[Light3D] = []

## El estado que se copia. Se crea entero encendido, que es el local abierto.
var iluminacion := Iluminacion.new()


func _ready() -> void:
	aplicar()


## Deja cada luz visible si su luminaria está encendida.
func aplicar() -> void:
	for indice in luces.size():
		luces[indice].visible = iluminacion.esta_encendida(indice)
