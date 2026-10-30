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
## **Reparenta y escribe `position` local, nunca `global_position`.** Está medido:
## `global_transform` fuera del árbol de escena tira un error del motor y
## devuelve la identidad, así que un sistema que colocara con eso no se podría probar sin
## levantar una escena — y el «verde» que diera sería el de un valor que coincide por casualidad.
class_name Agarre
extends Node

signal objeto_agarrado(nodo: Node3D)
## Lo mismo que `objeto_agarrado`, para el audio, con el contexto del gesto: si saca una bolsa del
## tacho. Se emite aparte porque `objeto_agarrado` tiene otros lectores que esperan un solo dato.
signal objeto_alzado(nodo: Node3D, del_tacho: bool)
signal agarre_rechazado(motivo: Manos.Rechazo)
signal objeto_soltado(nodo: Node3D)
## La mano queda libre sin soltar el cuerpo al mundo: lo recibe un destino.
signal objeto_entregado(nodo: Node3D)

## Cuánto se agranda la forma al buscar lo que toca, en metros. Es también cuánto puede quedar
## hundida la base de lo que está encima.
const MARGEN_DE_CONTACTO := 0.02

## Los tres puntos entran por `@export` y no como autoload ni por `get_node()` hacia arriba:
## está medido que `gate_de_capas.py` no ve un autoload nombrado por su nombre global, así que
## esa puerta cruzaría capas sin dejar rastro.
@export var punto_de_carga: Node3D
@export var punto_de_soltado: Node3D
@export var punto_de_respaldo: Node3D
@export var punto_de_producto: Node3D

var _manos := Manos.new()
var _nodo: Node3D = null
## De dónde colgaba lo sostenido antes de su último movimiento. Una caja se lleva en la cintura y
## una unidad en su punto propio: volver del examen al punto de carga las dejaba en otra mano.
var _ancla_de_vuelta: Node3D = null
var _capa_original: int = 0
var _mascara_original: int = 0


func cuerpo_sostenido() -> Node3D:
	return _nodo


## Las manos, para que quien las necesite pregunte en vez de que este sistema le copie el estado.
func manos() -> Manos:
	return _manos


## Devuelve `true` **sólo si lo agarró ahora**, y emite el rechazo con su motivo si no.
func pedir_agarrar(datos: ObjetoDelAlmacen, nodo: Node3D, del_tacho: bool = false) -> bool:
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
	_ancla_de_vuelta = null
	_despertar_contactos(nodo)
	# Guardar solo al agarrar: el examen recibe el cuerpo con las colisiones suspendidas.
	if nodo is CollisionObject3D:
		_capa_original = nodo.collision_layer
		_mascara_original = nodo.collision_mask
		nodo.collision_layer = 0
		nodo.collision_mask = 0
	_colgar(nodo, _punto_de_carga())
	objeto_agarrado.emit(nodo)
	objeto_alzado.emit(nodo, del_tacho)
	return true


## Suelta lo que se lleva y devuelve el nodo que soltó, o `null` si no había nada.
##
## `al_frente` es «adelante hay lugar»: con `false` lo deja a los pies en vez de empujarlo
## adentro de una estantería. Quién contesta esa pregunta es la escena, que es la única que puede
## mirar el mundo; acá sólo se elige el punto. Al frente, si la mira señala una superficie que lo
## admite, la escena lo apoya ahí después de `objeto_soltado`.
func soltar(al_frente: bool) -> Node3D:
	if _manos.soltar() == null:
		return null
	var nodo := _nodo
	_nodo = null
	_ancla_de_vuelta = null
	var ancla := punto_de_soltado if al_frente else punto_de_respaldo
	if nodo != null and ancla != null:
		var orientacion := nodo.global_basis if nodo.is_inside_tree() else nodo.basis
		_colgar(nodo, ancla, false)
		# Cambiar de padre no debe enderezar el objeto antes de que empiece a caer.
		if nodo.is_inside_tree():
			nodo.global_basis = orientacion
		else:
			nodo.basis = orientacion
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
	_ancla_de_vuelta = _nodo.get_parent() as Node3D
	_colgar(_nodo, ancla)
	return _nodo


## Vuelve a poner lo que se había acercado a la cara en el punto de donde salió.
##
## No anota una vuelta nueva: devolver dos veces deja el objeto donde estaba, y no lo rebota a
## la cara.
func devolver_a_la_mano() -> Node3D:
	if _nodo == null:
		return null
	var ancla := _ancla_de_vuelta
	if ancla == null:
		ancla = _punto_de_carga()
	if ancla == null:
		return null
	_colgar(_nodo, ancla)
	return _nodo


