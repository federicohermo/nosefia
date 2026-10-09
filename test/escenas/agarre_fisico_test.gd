extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")


func test_soltar_hacia_la_gondola_deja_el_producto_visible_y_recuperable() -> void:
	var referencia: Node3D = auto_free(ALMACEN.instantiate())
	var malla := referencia.get_node("Estructura/gondolanueva") as MeshInstance3D
	var limites := malla.transform * malla.get_aabb()
	var centro := limites.get_center()
	var destino := Vector3(centro.x, 1.7, centro.z)
	var ojos: Array[Vector3] = [
		Vector3(limites.end.x + 0.6, 1.7, centro.z),
		Vector3(limites.position.x - 0.6, 1.7, centro.z),
		Vector3(centro.x, 1.7, limites.end.z + 1.0),
	]
	for ojo: Vector3 in ojos:
		var almacen: Node3D = auto_free(ALMACEN.instantiate())
		add_child(almacen)
		AperturaConLugar.abrir_con_todo_el_lugar(almacen)
		var jugador: CharacterBody3D = almacen.get_node("Jugador")
		jugador.set_physics_process(false)
		var camara: Camera3D = jugador.get_node("Giro/Camara")
		var agarre: Agarre = jugador.get("agarre")
		jugador.global_position = ojo - Vector3.UP * 1.7
		camara.look_at(destino)
		await get_tree().physics_frame
		for producto in Catalogo.todos():
			almacen.get("_reposicion_manual").retirar(producto.id)
			var cuerpo: RigidBody3D = agarre.punto_de_producto.get_child(0)
			var orientacion := cuerpo.global_basis
			agarre.soltar(true)
			# Soltar no lo endereza. Salvo lo que queda metido en el cuerpo, que cae derecho al piso
			# al lado del jugador, como la caja: pegado a la góndola, el barrido lo deja en la cara.
			if not cuerpo.global_basis.is_equal_approx(orientacion):
				var inclinado := rad_to_deg(cuerpo.global_basis.y.angle_to(Vector3.UP))
				(
					assert_float(inclinado)
					. override_failure_message(
						"%s se enderezó a %.0f° sin caer al lado" % [producto.nombre, inclinado]
					)
					. is_less(1.0)
				)
				var al_lado := cuerpo.global_position - jugador.global_position
				(
					assert_float(Vector2(al_lado.x, al_lado.z).length())
					. override_failure_message(
						"%s se enderezó a %v del jugador" % [producto.nombre, al_lado]
					)
					. is_less(1.0)
				)
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
			camara.look_at(destino)
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
	var camara: Camera3D = jugador.get_node("Giro/Camara")
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


func test_el_izquierdo_en_el_contenedor_entrega_la_bolsa_al_recolector() -> void:  # AC-CLN-036
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	var bolsa: ObjetoAgarrable = almacen.get_node("Objetos/BolsaDeBasura1")
	var agarre: Agarre = jugador.get("agarre")
	var contenedor: Node3D = almacen.get_node(
		"Estructura/deposito_contenedor_soporte/deposito_contenedor_cuerpo/StaticBody3D"
	)
	assert_bool(agarre.pedir_agarrar(bolsa.datos, bolsa)).is_true()
	jugador.set("_enfocado", contenedor)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	jugador.call("_unhandled_input", clic)
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	assert_bool(recolector.tarea().esta_depositada(bolsa.datos.id)).is_true()
	assert_int(recolector.tarea().depositadas()).is_equal(1)
	assert_object(agarre.manos().sostenido()).is_null()
