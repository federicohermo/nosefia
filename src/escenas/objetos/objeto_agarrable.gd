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

## Dónde lo dejó la escena. Se guarda en `_ready()` y no en la declaración porque el `transform`
## que importa es el que le puso el `.tscn`, y ése recién existe cuando el nodo entró al árbol.
var _lugar_de_origen: Transform3D


func _ready() -> void:
	_lugar_de_origen = transform


## Lo devuelve a donde empezó la noche.
##
## **El dominio se resetea y los nodos no**: al abrir la jornada el recolector vuelve a
## `depositadas() == 0`, pero las bolsas siguen físicamente adentro del `Area3D` del fondo, así
## que desde la jornada 2 sacar la basura no cuesta un paso — está hecha antes de empezar.
##
## Las velocidades van a cero además del `transform` porque un `RigidBody3D` teletransportado
## conserva su impulso y se va solo del lugar al que lo acaban de mandar. El `freeze` alrededor
## es lo que evita que el servidor de física pise la escritura en el mismo cuadro, y se restaura
## al valor que tenía en vez de apagarse: el objeto puede estar congelado porque lo están
## llevando, y despertarlo acá lo dejaría caer.
func volver_a_su_lugar() -> void:
	var estaba_congelado := freeze
	freeze = true
	transform = _lugar_de_origen
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = estaba_congelado


## El contrato de «con esto se puede interactuar» es este método más el grupo del `.tscn`, y no un
## tipo, porque ninguna de las capas que lo necesitan puede nombrar el tipo: `sistemas/` no puede
## nombrar un `class_name` de `escenas/` —el gate de capas lo caza sin que haya un `preload`— y
## `dominio/` tampoco, porque esto es un `Node3D`. El nombre del método vive en
## `ReglasDeLosObjetos.METODO_INTERACTUAR` y lo afirma el test de esta escena.
func interactuar() -> ObjetoDelAlmacen:
	return datos
