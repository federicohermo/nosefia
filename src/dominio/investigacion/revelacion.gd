## Lo que un objeto del almacén tiene abajo y sólo se ve examinándolo.
##
## Es un `Resource` y no un `String` suelto adentro del objeto porque se escribe en un `.tres`,
## a mano y en español, y porque el día que una revelación tenga más de un campo —de qué noche
## es, a qué otra cosa apunta— el `.tres` no cambia de forma.
##
## Vive en `investigacion/` y no en `almacen/`: la carpeta mide **cuánto rinde el minuto que no
## se paga**, y esto es exactamente lo que ese minuto compra. El objeto que la lleva sí es del
## almacén, y por eso están separados.
class_name Revelacion
extends Resource

@export_multiline var texto: String = ""


## Si esta revelación revela algo.
##
## Un texto en blanco no es una revelación vacía inofensiva: es un objeto que promete algo al
## examinarlo y contesta una línea en blanco, y el jugador acaba de pagar el minuto igual. El
## `strip_edges()` es por el `.tres` escrito a mano, donde el campo queda con un espacio o un
## salto de línea y se ve lleno en el inspector.
func dice_algo() -> bool:
	return not texto.strip_edges().is_empty()
