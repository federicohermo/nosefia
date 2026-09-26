## El audio del local: trae la tabla, la reparte y ata las señales. Cáscara y nada más.
##
## Va en `puestos/` y no en `objetos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: hay uno solo y llega cableado, aunque no sea un puesto de trabajo en el sentido del GDD.
extends Node

## Los dos sistemas cuelgan de esta escena y entran por `@export`, no por ruta: una escena que se
## reacomoda rompe un `get_node()` sin que nada avise hasta que se corre.
@export var reproductor: ReproductorDeSonidos
@export var enlace: EnlaceDeAudio

## Los emisores fijos, en coordenadas del local: un hijo por nombre de emisor de la tabla.
@export var emisores: Node3D


func _ready() -> void:
	var tabla := TablaDeSonidos.desde_disco()
	reproductor.arrancar(tabla)
	reproductor.registrar_emisores(emisores)
	enlace.arrancar(tabla)


## Ata las señales de las fuentes que le pase el cableado de la escena.
##
## Recibe la lista en vez de salir a buscarla: quién existe en el almacén lo sabe la raíz, y
## recorrer el árbol acá ataría el audio a la forma exacta de la escena.
func enlazar(fuentes: Array) -> void:
	enlace.enlazar_todo(fuentes)


## Arranca lo que va en bucle: el ambiente y la música. Lo llama el cableado al abrir la
## jornada: ninguna señal lo dispara, y por eso sus filas quedan declaradas sin fuente. Lo que ya
## suena no empieza de nuevo.
func arrancar_el_ambiente() -> void:
	reproductor.pedir(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)
	reproductor.pedir(EntradaSonora.Evento.MUSICA_DE_LA_NOCHE)


## La música corta al cerrar la jornada. El ambiente sigue: el local no se apaga.
func callar_la_musica() -> void:
	reproductor.callar(EntradaSonora.Evento.MUSICA_DE_LA_NOCHE)
