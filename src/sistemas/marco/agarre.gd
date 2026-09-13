## Traduce «lo agarré» a lo que el motor entiende: reparentar el cuerpo y congelarle la física.
##
## No decide nada — quién puede agarrar qué lo contesta `Manos`, que es de `dominio/` y tiene
## test. Acá quedan las tres cosas que un `RefCounted` no puede hacer: mover un `Node3D` de
## padre, tocar `freeze` y emitir señales.
##
## Va en `marco/` y no en `tareas/` ni en `investigacion/`, que es el criterio de esa carpeta —si
## consume tiempo del turno, y para qué—: agarrar no consume tiempo y no cumple nada. Es el mismo
## gesto de los dos lados de la tensión, y esa ambigüedad es justamente el spec: agarrar una lata
## para reponerla y agarrarla para verle el vencimiento son el mismo movimiento. Examinar sí cae
## de un lado, y por eso `Examen` vive en `investigacion/`.
##
## **Reparenta y escribe `position` local, nunca `global_position`.** Está medido en el
## `research.md` del 006: `global_transform` fuera del árbol de escena tira un error del motor y
## devuelve la identidad, así que un sistema que colocara con eso no se podría probar sin
## levantar una escena — y el «verde» que diera sería el de un valor que coincide por casualidad.
class_name Agarre
extends Node

signal objeto_agarrado(nodo: Node3D)
signal agarre_rechazado(motivo: Manos.Rechazo)
signal objeto_soltado(nodo: Node3D)

## Los tres puntos entran por `@export` y no como autoload ni por `get_node()` hacia arriba:
## está medido que `gate_de_capas.py` no ve un autoload nombrado por su nombre global, así que
## esa puerta cruzaría capas sin dejar rastro.
@export var punto_de_carga: Node3D
@export var punto_de_soltado: Node3D
@export var punto_de_respaldo: Node3D

var _manos := Manos.new()
var _nodo: Node3D = null
var _capa_original: int = 0
var _mascara_original: int = 0


## Las manos, para que quien las necesite pregunte en vez de que este sistema le copie el estado.
func manos() -> Manos:
	return _manos


## Devuelve `true` **sólo si lo agarró ahora**, y emite el rechazo con su motivo si no.
func pedir_agarrar(datos: ObjetoDelAlmacen, nodo: Node3D) -> bool:
	var motivo := _manos.motivo_de_rechazo(datos)
	if motivo != Manos.Rechazo.NINGUNO:
		agarre_rechazado.emit(motivo)
		return false
	# Un punto sin cablear es un `.tscn` mal armado y no un rechazo del juego: emitir
	# `agarre_rechazado` acá le diría al jugador «no podés agarrar eso», que sería falso. Quien
	# caza esto es `test/escenas/jugador_test.gd`, que afirma que los `@export` de los puntos
	# RESUELVEN, no que los nodos existan: está medido que borrar el `node_paths` del `.tscn` deja
	# los nodos en su lugar, el `@export` en `null` y la escena cargando sin un solo error.
	if nodo == null or punto_de_carga == null:
		push_error("Agarre sin punto de carga cableado: revisar jugador.tscn")
		return false
	_manos.agarrar(datos)
	_nodo = nodo
	# Guardar s?lo al agarrar: el examen recibe el cuerpo con las colisiones suspendidas.
	if nodo is CollisionObject3D:
		_capa_original = nodo.collision_layer
		_mascara_original = nodo.collision_mask
		nodo.collision_layer = 0
		nodo.collision_mask = 0
	_colgar(nodo, punto_de_carga)
	objeto_agarrado.emit(nodo)
	return true


## Suelta lo que se lleva y devuelve el nodo que soltó, o `null` si no había nada.
##
## `al_frente` es «adelante hay lugar»: con `false` lo deja a los pies en vez de empujarlo
## adentro de una estantería. Quién contesta esa pregunta es la escena, que es la única que puede
## mirar el mundo; acá sólo se elige el punto.
func soltar(al_frente: bool) -> Node3D:
	if _manos.soltar() == null:
		return null
	var nodo := _nodo
	_nodo = null
	var ancla := punto_de_soltado if al_frente else punto_de_respaldo
	if nodo != null and ancla != null:
		_colgar(nodo, ancla, false)
	if nodo is CollisionObject3D:
		nodo.collision_layer = _capa_original
		nodo.collision_mask = _mascara_original
	objeto_soltado.emit(nodo)
	return nodo


## Mueve a otro punto lo que se lleva, sin soltarlo, y devuelve el nodo que movió.
##
## Es lo que `Examen` usa para acercarlo a la cara: quien mueve el nodo es siempre quien lo tiene,
## así que la única pieza que reparenta sigue siendo ésta. La alternativa —que `Examen` llame al
## reparentador de acá— sería un sistema tocando el interior de otro.
func mover_lo_sostenido(ancla: Node3D) -> Node3D:
	if _nodo == null or ancla == null:
		return null
	_colgar(_nodo, ancla)
	return _nodo


## Vuelve a poner en la mano lo que se había acercado a la cara.
func devolver_a_la_mano() -> Node3D:
	return mover_lo_sostenido(punto_de_carga)


## El clic izquierdo hace las dos cosas, y cuál de las dos toca es un `if` sobre el estado de las
## manos. Vive acá y no en la escena: en `escenas/` sería una regla del juego sin test, y los dos
## gates darían verde sobre ella.
func alternar(datos: ObjetoDelAlmacen, nodo: Node3D) -> void:
	if _manos.sostenido() == null:
		pedir_agarrar(datos, nodo)
	else:
		soltar(true)


## Deja las manos vacías dejando lo que hubiera a los pies. No emite nada si ya estaban vacías:
## lo llaman el cierre de la jornada y la suspensión del jugador, que pueden pasar dos veces
## seguidas, y un aviso ahí haría que el HUD anuncie un objeto que no existía.
func vaciar_las_manos() -> void:
	if _manos.sostenido() == null:
		return
	soltar(false)


## Cuelga el nodo del ancla, en el origen del ancla y sin rotación heredada.
##
## La física se congela mientras se lleva algo: sin eso el objeto se cae de la mano en el mismo
## cuadro en que se lo levanta, y el síntoma —«no se puede agarrar nada»— no nombra a la física.
static func _colgar(nodo: Node3D, ancla: Node3D, quieta: bool = true) -> void:
	var padre := nodo.get_parent()
	if padre != null:
		padre.remove_child(nodo)
	ancla.add_child(nodo)
	nodo.position = Vector3.ZERO
	nodo.rotation = Vector3.ZERO
	if nodo is RigidBody3D:
		(nodo as RigidBody3D).freeze = quieta
