## La hoja de una puerta que gira arrastra lo suelto que tiene adelante, y quieta no deja nada
## adentro de ella.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## La hoja que se mide: la del paso al fondo, que abre hacia el cuarto de atrás.
const HOJA := "Estructura/puerta"

## Dónde va la unidad en el recorrido: a qué distancia de la bisagra y a qué fracción del giro.
const RADIO_EN_EL_RECORRIDO := 1.0
const FRACCION_DEL_GIRO := 0.5

## Cuadros de física hasta que la hoja haga el giro entero y lo arrastrado se acomode.
const CUADROS_DEL_GIRO := 150

## Cuadros para que una unidad soltada en el piso se duerma.
const CUADROS_PARA_DORMIRSE := 120

## Cuánto tiene que haberse corrido lo arrastrado en el sentido del giro, en metros.
const CORRIDA_MINIMA := 0.05

const PRODUCTO := Producto.Id.MALBARDO

## Cuánto deja el motor que un cuerpo vivo apoyado se hunda en lo que toca.
const PENETRACION_TOLERADA := "physics/jolt_physics_3d/simulation/penetration_slop"
const PRODUCTO_DE_LA_CAJA := Producto.Id.CHISITOS


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	return almacen


## El cuerpo de la hoja: el hijo de la malla que contesta en qué estado está la puerta.
func _cuerpo_de(hoja: Node3D) -> PhysicsBody3D:
	for hijo in hoja.get_children():
		if hijo.has_method("puerta"):
			return hijo
	return null


## La bisagra en el mundo: el borde de menor X de la hoja cerrada.
func _bisagra(hoja: MeshInstance3D) -> Vector3:
	return hoja.global_transform * Vector3(hoja.get_aabb().position.x, 0.0, 0.0)


## Un punto del piso en el recorrido de la hoja, a `fraccion` del cuarto de vuelta.
func _en_el_recorrido(almacen: Node3D, hoja: MeshInstance3D, fraccion: float) -> Vector3:
	var bisagra := _bisagra(hoja)
	var brazo := (hoja.global_transform.basis.x * Vector3(1.0, 0.0, 1.0)).normalized()
	var giro := Basis(Vector3.UP, Puerta.ANGULO_ABIERTA * fraccion)
	var punto := bisagra + giro * brazo * RADIO_EN_EL_RECORRIDO
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	punto.y = suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0
	return punto


## Hacia dónde empuja la hoja en ese punto cuando abre.
func _sentido_del_giro(hoja: MeshInstance3D, punto: Vector3) -> Vector3:
	var radio := punto - _bisagra(hoja)
	radio.y = 0.0
	return Vector3.UP.cross(radio).normalized()


## Una unidad dormida, apoyada en el piso en `punto`.
func _unidad_dormida(almacen: Node3D, punto: Vector3) -> RigidBody3D:
	var agarre: Agarre = almacen.get("_agarre")
	almacen.get("_reposicion_manual").call("retirar", PRODUCTO)
	var unidad: RigidBody3D = agarre.soltar(true)
	unidad.global_basis = Basis.IDENTITY
	unidad.global_position = punto + Vector3.UP * 0.15
	unidad.linear_velocity = Vector3.ZERO
	for cuadro in CUADROS_PARA_DORMIRSE:
		await get_tree().physics_frame
	return unidad


## Si el cuerpo se hunde en la hoja más de lo que el motor tolera a un cuerpo vivo apoyado.
##
## La profundidad sale de los pares de contacto con la hoja sola. La de `body_test_motion` es lo
## que sobra después de sacar al cuerpo: una unidad metida entera daba 2 cm. Medido el 2026-09-26.
func _adentro_de_la_hoja(cuerpo: PhysicsBody3D, hoja: PhysicsBody3D) -> bool:
	var tolerado: float = (
		ReglasDeLosObjetos.ROCE + ProjectSettings.get_setting(PENETRACION_TOLERADA, 0.0)
	)
	var espacio := cuerpo.get_world_3d().direct_space_state
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		if forma.disabled:
			continue
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		var otros: Array[RID] = [cuerpo.get_rid()]
		for golpe in espacio.intersect_shape(consulta, 32):
			if golpe["collider"] != hoja:
				otros.append(golpe["rid"])
		consulta.exclude = otros
		var pares := espacio.collide_shape(consulta, 16)
		for indice in range(0, pares.size(), 2):
			if pares[indice].distance_to(pares[indice + 1]) > tolerado:
				return true
	return false


