extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_soltar_hacia_la_gondola_deja_el_producto_visible_y_recuperable() -> void:
	for ojo in [Vector3(2.6, 1.7, 0), Vector3(0, 1.7, 0), Vector3(1.3, 1.7, 3.85)]:
		var almacen: Node3D = auto_free(ALMACEN.instantiate())
		add_child(almacen)
		var jugador: CharacterBody3D = almacen.get_node("Jugador")
		jugador.set_physics_process(false)
		var camara: Camera3D = jugador.get_node("Camara")
		var agarre: Agarre = jugador.get("agarre")
		jugador.global_position = ojo - Vector3.UP * 1.7
		camara.look_at(Vector3(1.3, 1.7, 0))
		await get_tree().physics_frame
		for producto in Catalogo.todos():
			almacen.get("_reposicion_manual").retirar(producto.id)
			var cuerpo: RigidBody3D = agarre.punto_de_producto.get_child(0)
			var orientacion := cuerpo.global_basis
			agarre.soltar(true)
			assert_bool(cuerpo.global_basis.is_equal_approx(orientacion)).is_true()
			for cuadro in 90:
				await get_tree().physics_frame
			camara.look_at(cuerpo.global_position)
			var candidato: CampoDeInteraccion.Candidato = jugador.call("_medir_candidato", cuerpo)
			(
				assert_float(candidato.distancia)
				. override_failure_message(
					(
						"%s soltado desde %s quedó en %s, fuera de alcance"
						% [producto.nombre, ojo, cuerpo.global_position]
					)
				)
				. is_less(ReglasDelJugador.ALCANCE_DE_LA_MIRA)
			)
			assert_bool(cuerpo.is_visible_in_tree()).is_true()
			assert_bool(agarre.pedir_agarrar(cuerpo.datos, cuerpo)).is_true()
			almacen.get("_reposicion_manual").pedir_colocar(producto.id)
			camara.look_at(Vector3(1.3, 1.7, 0))
		almacen.queue_free()
		await get_tree().process_frame


func test_la_bolsa_sostenida_no_desplaza_al_jugador() -> void:
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


func test_soltar_en_el_descarte_entrega_el_id_al_recolector() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var bolsa: RigidBody3D = almacen.get_node("Objetos/BolsaDeBasura1")
	var agarre: Agarre = jugador.get("agarre")
	var zona: Area3D = almacen.get_node("Objetos/ZonaDeDescarte")
	var recolector: RecolectorDeBasura = almacen.get_node("Servicios/Recolector")
	var datos: ObjetoDelAlmacen = bolsa.get("datos")
	jugador.global_position = zona.global_position + Vector3.BACK
	assert_bool(agarre.pedir_agarrar(datos, bolsa)).is_true()
	agarre.punto_de_soltado.global_position = zona.global_position + Vector3.UP * 0.3
	assert_object(agarre.soltar(true)).is_same(bolsa)
	for cuadro in 5:
		await get_tree().physics_frame
	assert_bool(recolector.tarea().esta_depositada(datos.id)).is_true()
	assert_int(recolector.tarea().depositadas()).is_equal(1)
