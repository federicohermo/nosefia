extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const BolsaEnLaMano := preload("res://test/escenas/bolsa_en_la_mano.gd")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
const LadosDelMueble := preload("res://test/escenas/lados_del_mueble.gd")
## Los lados horizontales de un mueble.
const CARAS_DE_UN_MUEBLE := 4
## A cuánto de la cara se para quien suelta hacia el costado, y hacia la cabecera.
const DISTANCIA_AL_COSTADO := 0.6
const DISTANCIA_A_LA_CABECERA := 1.0


func test_soltar_hacia_la_gondola_deja_el_producto_visible_y_recuperable() -> void:
	var probados := {"costado": 0, "cabecera": 0}
	for indice in CARAS_DE_UN_MUEBLE:
		var almacen: Node3D = auto_free(ALMACEN.instantiate())
		almacen.set(
			"_partida",
			Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
		)
		add_child(almacen)
		await get_tree().physics_frame
		# Cada cara con lugar para pararse: los costados, y una cabecera.
		var malla := almacen.get_node("Estructura/gondolanueva") as MeshInstance3D
		var lado := LadosDelMueble.lados(malla)[indice]
		var clase := "cabecera" if lado.de_cabecera else "costado"
		var distancia := DISTANCIA_A_LA_CABECERA if lado.de_cabecera else DISTANCIA_AL_COSTADO
		var pie := LadosDelMueble.pie_junto_a(malla, lado, distancia)
		if not LadosDelMueble.cabe_parado(almacen, pie):
			continue
		if lado.de_cabecera and probados[clase] > 0:
			continue
		probados[clase] += 1
		var centro := LadosDelMueble.pieza(malla).get_center()
		var destino := Vector3(centro.x, 1.7, centro.z)
		AperturaConLugar.abrir_con_todo_el_lugar(almacen)
		var jugador: CharacterBody3D = almacen.get_node("Jugador")
		jugador.set_physics_process(false)
		var camara: Camera3D = jugador.get_node("Giro/Camara")
		var agarre: Agarre = jugador.get("agarre")
		jugador.global_position = Vector3(pie.x, 0.0, pie.z)
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
						% [producto.nombre, pie, cuerpo.global_position]
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
	# Una góndola contra la pared no tiene por qué dejar lugar junto a sus cabeceras.
	(
		assert_int(probados["costado"] + probados["cabecera"])
		. override_failure_message("ninguna cara de la góndola tiene lugar para pararse")
		. is_greater(0)
	)


func test_la_bolsa_sostenida_no_desplaza_al_jugador() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var bolsa := BolsaEnLaMano.preparar(almacen)
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
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	var bolsa := BolsaEnLaMano.preparar(almacen)
	var agarre: Agarre = jugador.get("agarre")
	var contenedor: Node3D = almacen.get_node(
		(
			"Estructura/deposito_contenedor_grande_soporte/"
			+ "deposito_contenedor_grande_cuerpo/StaticBody3D"
		)
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
