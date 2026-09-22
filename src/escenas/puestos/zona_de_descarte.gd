## La zona del fondo donde va la basura: **mide una distancia y llama hacia abajo**.
##
## **No lleva una sola regla.** Cuántas bolsas hay, qué cuenta como basura, si la bolsa entró y
## cuándo la obligatoria se cumple son todas de `dominio/`. Está medido que escritas acá dan
## `sin hallazgos` en `capas` **y** en `tdd`: nacerían sin test y en verde.
##
## **No declara un nombre global a propósito.** Nadie la nombra desde abajo, y no tenerlo cierra
## la única puerta que el gate de capas sí caza — que `sistemas/` nombre un tipo de `escenas/`. El
## nombre de esa declaración no se escribe acá ni en un comentario: el caso que lo verifica no
## distingue código de prosa.
##
## **El radio del `.tscn` es un reflejo de la constante, no su fuente.** Un `.tscn` no puede leer
## un `const`, así que el número está escrito dos veces y hay un caso que los compara: sin él, la
## esfera y la regla se separan y el jugador suelta la bolsa donde el juego dice que no cuenta.
extends Area3D

@export var recolector: RecolectorDeBasura

## La esfera que se ve como zona. Se expone su radio para que un caso lo pueda comparar contra la
## constante: es lo único de este archivo que no es cableado.
@export var forma: CollisionShape3D


func _ready() -> void:
	body_entered.connect(_al_entrar_un_cuerpo)


## El radio que el `.tscn` declara, o `0.0` si la forma no es una esfera.
func radio() -> float:
	var esfera := forma.shape as SphereShape3D
	if esfera == null:
		return 0.0
	return esfera.radius


## Mide a qué distancia del centro quedó lo que entró y se lo pasa al recolector.
##
## Se mide igual aunque el cuerpo haya entrado al área: quién decide si eso alcanza es el dominio,
## y medir acá y decidir allá es lo que permite probar la regla sin levantar una escena.
func _al_entrar_un_cuerpo(cuerpo: Node3D) -> void:
	recolector.pedir_depositar(_id_de(cuerpo), global_position.distance_to(cuerpo.global_position))


## El `id` de lo que entró, o el centinela de «nada» si eso no se presenta.
##
## Los dos cortes son de contrato y no del juego: una pared que entrara al área no tiene el método,
## y un agarrable sin su `.tres` contesta `null`. Los dos terminan en `NO_ES_BASURA`, que lo decide
## el dominio.
func _id_de(cuerpo: Node3D) -> StringName:
	if not cuerpo.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR):
		return ObjetoDelAlmacen.SIN_ID
	var datos: ObjetoDelAlmacen = cuerpo.call(ReglasDeLosObjetos.METODO_INTERACTUAR)
	if datos == null:
		return ObjetoDelAlmacen.SIN_ID
	return datos.id
