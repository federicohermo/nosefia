## La red de seguridad: lo que igual quedó adentro de un sólido fijo vuelve a un lugar alcanzable.
##
## El volumen de los sólidos previene casi todo. Lo que queda es lo que ningún barrido ve:
## `cast_motion` ignora lo que ya arranca solapado, y la hoja de una puerta se mueve escribiéndole
## la posición. Esta red mira en tres momentos —al soltar, al terminar un empujón y al dormirse—
## y, si hace falta, arma los candidatos con física. Cuál gana lo decide `Rescate`.
##
## **Nunca devuelve nada a la mano**: al dormirse o al terminar un empujón, la mano puede estar
## llena. Y no toca ninguna tarea: mueve el cuerpo y nada más.
class_name RedDeSeguridad
extends Node

## En cuántos anillos se busca alrededor del punto donde entró, hasta el tamaño del objeto.
const ANILLOS := 3
const LADOS := 8

## Hasta dónde se busca piso debajo de un candidato, en metros.
const CAIDA := 3.0

## Cuánto puede separarse un candidato de lo que lo sostiene y seguir apoyado, en metros.
const HOLGURA_DEL_APOYO := 0.05

## Cuánto deja el motor que un cuerpo vivo apoyado se hunda en lo que lo sostiene.
const PENETRACION_TOLERADA := "physics/jolt_physics_3d/simulation/penetration_slop"

## La señal de la hoja de una puerta que dejó de girar. La declara la escena de la puerta.
const SENAL_DE_LA_HOJA_QUIETA := &"hoja_quieta"

@export var agarre: Agarre
@export var jugador: CharacterBody3D

## Las hojas de las puertas. Al quedar quietas, lo que quedó adentro se rescata.
@export var puertas: Array[PhysicsBody3D] = []

## Cada rescate, en orden: el objeto, el sólido, dónde estaba, la clase elegida —o
## `Rescate.NINGUNO`— y el aviso. Lo leen los tests.
var rescates: Array[Dictionary] = []

var _vigilados := {}
var _rachas := {}
var _rescatando := false


func _ready() -> void:
	# Después del jugador: es él quien empuja, adentro de su propio paso de física.
	process_physics_priority = 1
	if agarre != null:
		agarre.objeto_soltado.connect(_al_soltar)
	get_tree().node_added.connect(_vigilar)
	for puerta in puertas:
		puerta.connect(SENAL_DE_LA_HOJA_QUIETA, _al_quedar_quieta)
	for nodo in get_tree().root.find_children("*", "RigidBody3D", true, false):
		_vigilar(nodo)


func _physics_process(_delta: float) -> void:
	for caja: Node3D in _rachas.keys():
		var racha: Dictionary = _rachas[caja]
		if not is_instance_valid(caja):
			_rachas.erase(caja)
		elif Rescate.termino_la_racha(racha["ahora"], racha["antes"]):
			_rachas.erase(caja)
			revisar(caja, [racha["inicio"]] as Array[Transform3D])
		else:
			racha["antes"] = racha["ahora"]
			racha["ahora"] = false


