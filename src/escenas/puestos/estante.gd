## El estante que se ve: pregunta y pinta.
##
## **Cuánto le entra a la góndola no está escrito acá.** Los huecos los dibuja la escena, y
## cuántos se ven sale de lo que el dominio contesta: una cuenta propia acá dejaría al estante y
## al `Inventario` contradiciéndose en silencio, y está medido que una regla copiada en esta capa
## pasa los dos gates en verde.
##
## **Avisa hacia arriba en vez de llamar a nadie**: una señal sin escuchas no hace nada, mientras
## que una llamada a un `@export` sin cablear muere en el primer cuadro con un
## `Nonexistent function … in base 'Nil'` que no nombra ni al `.tscn` ni al `@export`.
##
## Va en `puestos/` y no en `objetos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: de esto hay una y vive cableada, mientras que de las cosas sueltas hay N.
##
## No declara un nombre global a propósito: es cáscara, nadie la nombra desde abajo, y el `.tscn`
## que la usa la trae con su script puesto.
extends StaticBody3D

signal colocacion_pedida

@export var mallas: Array[MeshInstance3D] = []
@export var _huecos: Node3D


## El contrato de «con esto se puede interactuar» es este método más el grupo del `.tscn`.
##
## Devuelve `null` porque del estante no se levanta nada: lo que pasa acá es que una unidad se
## coloca, y quién puede colocarla lo contesta `Estante`, que es de `dominio/` y tiene test.
func interactuar() -> ObjetoDelAlmacen:
	colocacion_pedida.emit()
	return null


## Deja visible un hueco por cada producto que ya llegó a su cupo.
##
## Recibe el número en vez de ir a buscarlo: el estante de la escena no es dueño de nada, y quien
## sabe cuántos hay repuestos es `Estante`. Es lo que lo deja dibujarse sin conocer al inventario.
func mostrar(completos: int) -> void:
	var huecos := _huecos.get_children()
	for indice in range(huecos.size()):
		var hueco: Node3D = huecos[indice]
		hueco.visible = indice < completos
