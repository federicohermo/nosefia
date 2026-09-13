extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_la_bolsa_sostenida_no_desplaza_al_jugador() -> void:  # 040-AC5
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var bolsa: RigidBody3D = almacen.get_node("Objetos/BolsaDeBasura1")
	var agarre: Agarre = jugador.get("agarre")
	for cuadro in 60:
		await get_tree().physics_frame
	assert_bool(jugador.is_on_floor()).is_true()
	assert_bool(agarre.pedir_agarrar(bolsa.get("datos"), bolsa)).is_true()
	var camara: Camera3D = jugador.get_node("Camara")
	for grados: int in [-20, -40, -60, -80]:
		camara.rotation.x = deg_to_rad(grados)
		var inicio := jugador.global_position
		for cuadro in 20:
			await get_tree().physics_frame
		var distancia := inicio.distance_to(jugador.global_position)
		(
			assert_float(distancia)
			. override_failure_message("Pitch %d: %f m" % [grados, distancia])
			. is_less(0.01)
		)


func test_soltar_en_el_descarte_entrega_el_id_al_recolector() -> void:  # 040-AC6
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var bolsa: RigidBody3D = almacen.get_node("Objetos/BolsaDeBasura1")
	var agarre: Agarre = jugador.get("agarre")
	var zona: Area3D = almacen.get_node("Objetos/ZonaDeDescarte")
	var recolector: RecolectorDeBasura = almacen.get_node("Servicios/Recolector")
	var datos: ObjetoDelAlmacen = bolsa.get("datos")
	assert_bool(agarre.pedir_agarrar(datos, bolsa)).is_true()
	agarre.punto_de_soltado.global_position = zona.global_position + Vector3.UP * 0.3
	assert_object(agarre.soltar(true)).is_same(bolsa)
	for cuadro in 5:
		await get_tree().physics_frame
	assert_bool(recolector.tarea().esta_depositada(datos.id)).is_true()
	assert_int(recolector.tarea().depositadas()).is_equal(1)