func _girar(hoja: Node3D) -> void:
	_cuerpo_de(hoja).call("interactuar")
	for cuadro in CUADROS_DEL_GIRO:
		await get_tree().physics_frame


func test_la_unidad_dormida_en_el_recorrido_se_arrastra_al_abrir() -> void:  # AC-PLY-030
	var almacen: Node3D = await _almacen()
	var hoja: MeshInstance3D = almacen.get_node(HOJA)
	var punto := _en_el_recorrido(almacen, hoja, FRACCION_DEL_GIRO)
	var unidad := await _unidad_dormida(almacen, punto)
	assert_bool(unidad.sleeping).override_failure_message("la unidad no se durmió").is_true()
	var desperto := [false]
	unidad.sleeping_state_changed.connect(
		func() -> void: desperto[0] = desperto[0] or not unidad.sleeping
	)
	var partida := unidad.global_position
	await _girar(hoja)
	var cuerpo := _cuerpo_de(hoja)
	(
		assert_bool(_adentro_de_la_hoja(unidad, cuerpo))
		. override_failure_message(
			"la unidad quedó adentro de la hoja en %v" % unidad.global_position
		)
		. is_false()
	)
	var corrida := (unidad.global_position - partida).dot(_sentido_del_giro(hoja, partida))
	(
		assert_float(corrida)
		. override_failure_message("la hoja no arrastró la unidad: se corrió %.3f m" % corrida)
		. is_greater(CORRIDA_MINIMA)
	)
	assert_bool(desperto[0]).override_failure_message("la unidad no se despertó").is_true()


func test_la_unidad_dormida_en_el_recorrido_se_arrastra_al_cerrar() -> void:  # AC-PLY-031
	var almacen: Node3D = await _almacen()
	var hoja: MeshInstance3D = almacen.get_node(HOJA)
	var punto := _en_el_recorrido(almacen, hoja, FRACCION_DEL_GIRO)
	var cerrada := hoja.global_transform
	await _girar(hoja)
	var unidad := await _unidad_dormida(almacen, punto)
	assert_bool(unidad.sleeping).override_failure_message("la unidad no se durmió").is_true()
	var partida := unidad.global_position
	await _girar(hoja)
	assert_bool(_adentro_de_la_hoja(unidad, _cuerpo_de(hoja))).is_false()
	assert_bool(hoja.global_transform.is_equal_approx(cerrada)).is_true()
	var corrida := (unidad.global_position - partida).dot(-_sentido_del_giro(hoja, partida))
	(
		assert_float(corrida)
		. override_failure_message("la hoja no arrastró la unidad al cerrar: %.3f m" % corrida)
		. is_greater(CORRIDA_MINIMA)
	)


## Lo que quedó adentro de la hoja al terminar el giro lo saca la red cuando la hoja queda
## quieta. Se lo pone congelado donde va a quedar la hoja, justo antes del último paso.
func test_al_quedar_quieta_no_queda_nada_adentro_de_la_hoja() -> void:  # AC-PLY-032
	var almacen: Node3D = await _almacen()
	var hoja: MeshInstance3D = almacen.get_node(HOJA)
	var punto := _en_el_recorrido(almacen, hoja, 1.0)
	var unidad := await _unidad_dormida(almacen, punto + Vector3.UP * 2.0)
	unidad.freeze = true
	var cuerpo := _cuerpo_de(hoja)
	var quieta := [false]
	cuerpo.connect("hoja_quieta", func(_hoja: PhysicsBody3D) -> void: quieta[0] = true)
	cuerpo.call("interactuar")
	while not cuerpo.call("puerta").angulo() > Puerta.ANGULO_ABIERTA * 0.9:
		await get_tree().physics_frame
	unidad.global_position = punto + Vector3.UP * 0.1
	for cuadro in CUADROS_DEL_GIRO:
		await get_tree().physics_frame
	assert_bool(quieta[0]).override_failure_message("la hoja no avisó que quedó quieta").is_true()
	(
		assert_bool(_adentro_de_la_hoja(unidad, cuerpo))
		. override_failure_message(
			"la unidad quedó adentro de la hoja en %v" % unidad.global_position
		)
		. is_false()
	)
	var red: RedDeSeguridad = almacen.get_node("Servicios/RedDeSeguridad")
	assert_int(red.rescates.size()).is_equal(1)


