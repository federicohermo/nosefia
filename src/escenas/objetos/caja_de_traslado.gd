## La caja que se ve: pregunta y pinta.
##
## **Cuántos casilleros hay no está escrito acá.** Los dibuja la escena, y cuántos se ven sale de
## lo que el dominio contesta: una cuenta propia acá dejaría la caja y `CajaDeTraslado`
## contradiciéndose en silencio, y está medido que un cupo copiado en esta capa pasa los dos
## gates en verde.
##
## No declara un nombre global a propósito: es cáscara, nadie la nombra desde abajo, y el `.tscn`
## que la usa la trae con su script puesto.
extends Node3D

@export var _casilleros: Node3D


## Deja visibles tantos casilleros como productos haya adentro.
##
## Recibe el contenido en vez de ir a buscarlo: la caja de la escena no es dueña de nada, y quien
## la carga es `CargaDeLaCaja`. Es lo que la deja dibujarse sin conocer al nodo que la llena.
func mostrar(contenido: Array[Producto]) -> void:
	var casilleros := _casilleros.get_children()
	for indice in range(casilleros.size()):
		var casillero: Node3D = casilleros[indice]
		casillero.visible = indice < contenido.size()
