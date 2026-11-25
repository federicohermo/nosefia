extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Desde qué altura se suelta, en metros: la de la mano de quien lleva un producto.
const ALTURA_DE_SUELTA := 1.7
## Cuántos pasos de física se espera a que se apoye.
const PASOS_PARA_APOYARSE := 120
## Lo mínimo que tiene que haber entre la base del cuerpo y el piso para que no se haya hundido.
const HUNDIMIENTO_TOLERADO := 0.02
## Un producto: la caja de un envase chico, con las inclinaciones con que cae de la mano.
const TAMANO := Vector3(0.15, 0.2, 0.15)
const INCLINACIONES: Array[Vector3] = [
	Vector3.ZERO,
	Vector3(0.0, -0.349066, -0.296706),
	Vector3(0.4, 0.2, 0.5),
	Vector3(0.0, 0.0, 0.785398),
]
## De dónde a dónde, y cada cuánto, se prueba el piso del local.
const DESDE := Vector2(-2.0, -7.0)
const HASTA := Vector2(7.0, 5.0)
const PASO := Vector2(1.5, 2.0)
## El caso que la CI vio atravesar el piso (agarre_fisico_test), en el mundo.
const PUNTO_QUE_ATRAVESO := Vector2(7.317472, -3.853248)
## Con menos puntos que esto la prueba no mira el piso: sería un verde que no ejerce nada.
const PUNTOS_MINIMOS := 8


func test_un_producto_que_cae_sobre_el_piso_no_lo_atraviesa() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA, "medios": 0})
	)
	add_child(almacen)
	await get_tree().physics_frame
	var estructura: Node3D = almacen.get_node("Estructura")
	var suelo: CollisionShape3D = estructura.get_node("SueloSolido/Local")
	var piso := suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0
	var espacio: PhysicsDirectSpaceState3D = estructura.get_world_3d().direct_space_state
	var puntos: Array[Vector2] = [PUNTO_QUE_ATRAVESO]
	var x := DESDE.x
	while x <= HASTA.x:
		var z := DESDE.y
		while z <= HASTA.y:
			puntos.append(Vector2(x, z))
			z += PASO.y
		x += PASO.x
	var cuerpos: Array[RigidBody3D] = []
	var probados := 0
	for punto in puntos:
		# Sólo vale el piso a cielo abierto: si lo primero que hay arriba es un mueble, no es el piso.
		# Las instancias del almacén comparten el mundo: vale el piso de cualquiera de ellas.
		var rayo := PhysicsRayQueryParameters3D.create(
			Vector3(punto.x, ALTURA_DE_SUELTA + TAMANO.y, punto.y), Vector3(punto.x, -1.0, punto.y)
		)
		var golpe: Dictionary = espacio.intersect_ray(rayo)
		if golpe.is_empty() or (golpe["collider"] as Node).name != &"SueloSolido":
			continue
		for inclinacion in INCLINACIONES:
			var cuerpo: RigidBody3D = auto_free(RigidBody3D.new())
			var forma := CollisionShape3D.new()
			var caja := BoxShape3D.new()
			caja.size = TAMANO
			forma.shape = caja
			cuerpo.add_child(forma)
			cuerpo.continuous_cd = true
			cuerpo.collision_layer = 1
			cuerpo.collision_mask = ReglasDeLosObjetos.MASCARA_DEL_PRODUCTO
			add_child(cuerpo)
			cuerpo.global_basis = Basis.from_euler(inclinacion)
			cuerpo.global_position = Vector3(punto.x, ALTURA_DE_SUELTA, punto.y)
			cuerpos.append(cuerpo)
		probados += 1
	(
		assert_int(probados)
		. override_failure_message("el piso a cielo abierto no tiene puntos para probar")
		. is_greater_equal(PUNTOS_MINIMOS)
	)
	for _paso in PASOS_PARA_APOYARSE:
		await get_tree().physics_frame
	for cuerpo in cuerpos:
		var base := cuerpo.global_position.y - TAMANO.length() / 2.0
		(
			assert_float(cuerpo.global_position.y)
			. override_failure_message(
				(
					"un producto soltado en %v quedó en %v: atravesó el piso, que llega a %.3f"
					% [
						Vector3(
							cuerpo.global_position.x, ALTURA_DE_SUELTA, cuerpo.global_position.z
						),
						cuerpo.global_position,
						piso
					]
				)
			)
			. is_greater(piso - HUNDIMIENTO_TOLERADO)
		)
		assert_float(base).is_less(cuerpo.global_position.y)
