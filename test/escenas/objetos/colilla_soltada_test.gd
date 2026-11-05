## La colilla que el jugador suelta en el depósito queda sobre el piso, y se la puede volver a
## levantar.
##
## Se suelta como en el juego: el jugador la agarra, mira a distintas alturas y repite el clic.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const COLILLA := preload("res://src/escenas/objetos/colilla.tscn")

## Piso libre del depósito, lejos de los muebles y sin nada encima. Es el que mide
## `producto_soltado_test.gd`.
const PISO_LIBRE := Vector3(4.18, 0.0, -8.95)

## A cuántos metros del lugar libre se para el jugador, mirando hacia adentro del depósito.
const PARADO := 1.0

## Hacia dónde mira al soltar, en grados: del piso a los pies hasta un poco sobre el horizonte.
const ALTOS_DE_LA_MIRA: Array[float] = [-80.0, -60.0, -40.0, -20.0, 0.0, 15.0]

## Cuadros de física para que lo soltado caiga y se duerma.
const CUADROS_DE_REPOSO := 90

## Cuánto puede bajar el centro por debajo del piso que tiene debajo, en metros.
const HUNDIMIENTO := 0.05


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


func _piso_debajo(almacen: Node3D, cuerpo: Node3D) -> Dictionary:
	var arriba := cuerpo.global_position * Vector3(1.0, 0.0, 1.0) + Vector3.UP * 3.0
	var consulta := PhysicsRayQueryParameters3D.create(arriba, arriba + Vector3.DOWN * 6.0)
	consulta.exclude = [(cuerpo as CollisionObject3D).get_rid()]
	return almacen.get_world_3d().direct_space_state.intersect_ray(consulta)


func test_la_colilla_soltada_en_el_deposito_queda_sobre_el_piso() -> void:
	var almacen := await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var colilla: ObjetoAgarrable = COLILLA.instantiate()
	almacen.add_child(colilla)
	var piso_libre: Dictionary = almacen.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(
			PISO_LIBRE + Vector3.UP * 3.0, PISO_LIBRE + Vector3.DOWN * 3.0
		)
	)
	# La premisa: el lugar donde se para el jugador tiene piso horizontal debajo.
	assert_bool(piso_libre.is_empty()).is_false()
	assert_bool(piso_libre["normal"].y > 0.99).is_true()
	var soltadas := 0
	for alto in ALTOS_DE_LA_MIRA:
		jugador.global_position = Vector3(
			PISO_LIBRE.x, piso_libre["position"].y + 0.1, PISO_LIBRE.z + PARADO
		)
		jugador.velocity = Vector3.ZERO
		if agarre.manos().sostenido() == null:
			_clic(jugador, colilla)
		assert_object(agarre.manos().sostenido()).is_same(colilla.datos)
		_mirar(jugador, 0.0, deg_to_rad(alto))
		_clic(jugador, colilla)
		if agarre.manos().sostenido() != null:
			continue
		soltadas += 1
		for cuadro in CUADROS_DE_REPOSO:
			await get_tree().physics_frame
		var piso := _piso_debajo(almacen, colilla)
		assert_bool(piso.is_empty()).is_false()
		var donde := "Soltada mirando %.0f" % alto
		(
			assert_float(colilla.global_position.y)
			. override_failure_message(
				(
					"%s, bajó hasta %.3f y el piso está en %.3f"
					% [donde, colilla.global_position.y, piso["position"].y]
				)
			)
			. is_greater_equal(piso["position"].y - HUNDIMIENTO)
		)
		(
			assert_bool(colilla.visible and colilla.collision_layer != 0)
			. override_failure_message("%s, la colilla no quedó a la vista y levantable" % donde)
			. is_true()
		)
	assert_int(soltadas).is_greater(0)
