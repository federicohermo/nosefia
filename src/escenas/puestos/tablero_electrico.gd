## El tablero eléctrico del depósito: un clic sobre cualquier parte suyo pide restablecer la luz.
##
## **No decide si hay corte ni qué restablece.** Eso es de `AnomaliasDeLaJornada`; acá queda la
## traducción del clic a una señal. Con la luz puesta el clic no hace nada, y quien escucha lo
## sabe: el dominio contesta lo mismo que antes.
extends StaticBody3D

signal restablecimiento_pedido

## Las mallas que el marco del objetivo pinta al enfocar.
@export var mallas: Array[MeshInstance3D] = []


func accionar() -> void:
	restablecimiento_pedido.emit()