func _punto_de_carga() -> Node3D:
	if _manos.sostenido() is UnidadDeProducto and punto_de_producto != null:
		return punto_de_producto
	return punto_de_carga


## Una entrega aceptada deja el cuerpo quieto para que el destino lo ubique.
func entregar() -> Node3D:
	_manos.soltar()
	var nodo := _nodo
	_nodo = null
	_ancla_de_vuelta = null
	if nodo != null:
		objeto_entregado.emit(nodo)
	return nodo


## El clic izquierdo hace las dos cosas, y cuál de las dos toca es un `if` sobre el estado de las
## manos. Vive acá y no en la escena: en `escenas/` sería una regla del juego sin test, y los dos
## gates darían verde sobre ella.
func alternar(datos: ObjetoDelAlmacen, nodo: Node3D) -> void:
	if _manos.sostenido() == null:
		pedir_agarrar(datos, nodo)
	else:
		soltar(true)


func vaciar_las_manos() -> void:
	if _manos.sostenido() == null:
		return
	soltar(false)


## Despierta lo apoyado antes de quitar el cuerpo que lo sostiene: lo que lo toca, y lo que éste
## sostiene a su vez.
static func _despertar_contactos(nodo: Node3D) -> void:
	if not nodo is PhysicsBody3D or not nodo.is_inside_tree():
		return
	despertar_lo_apoyado(nodo as PhysicsBody3D, {}, true)


## Despierta lo que toca al cuerpo y sigue hacia arriba desde cada cosa que despierta, hasta el
## final de la pila: quitado el de abajo, cada uno cae hasta su apoyo real.
##
## **Con `todo_contacto`, también lo que lo toca de costado**: al quitar el cuerpo lo que quedó
## pegado debe asentarse de nuevo. Sin él, sólo lo que está más arriba. Un cuerpo congelado
## —una caja quieta— no despierta a nadie, y por eso sólo se suelta el que quedó arriba de lo que
## se va: uno de costado sigue sobre su propio apoyo.
##
## Cada cuerpo se visita una vez, en `visitados`. Estar despierto no corta el recorrido: puede
## sostener algo que sigue dormido.
static func despertar_lo_apoyado(
	cuerpo: PhysicsBody3D, visitados: Dictionary[RID, bool], todo_contacto: bool = false
) -> void:
	if visitados.has(cuerpo.get_rid()):
		return
	visitados[cuerpo.get_rid()] = true
	var espacio := cuerpo.get_world_3d().direct_space_state
	var tapa := _limites_globales(cuerpo).end.y
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		if forma.disabled or forma.shape == null:
			continue
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		# Al congelarse, el apoyo pasa a ser estático y Jolt no despierta lo que sostenía.
		consulta.margin = MARGEN_DE_CONTACTO
		consulta.exclude = [cuerpo.get_rid()]
		for choque: Dictionary in espacio.intersect_shape(consulta, 32):
			var contacto := choque.collider as RigidBody3D
			if contacto == null:
				continue
			# Encima es que su base llega a la tapa, no que su origen quede más alto: un vecino
			# más alto, al lado, tiene el origen más arriba sin estar apoyado en nada de éste.
			var arriba := _limites_globales(contacto).position.y >= tapa - MARGEN_DE_CONTACTO
			if not arriba and (contacto.freeze or not todo_contacto):
				continue
			contacto.freeze = false
			contacto.sleeping = false
			if arriba:
				despertar_lo_apoyado(contacto, visitados)


## La caja que envuelve las formas activas del cuerpo, en el espacio global.
static func _limites_globales(cuerpo: PhysicsBody3D) -> AABB:
	var limites := AABB()
	var primera := true
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		if forma.disabled or forma.shape == null:
			continue
		var de_la_forma := forma.global_transform * LimitesDeForma.de(forma.shape)
		limites = de_la_forma if primera else limites.merge(de_la_forma)
		primera = false
	return limites


## Cuelga el nodo del ancla, en el origen del ancla y sin rotación heredada.
## La física se congela mientras se lleva algo para que no se caiga de la mano.
static func _colgar(nodo: Node3D, ancla: Node3D, quieta: bool = true) -> void:
	nodo.top_level = false
	var padre := nodo.get_parent()
	if padre != null:
		padre.remove_child(nodo)
	ancla.add_child(nodo)
	nodo.position = Vector3.ZERO
	nodo.rotation = Vector3.ZERO
	if quieta and "orientacion_en_mano" in nodo:
		var orientacion: Basis = nodo.get("orientacion_en_mano")
		nodo.rotation = orientacion.get_euler()
	# Los cuerpos sueltos no deben heredar los movimientos de la cámara.
	nodo.top_level = not quieta
	if nodo is RigidBody3D:
		(nodo as RigidBody3D).freeze = quieta
