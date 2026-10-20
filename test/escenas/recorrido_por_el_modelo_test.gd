## La altura del ojo depende del piso real, incluso después de importar otro modelo.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_la_gravedad_asienta_al_jugador_a_la_misma_altura_en_los_tres_cuartos() -> void:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	add_child(local)
	local.get_node("Interfaz/PersianaDeLaNoche").terminar()
	local.get("_reloj").set_process(false)
	var jugador: CharacterBody3D = local.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var espacio := local.get_world_3d().direct_space_state
	for cuadro in 4:
		await get_tree().physics_frame
	for nombre: String in ["Local", "Deposito", "Fondo"]:
		var forma: CollisionShape3D = local.get_node("Estructura/SueloSolido/" + nombre)
		var piso := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		var probados := 0
		for x: float in [0.2, 0.5, 0.8]:
			for z: float in [0.2, 0.5, 0.8]:
				var pie := Vector3(
					lerpf(piso.position.x, piso.end.x, x),
					piso.end.y,
					lerpf(piso.position.z, piso.end.z, z)
				)
				var consulta := PhysicsShapeQueryParameters3D.new()
				consulta.shape = cuerpo.shape
				consulta.transform = Transform3D(
					Basis.IDENTITY, pie + cuerpo.position + Vector3.UP * 0.05
				)
				consulta.collision_mask = jugador.collision_mask
				consulta.exclude = [jugador.get_rid()]
				if not espacio.intersect_shape(consulta, 1).is_empty():
					continue
				jugador.global_position = pie + Vector3.UP * 0.35
				jugador.velocity = Vector3.ZERO
				jugador.reset_physics_interpolation()
				for cuadro in 40:
					await get_tree().physics_frame
				assert_bool(jugador.is_on_floor()).override_failure_message(nombre).is_true()
				(
					assert_float(jugador.global_position.y - piso.end.y)
					. override_failure_message(nombre)
					. is_between(-0.01, 0.04)
				)
				assert_float(camara.global_position.y - jugador.global_position.y).is_equal_approx(
					ReglasDelJugador.ALTURA_DE_LA_CAMARA, 0.001
				)
				probados += 1
		assert_int(probados).override_failure_message(nombre).is_greater(0)


func test_abrir_el_cuartito_no_barre_los_utiles_de_limpieza() -> void:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	local.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	add_child(local)
	var cuartito: Node = local.get_node("Estructura/puerta_limpieza/CuerpoDeLaHoja")
	assert_bool(cuartito.call("puerta").trabada()).is_false()
	local.get("_jugador").set_physics_process(false)
	var utiles: Array = local.get("_utiles_de_limpieza")
	var origenes: Array[Vector3] = []
	for util: Node3D in utiles:
		origenes.append(util.global_position)
	cuartito.call("alternar")
	assert_bool(cuartito.call("puerta").abierta()).is_true()
	for cuadro in 90:
		await get_tree().physics_frame
	for indice in utiles.size():
		(
			assert_float(utiles[indice].global_position.distance_to(origenes[indice]))
			. override_failure_message(str(utiles[indice].name))
			. is_less(0.08)
		)
