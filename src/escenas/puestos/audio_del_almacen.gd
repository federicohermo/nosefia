## El audio del local: trae la tabla, la reparte y ata las señales. Cáscara y nada más.
##
## **No decide nada.** Qué suena, por qué bus y con qué señal se dispara están en la tabla; a qué
## voz le toca, en la ronda; y qué señales existen se lo pregunta el enlazador al motor. Acá sólo
## se pasan las tres cosas de un lado al otro.
##
## Va en `puestos/` y no en `objetos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: hay uno solo y llega cableado, aunque no sea un puesto de trabajo en el sentido del GDD.
extends Node

## Los dos sistemas cuelgan de esta escena y entran por `@export`, no por ruta: una escena que se
## reacomoda rompe un `get_node()` sin que nada avise hasta que se corre.
@export var reproductor: ReproductorDeSonidos
@export var enlace: EnlaceDeAudio


func _ready() -> void:
	var tabla := TablaDeSonidos.desde_disco()
	reproductor.arrancar(tabla)
	enlace.arrancar(tabla)


## Ata las señales de las fuentes que le pase el cableado de la escena.
##
## Recibe la lista en vez de salir a buscarla: quién existe en el almacén lo sabe la raíz, y
## recorrer el árbol acá ataría el audio a la forma exacta de la escena.
func enlazar(fuentes: Array) -> void:
	enlace.enlazar_todo(fuentes)


## Arranca lo que va en bucle. Lo llama el cableado al abrir la jornada: ninguna señal lo dispara,
## y por eso su fila queda declarada sin fuente.
func arrancar_el_ambiente() -> void:
	reproductor.pedir(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)
