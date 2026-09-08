## Los valores fijos de atender: cuántos compradores pasan por la ventanilla en una jornada.
##
## Es un archivo aparte de `reglas.gd` por el mismo criterio que separa a los otros `reglas_de_*`
## de esta carpeta: no es de qué trata el número, es quién lo toca y probando qué. `reglas.gd` se
## toca discutiendo cuánto dura la noche; esto, probando si atender interrumpe lo suficiente.
class_name ReglasDeLaVentanilla
extends RefCounted

## Cuántos compradores hay que atender por jornada.
##
## **Dos, y sale del GDD**: «no más de dos compradores por día». Con uno solo atender sería un
## viaje y no tendría con qué interrumpir la investigación dos veces, que es lo que lo mete en la
## resta de la tensión central.
##
## Vive acá y no en `tarea_de_atender.gd` a propósito: la tarea **recibe** la lista y no sabe
## cuántos son, así que un test se arma con uno o con tres sin que mover este número rompa nada.
const COMPRADORES_POR_JORNADA := 2
