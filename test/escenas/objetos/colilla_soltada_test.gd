## La colilla que el jugador suelta en cualquier lugar del depósito queda sobre el piso.
##
## Se suelta como en el juego: el jugador la agarra, mira y repite el clic. Se recorre todo el piso
## del depósito, con un margen hacia el local y las paredes, y se mira desde cada lugar en varias
## direcciones y alturas.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const COLILLA := preload("res://src/escenas/objetos/colilla.tscn")

## Cada cuántos metros se para el jugador, en x y en z.
const PASO := 0.75

## Cuánto se agranda el depósito para cubrir el borde con el local y las paredes, en metros.
const MARGEN := 0.5

## Hacia dónde mira en cada gesto, en grados. El gesto `n` usa el giro `n` y el alto `n`.
const GIROS: Array[float] = [0.0, 90.0, 180.0, 270.0]
const ALTOS: Array[float] = [-70.0, -40.0, 0.0, 10.0]

## Cuadros de física para que lo soltado caiga y se duerma.
const CUADROS_DE_REPOSO := 120

## Cuánto puede bajar el centro por debajo del piso, en metros.
const HUNDIMIENTO := 0.05

## Cuántos casos que fallaron se nombran en el mensaje.
const AVISOS_MAXIMOS := 10


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	await get_tree().physics_frame
	return almacen


## Mira como lo haría el mouse. El suavizado del giro atrasa la cámara según cuántos cuadros hubo:
## se termina el dibujo acá, y el gesto suelta con la vista pedida.
func _mirar(jugador: Node3D, giro: float, alto: float) -> void:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var evento := InputEventMouseMotion.new()
	evento.relative = (
		Vector2(jugador.get_node("Giro").rotation.y - giro, camara.rotation.x - alto)
		/ ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE
	)
	jugador.call("_unhandled_input", evento)
	(jugador.get("_control") as ControlDelJugador).avanzar_el_dibujo(SuavizadoDelGiro.VENTANA)
	jugador.call("_aplicar_la_rotacion")


## El clic del agarre sobre el objetivo: levanta lo que hay en el suelo y suelta lo que se lleva.
func _clic(jugador: Node3D, objetivo: Node3D) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


## El depósito en el mundo, agrandado por el margen.
func _deposito_en_el_mundo(almacen: Node3D) -> AABB:
	var habitaciones: Node3D = almacen.get("_habitaciones")
	var deposito: Array[AABB] = habitaciones.get("deposito")
	var limites := habitaciones.global_transform * deposito[0]
	for parte in deposito:
		limites = limites.merge(habitaciones.global_transform * parte)
	return limites.grow(MARGEN)


## Donde el cuerpo del jugador cabe: parado ahí no se superpone con nada.
func _cabe_el_jugador(jugador: CharacterBody3D, lugar: Vector3) -> bool:
	var prueba := PhysicsTestMotionParameters3D.new()
	prueba.from = Transform3D(jugador.global_basis, lugar)
	prueba.motion = Vector3.ZERO
	return not PhysicsServer3D.body_test_motion(
		jugador.get_rid(), prueba, PhysicsTestMotionResult3D.new()
	)


func _lugares_donde_pararse(
	almacen: Node3D, jugador: CharacterBody3D, altura: float
) -> Array[Vector3]:
	var limites := _deposito_en_el_mundo(almacen)
	var lugares: Array[Vector3] = []
	var x := limites.position.x
	while x <= limites.end.x:
		var z := limites.position.z
		while z <= limites.end.z:
			var lugar := Vector3(x, altura, z)
			if _cabe_el_jugador(jugador, lugar):
				lugares.append(lugar)
			z += PASO
		x += PASO
	return lugares


## Qué solido tiene justo debajo, para nombrarlo si la colilla se pierde.
func _que_hay_debajo(almacen: Node3D, colilla: Node3D) -> String:
	var consulta := PhysicsRayQueryParameters3D.create(
		colilla.global_position, colilla.global_position + Vector3.DOWN * 4.0
	)
	consulta.exclude = [(colilla as CollisionObject3D).get_rid()]
	var golpe := almacen.get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty():
		return "nada"
	var solido := golpe["collider"] as Node
	return "`%s/%s` a %.2f" % [solido.get_parent().name, solido.name, golpe["position"].y]


func test_la_colilla_soltada_en_cualquier_lugar_del_deposito_queda_sobre_el_piso() -> void:
	var almacen := await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var lugares := _lugares_donde_pararse(almacen, jugador, jugador.global_position.y)
	# La premisa: hay dónde pararse. Si el depósito cambia de lugar, esto sale rojo en vez de
	# recorrer un piso vacío.
	assert_array(lugares).is_not_empty()
	var piso := _deposito_en_el_mundo(almacen).position.y + MARGEN
	var soltadas: Array[Dictionary] = []
	for lugar in lugares:
		for gesto in GIROS.size():
			# Una colilla ya soltada puede haber quedado donde se para ahora: ahí no se entra.
			if not _cabe_el_jugador(jugador, lugar):
				continue
			var colilla: ObjetoAgarrable = COLILLA.instantiate()
			almacen.add_child(colilla)
			jugador.global_position = lugar
			jugador.velocity = Vector3.ZERO
			_clic(jugador, colilla)
			await get_tree().physics_frame
			_mirar(jugador, deg_to_rad(GIROS[gesto]), deg_to_rad(ALTOS[gesto]))
			_clic(jugador, colilla)
			var nacio := colilla.global_position
			var debajo := _que_hay_debajo(almacen, colilla)
			await get_tree().physics_frame
			var donde := (
				"desde %v mirando %.0f/%.0f, nació en %v con %s debajo"
				% [lugar, GIROS[gesto], ALTOS[gesto], nacio, debajo]
			)
			soltadas.append({"colilla": colilla, "donde": donde})
	for cuadro in CUADROS_DE_REPOSO:
		await get_tree().physics_frame
	var perdidas: Array[String] = []
	for suelta in soltadas:
		var colilla: ObjetoAgarrable = suelta["colilla"]
		if colilla.global_position.y < piso - HUNDIMIENTO:
			perdidas.append("%s: quedó en %v" % [suelta["donde"], colilla.global_position])
	(
		assert_array(perdidas)
		. override_failure_message(
			(
				"%d de %d colillas atravesaron el piso (%.3f). %s"
				% [
					perdidas.size(),
					soltadas.size(),
					piso,
					" | ".join(perdidas.slice(0, AVISOS_MAXIMOS))
				]
			)
		)
		. is_empty()
	)