## Mira si el objeto se superpone con un sólido fijo y, si es así, lo lleva al primer candidato
## libre. `deshacer` son los lugares que deshacen el gesto, en orden.
func revisar(objeto: Node3D, deshacer: Array[Transform3D] = []) -> void:
	var cuerpo := objeto as PhysicsBody3D
	if cuerpo == null or cuerpo.collision_layer == 0:
		return
	var solido := _solido_pisado(cuerpo)
	if solido == null:
		return
	var desde := cuerpo.global_position
	# Las áreas donde ya estaba, o donde arrancó la noche: volver ahí no cuenta nada nuevo.
	var areas := _areas_en(cuerpo, cuerpo.global_transform)
	if _tiene_origen(cuerpo):
		areas.append_array(
			_areas_en(cuerpo, cuerpo.call(ReglasDeLosObjetos.METODO_LUGAR_DE_ORIGEN))
		)
	var opciones: Array[Array] = [
		deshacer,
		_alrededor(cuerpo),
		_encima_del_origen(cuerpo),
		_origen(cuerpo),
	]
	var clases: Array[Rescate.Clase] = [
		Rescate.Clase.DESHACER,
		Rescate.Clase.ALREDEDOR,
		Rescate.Clase.ENCIMA_DEL_ORIGEN,
		Rescate.Clase.ORIGEN,
	]
	var candidatos: Array[Rescate.Candidato] = []
	var lugares: Array[Transform3D] = []
	for indice in opciones.size():
		var elegido := _primero_libre(cuerpo, opciones[indice], areas)
		candidatos.append(Rescate.Candidato.new(clases[indice], not elegido.is_empty()))
		lugares.append(Transform3D() if elegido.is_empty() else elegido[0])
	var eleccion := Rescate.elegir(candidatos)
	var clase := Rescate.NINGUNO if eleccion == Rescate.NINGUNO else clases[eleccion]
	var aviso := _aviso(cuerpo, solido, desde, clase)
	rescates.append(
		{"objeto": cuerpo, "solido": solido, "posicion": desde, "clase": clase, "aviso": aviso}
	)
	if OS.is_debug_build():
		push_warning(aviso)
	if eleccion != Rescate.NINGUNO:
		_mover(cuerpo, lugares[eleccion])


func _vigilar(nodo: Node) -> void:
	var cuerpo := nodo as RigidBody3D
	if cuerpo == null or not cuerpo.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR):
		return
	if _vigilados.has(cuerpo.get_instance_id()):
		return
	_vigilados[cuerpo.get_instance_id()] = true
	cuerpo.sleeping_state_changed.connect(_al_cambiar_el_reposo.bind(cuerpo))
	if cuerpo.has_signal(ReglasDeLosObjetos.SENAL_EMPUJADA):
		cuerpo.connect(ReglasDeLosObjetos.SENAL_EMPUJADA, _al_empujar)


## Un paso después de soltar, cuando ya corrieron los que acomodan lo soltado. Si para entonces
## volvió a la mano, no tiene colisión y no hay nada que mirar.
func _al_soltar(nodo: Node3D) -> void:
	await get_tree().physics_frame
	if not is_instance_valid(nodo):
		return
	var cuerpo := nodo as PhysicsBody3D
	if cuerpo == null or cuerpo.collision_layer == 0:
		return
	revisar(cuerpo, _al_lado_del_jugador(cuerpo))


## Lo que quedó superpuesto con la hoja quieta. La hoja quieta es un sólido fijo más.
func _al_quedar_quieta(hoja: PhysicsBody3D) -> void:
	var espacio := hoja.get_world_3d().direct_space_state
	var adentro: Array[PhysicsBody3D] = []
	for forma: CollisionShape3D in hoja.find_children("*", "CollisionShape3D", false, false):
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.exclude = [hoja.get_rid()]
		for choque in espacio.intersect_shape(consulta, 16):
			var cuerpo := choque["collider"] as RigidBody3D
			if cuerpo != null and cuerpo.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR):
				if not adentro.has(cuerpo):
					adentro.append(cuerpo)
	for cuerpo in adentro:
		revisar(cuerpo)


## Sólo los rígidos vivos: una caja congelada se mira al soltarla y al terminar el empujón.
func _al_cambiar_el_reposo(cuerpo: RigidBody3D) -> void:
	if cuerpo.sleeping and not cuerpo.freeze:
		revisar(cuerpo)


## La caja avisa antes de correrse, así que acá todavía está donde arrancó la racha.
func _al_empujar(caja: Node3D) -> void:
	if _rescatando:
		return
	if not _rachas.has(caja):
		_rachas[caja] = {"inicio": caja.global_transform, "antes": false, "ahora": true}
	else:
		_rachas[caja]["ahora"] = true


## El primer sólido fijo en el que el cuerpo se hunde más de lo que el motor tolera.
func _solido_pisado(cuerpo: PhysicsBody3D) -> Node3D:
	var tolerado := ReglasDeLosObjetos.ROCE
	if cuerpo is RigidBody3D and not (cuerpo as RigidBody3D).freeze:
		tolerado += ProjectSettings.get_setting(PENETRACION_TOLERADA, 0.0)
	for choque in _choques(cuerpo, cuerpo.global_transform):
		if choque["solido"] is StaticBody3D and choque["profundidad"] > tolerado:
			return choque["solido"]
	return null


