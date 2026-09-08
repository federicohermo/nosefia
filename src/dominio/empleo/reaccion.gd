## Una línea de lo que el jefe deja escrito a la mañana siguiente, como dato y no como código.
##
## Es un `Resource` para que el contenido entre en archivos y no en un `match`: cambiar lo que
## dice el jefe no debería recompilar nada ni pasar por una revisión de código.
##
## **Lleva adentro su propia clave, y eso no es redundancia.** Un `@export` de `enum` se guarda
## como **un entero pelado** —medido: abierto el `.tres`, dice `sobre = 1` y no queda rastro de
## qué valor era—, así que un archivo colgado de la fila equivocada del catálogo no da ningún
## error: da la reacción equivocada, en silencio. Con la clave adentro, el test la cruza contra
## la fila y el `.tres` mal enganchado sale en rojo.
class_name Reaccion
extends Resource

## Sobre qué habla esta línea. El orden importa: el catálogo indexa el estado de la tarea como
## un entero, así que «sin cumplir» tiene que ser el cero.
enum Sobre { TAREA_SIN_CUMPLIR, TAREA_CUMPLIDA, APERCIBIMIENTOS }

@export var sobre: Sobre = Sobre.TAREA_SIN_CUMPLIR

## La otra mitad de la clave: el `Tarea.Tipo` cuando habla de una tarea, y cuántos
## apercibimientos cuando es el comentario general.
@export var indice: int = 0

@export var texto: String = ""