## M2: el jugador parado en el recorrido. Lo saca la recuperación de su propio movimiento.
func test_el_jugador_parado_en_el_recorrido_no_queda_adentro_de_la_hoja() -> void:
	var almacen: Node3D = await _almacen()
	var hoja: MeshInstance3D = almacen.get_node(HOJA)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.global_position = _en_el_recorrido(almacen, hoja, FRACCION_DEL_GIRO) + Vector3.UP * 0.01
	await _girar(hoja)
	(
		assert_bool(_adentro_de_la_hoja(jugador, _cuerpo_de(hoja)))
		. override_failure_message(
			"la cápsula quedó adentro de la hoja en %v" % jugador.global_position
		)
		. is_false()
	)


## Una caja apoyada no frena la hoja: llega a su tope igual. Es provisorio: lo cambia la regla
## del peso.
func test_una_caja_apoyada_en_el_recorrido_no_frena_la_hoja() -> void:
	var almacen: Node3D = await _almacen()
	var hoja: MeshInstance3D = almacen.get_node(HOJA)
	var caja: Node3D = almacen.get("_cajas_de_productos")[PRODUCTO_DE_LA_CAJA]
	caja.global_position = _en_el_recorrido(almacen, hoja, FRACCION_DEL_GIRO) + Vector3.UP * 0.31
	caja.call("quedarse_quieta")
	await _girar(hoja)
	assert_float(_cuerpo_de(hoja).call("puerta").angulo()).is_equal(Puerta.ANGULO_ABIERTA)


## Cerrar de golpe salta sin girar: lo apoyado contra la hoja abierta no sale despedido.
func test_cerrar_de_golpe_no_despide_lo_que_toca_la_hoja() -> void:
	var almacen: Node3D = await _almacen()
	var hoja: MeshInstance3D = almacen.get_node(HOJA)
	var punto := _en_el_recorrido(almacen, hoja, 0.9)
	await _girar(hoja)
	var unidad := await _unidad_dormida(almacen, punto)
	var partida := unidad.global_position
	_cuerpo_de(hoja).call("cerrar_de_golpe")
	for cuadro in CUADROS_PARA_DORMIRSE:
		await get_tree().physics_frame
	var corrida := unidad.global_position.distance_to(partida)
	(
		assert_float(corrida)
		. override_failure_message("la hoja despidió la unidad: se corrió %.3f m" % corrida)
		. is_less(CORRIDA_MINIMA)
	)


func test_la_bolsa_en_el_recorrido_se_arrastra_al_abrir() -> void:
	assert_float(await _corrida_al_abrir("Objetos/BolsaDeBasura1")).is_greater(CORRIDA_MINIMA)


func test_el_trapeador_en_el_recorrido_se_arrastra_al_abrir() -> void:
	assert_float(await _corrida_al_abrir("Objetos/Trapeador")).is_greater(CORRIDA_MINIMA)


## Cuánto corre la hoja al abrir al objeto que se le pone en el recorrido. Un almacén por objeto:
## dos a la vez comparten el mundo, y la red de uno vigila los cuerpos del otro.
func _corrida_al_abrir(ruta: String) -> float:
	var almacen: Node3D = await _almacen()
	var hoja: MeshInstance3D = almacen.get_node(HOJA)
	var objeto: RigidBody3D = almacen.get_node(ruta)
	objeto.global_basis = Basis.IDENTITY
	objeto.global_position = _en_el_recorrido(almacen, hoja, FRACCION_DEL_GIRO) + Vector3.UP * 0.15
	for cuadro in CUADROS_PARA_DORMIRSE:
		await get_tree().physics_frame
	var partida := objeto.global_position
	await _girar(hoja)
	assert_bool(_adentro_de_la_hoja(objeto, _cuerpo_de(hoja))).is_false()
	return (objeto.global_position - partida).dot(_sentido_del_giro(hoja, partida))
