## La cáscara de una cosa suelta del almacén: un cuerpo físico que contesta qué es.
##
## Va en `objetos/` y no en `puestos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: de esto hay N, se crean y se destruyen en juego, mientras que un puesto se instancia una
## vez y vive cableado.
##
## Es cáscara y se nota en que no hay un solo `if`: qué se puede levantar lo decide `Manos`, qué
## revela lo decide `ObjetoDelAlmacen`, y dónde queda al agarrarlo lo decide `Agarre`. Acá sólo
## viven el cuerpo físico y el `Resource` que lo describe.
class_name ObjetoAgarrable
extends RigidBody3D

## Los datos entran por el `.tres`, así que agregar un objeto nuevo al almacén es duplicar la
## escena y cambiarle este campo: no se toca código.
@export var datos: ObjetoDelAlmacen


## El contrato de «con esto se puede interactuar» es este método más el grupo del `.tscn`, y no un
## tipo, porque ninguna de las capas que lo necesitan puede nombrar el tipo: `sistemas/` no puede
## nombrar un `class_name` de `escenas/` —el gate de capas lo caza sin que haya un `preload`— y
## `dominio/` tampoco, porque esto es un `Node3D`. El nombre del método vive en
## `ReglasDeLosObjetos.METODO_INTERACTUAR` y lo afirma el test de esta escena.
func interactuar() -> ObjetoDelAlmacen:
	return datos
