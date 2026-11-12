## Cuándo la página pide confirmación antes de cerrarse o recargarse: mientras corre una noche.
##
## Cerrar la pestaña a mitad de una noche pierde lo que se hizo en ella, y un atajo del navegador
## —Ctrl+W, que acá es agacharse y avanzar— la cierra sin preguntar. Entre noches, en el menú y en
## los epílogos no hay nada que perder, así que ahí no se pregunta.
##
## Recuerda qué pidió la última vez para dar la orden sólo cuando cambia: quien la ejecuta no
## tiene que repetirla cada cuadro.
class_name ConfirmacionAlSalir
extends RefCounted

enum Orden { NADA, PEDIR, DEJAR_DE_PEDIR }

var _pidiendo := false


## Lo que hay que hacer ahora, dado si la noche está en curso.
func orden(noche_en_curso: bool) -> Orden:
	if noche_en_curso == _pidiendo:
		return Orden.NADA
	_pidiendo = noche_en_curso
	return Orden.PEDIR if noche_en_curso else Orden.DEJAR_DE_PEDIR