## Con qué se superpone el cuerpo si estuviera en `lugar`, sin contar al jugador.
func _choques(cuerpo: PhysicsBody3D, lugar: Transform3D) -> Array[Dictionary]:
	var consulta := PhysicsTestMotionParameters3D.new()
	consulta.from = lugar
	# El tope del motor. Cada cuerpo ocupa varios contactos.
	consulta.max_collisions = 32
	if jugador != null:
		consulta.exclude_bodies = [jugador.get_rid()]
	var resultado := PhysicsTestMotionResult3D.new()
	PhysicsServer3D.body_test_motion(cuerpo.get_rid(), consulta, resultado)
	var salida: Array[Dictionary] = []
	for indice in resultado.get_collision_count():
		(
			salida
			. append(
				{
					"solido": resultado.get_collider(indice),
					"profundidad": resultado.get_collision_depth(indice),
				}
			)
		)
	return salida


## El primer lugar libre y alcanzable de la lista, en un arreglo de uno, o vacío.
##
## Libre y alcanzable: no se superpone con nada, está apoyado, y no cae en un área de tarea en la
## que no estaba antes.
func _primero_libre(cuerpo: PhysicsBody3D, lugares: Array, areas: Array[RID]) -> Array:
	for lugar: Transform3D in lugares:
		var libre := true
		for choque in _choques(cuerpo, lugar):
			libre = libre and choque["profundidad"] <= ReglasDeLosObjetos.ROCE
		for area in _areas_en(cuerpo, lugar):
			libre = libre and areas.has(area)
		if libre and _apoyado(cuerpo, lugar):
			return [lugar]
	return []


func _apoyado(cuerpo: PhysicsBody3D, lugar: Transform3D) -> bool:
	var consulta := PhysicsRayQueryParameters3D.create(
		lugar.origin,
		lugar.origin + Vector3.DOWN * (_media_altura(cuerpo) + HOLGURA_DEL_APOYO),
		cuerpo.collision_mask | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
	)
	consulta.exclude = [cuerpo.get_rid()]
	var golpe := cuerpo.get_world_3d().direct_space_state.intersect_ray(consulta)
	return not golpe.is_empty() and ReglasDeLosObjetos.se_puede_apoyar_en(golpe["normal"].y)


## Las áreas donde caería el cuerpo en `lugar`: la de descarte, y cualquier otra de una tarea.
func _areas_en(cuerpo: PhysicsBody3D, lugar: Transform3D) -> Array[RID]:
	var espacio := cuerpo.get_world_3d().direct_space_state
	var salida: Array[RID] = []
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = lugar * forma.transform
		consulta.collide_with_areas = true
		consulta.collide_with_bodies = false
		for choque in espacio.intersect_shape(consulta, 8):
			salida.append(choque["rid"])
	return salida


func _media_altura(cuerpo: Node3D) -> float:
	var limites := AABB()
	var primero := true
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		var suyos := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		limites = suyos if primero else limites.merge(suyos)
		primero = false
	return limites.size.y / 2.0


func _tamano(cuerpo: Node3D) -> float:
	var limites := AABB()
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		limites = limites.merge(
			Transform3D(forma.global_basis, Vector3.ZERO) * forma.shape.get_debug_mesh().get_aabb()
		)
	return maxf(limites.size.x, limites.size.z)


## El lugar apoyado sobre un punto del piso, con la vuelta que el cuerpo ya tiene.
func _sobre(cuerpo: Node3D, punto: Vector3) -> Transform3D:
	var alto := _media_altura(cuerpo) + ReglasDeLosObjetos.ROCE
	return Transform3D(cuerpo.global_basis, punto + Vector3.UP * alto)


