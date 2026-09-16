## Copia a la escena lo que `Iluminacion` ya resolvió.
##
## **Traduce y no decide.** Qué luminaria corresponde apagar es una regla del juego y vive en
## `dominio/`; acá sólo se convierte un `bool` por luminaria en `visible`. Si en este archivo
## aparece una tarea o una jornada, la regla se subió de capa.
##
## Lo que se apaga es el **grupo** y no una luz suelta: una luminaria del almacén es una tira de
## 15,7 m, y ninguna luz de Godot alumbra una línea. Son varios focos y se prenden juntos, así que
## el nodo cuelga de un `Node3D` por tira y apaga el padre.
##
## El emparejamiento es **por posición**: el grupo `n` es la luminaria `n` del dominio. Es lo que
## permite que el dominio no nombre un solo nodo del motor.
class_name LucesDelAlmacen
extends Node

## Un nodo por tira del salón, en el orden en que el dominio las cuenta.
@export var luminarias: Array[Node3D] = []

## El estado que se copia. Se crea entero encendido, que es el local abierto.
var iluminacion := Iluminacion.new()


func _ready() -> void:
	aplicar()


## Deja visible cada tira cuya luminaria está encendida.
func aplicar() -> void:
	for indice in luminarias.size():
		luminarias[indice].visible = iluminacion.esta_encendida(indice)