func _al_lado_del_jugador(cuerpo: PhysicsBody3D) -> Array[Transform3D]:
	var salida: Array[Transform3D] = []
	if jugador == null:
		return salida
	var radio := _tamano(cuerpo)
	for forma: CollisionShape3D in jugador.find_children("*", "CollisionShape3D", false, false):
		if forma.shape is CapsuleShape3D:
			radio += (forma.shape as CapsuleShape3D).radius
	var lugares := LugaresDelPiso.alrededor(
		cuerpo.get_world_3d().direct_space_state,
		jugador.global_position,
		-jugador.global_basis.z,
		radio,
		_media_altura(cuerpo) * 2.0,
		CAIDA,
		LADOS,
		cuerpo.collision_mask,
		[cuerpo.get_rid(), jugador.get_rid()]
	)
	for punto in lugares:
		salida.append(_sobre(cuerpo, punto))
	return salida


func _alrededor(cuerpo: PhysicsBody3D) -> Array[Transform3D]:
	var salida: Array[Transform3D] = []
	for anillo in range(1, ANILLOS + 1):
		var lugares := LugaresDelPiso.alrededor(
			cuerpo.get_world_3d().direct_space_state,
			cuerpo.global_position,
			Vector3.FORWARD,
			_tamano(cuerpo) * anillo / ANILLOS,
			_media_altura(cuerpo) * 2.0,
			CAIDA,
			LADOS,
			cuerpo.collision_mask,
			[cuerpo.get_rid()]
		)
		for punto in lugares:
			salida.append(_sobre(cuerpo, punto))
	return salida


## Una unidad sacada de una caja no tiene origen fijo: nació donde el puesto la creó.
func _tiene_origen(cuerpo: PhysicsBody3D) -> bool:
	if not cuerpo.has_method(ReglasDeLosObjetos.METODO_LUGAR_DE_ORIGEN):
		return false
	return not cuerpo.call(ReglasDeLosObjetos.METODO_INTERACTUAR) is UnidadDeProducto


## Encima de la caja que ocupa el origen. Sólo una caja admite otra cosa encima.
func _encima_del_origen(cuerpo: PhysicsBody3D) -> Array[Transform3D]:
	var salida: Array[Transform3D] = []
	if not _tiene_origen(cuerpo):
		return salida
	var origen: Transform3D = cuerpo.call(ReglasDeLosObjetos.METODO_LUGAR_DE_ORIGEN)
	for choque in _choques(cuerpo, origen):
		var ocupante := choque["solido"] as Node3D
		if ocupante == null or ocupante == cuerpo:
			continue
		if not ocupante.has_method(ReglasDeLosObjetos.METODO_EMPUJAR):
			continue
		var tapa := ocupante.global_position.y + _media_altura(ocupante)
		var lugar := origen
		lugar.origin.y = tapa + _media_altura(cuerpo) + ReglasDeLosObjetos.ROCE
		salida.append(lugar)
	return salida


func _origen(cuerpo: PhysicsBody3D) -> Array[Transform3D]:
	if not _tiene_origen(cuerpo):
		return _al_lado_del_jugador(cuerpo)
	return [cuerpo.call(ReglasDeLosObjetos.METODO_LUGAR_DE_ORIGEN)] as Array[Transform3D]


## Lo mueve de golpe. Una caja avisa antes que se va a correr, como al empujarla: lo que tenía
## apilado encima se despierta y cae.
func _mover(cuerpo: PhysicsBody3D, lugar: Transform3D) -> void:
	if cuerpo.has_signal(ReglasDeLosObjetos.SENAL_EMPUJADA):
		_rescatando = true
		cuerpo.emit_signal(ReglasDeLosObjetos.SENAL_EMPUJADA, cuerpo)
		_rescatando = false
	cuerpo.global_transform = lugar
	var rigido := cuerpo as RigidBody3D
	if rigido != null:
		rigido.linear_velocity = Vector3.ZERO
		rigido.angular_velocity = Vector3.ZERO
	cuerpo.reset_physics_interpolation()


func _aviso(cuerpo: Node3D, solido: Node3D, desde: Vector3, clase: int) -> String:
	var destino := (
		"queda donde está: ningún lugar libre"
		if clase == Rescate.NINGUNO
		else "va a %s" % Rescate.Clase.keys()[clase]
	)
	return (
		"Rescate: `%s` estaba adentro de `%s` en %s; %s"
		% [cuerpo.name, solido.name, desde, destino]
	)
