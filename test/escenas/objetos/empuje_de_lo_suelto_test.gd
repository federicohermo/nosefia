## Caminar contra lo que está suelto en el piso lo corre: los útiles, las bolsas y la caja.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

## Piso libre del depósito, lejos de los estantes.
const PISO_LIBRE_DEL_DEPOSITO := Vector3(4.49, 0.102, -10.0)

## Desde dónde camina el jugador, en metros detrás de lo que empuja.
const DETRAS_DE_LO_EMPUJADO := 1.2

## Cuadros de física empujando. Arrastrando se camina más lento, y sobran para cruzar el depósito.
const CUADROS_EMPUJANDO := 150

## Cuadros de física para que lo soltado caiga y se asiente.
const CUADROS_ASENTANDO := 90

## Desde qué altura se suelta, sobre el piso, en metros.
const SOLTADO_DESDE := 0.4

## Lo mínimo que tiene que haberse corrido, en metros. Un cuerpo que sigue tapando el paso no se
## corre nada.
const SE_CORRIO := 0.3

## Cuánto se separa de la pared lo que se empuja hacia ella, en metros, y cuánto alcance tiene
## la sonda que la busca.
const SEPARADO_DE_LA_PARED := 0.6
const ALCANCE_DE_LA_SONDA := 12.0

## La pared más cercana que sirve: menos que esto no deja lugar para el jugador.
const PARED_MAS_CERCA := 3.0

## Los útiles de limpieza del cuartito.
const UTILES: Array[String] = ["JabonAzul", "JabonRosa", "JabonAmarillo", "Mopa", "Balde"]


func _almacen_con_jugador_andando() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	add_child(almacen)
	AperturaConLugar.abrir_con_semilla(almacen)
	await get_tree().physics_frame
	return almacen


## Lo deja suelto, vivo y despierto en `lugar`, y espera a que se asiente sobre el piso.
func _soltar_en(cuerpo: ObjetoAgarrable, lugar: Vector3) -> void:
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", true, false):
		forma.disabled = false
	cuerpo.freeze = false
	cuerpo.sleeping = false
	cuerpo.global_basis = Basis.IDENTITY
	cuerpo.global_position = lugar
	cuerpo.linear_velocity = Vector3.ZERO
	cuerpo.angular_velocity = Vector3.ZERO
	cuerpo.reset_physics_interpolation()
	for cuadro in CUADROS_ASENTANDO:
		await get_tree().physics_frame


## Lo saca del camino del caso que sigue.
func _retirar(cuerpo: ObjetoAgarrable) -> void:
	cuerpo.freeze = true
	cuerpo.collision_layer = 0


## Para al jugador detrás de `lugar`, mirando hacia `hacia`.
func _parar_detras_de(jugador: CharacterBody3D, lugar: Vector3, hacia: Vector3) -> void:
	jugador.get_node("Giro").rotation.y = atan2(-hacia.x, -hacia.z)
	jugador.global_position = Vector3(
		lugar.x - hacia.x * DETRAS_DE_LO_EMPUJADO,
		PISO_LIBRE_DEL_DEPOSITO.y + 0.01,
		lugar.z - hacia.z * DETRAS_DE_LO_EMPUJADO
	)
	jugador.velocity = Vector3.ZERO
	await get_tree().physics_frame


## Camina hacia adelante, y devuelve cuánto avanzó el jugador y cuánto se corrió el cuerpo, los
## dos medidos en el sentido del paso.
func _empujar_caminando(
	jugador: CharacterBody3D, cuerpo: Node3D, hacia: Vector3, cuadros: int
) -> Dictionary[String, float]:
	var jugador_antes := jugador.global_position
	var cuerpo_antes := cuerpo.global_position
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	for cuadro in cuadros:
		await get_tree().physics_frame
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)
	await get_tree().physics_frame
	var recorrido: Dictionary[String, float] = {}
	recorrido["jugador"] = (jugador.global_position - jugador_antes).dot(hacia)
	recorrido["cuerpo"] = (cuerpo.global_position - cuerpo_antes).dot(hacia)
	return recorrido


## A qué distancia hay un sólido fijo desde `desde` en la dirección `hacia`, o -1.0 si no hay.
func _distancia_a_la_pared(almacen: Node3D, desde: Vector3, hacia: Vector3) -> float:
	var espacio := almacen.get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(
		desde, desde + hacia * ALCANCE_DE_LA_SONDA, 1
	)
	var tapados: Array[RID] = []
	while true:
		consulta.exclude = tapados
		var golpe := espacio.intersect_ray(consulta)
		if golpe.is_empty():
			return -1.0
		if golpe["collider"] is StaticBody3D:
			return desde.distance_to(golpe["position"])
		tapados.append((golpe["collider"] as CollisionObject3D).get_rid())
	return -1.0


## Cuántos sólidos fijos pisa el cuerpo, con la forma apenas más chica para que apoyarse no cuente.
func _solidos_que_pisa(almacen: Node3D, cuerpo: ObjetoAgarrable) -> Array[String]:
	var pisados: Array[String] = []
	var espacio := almacen.get_world_3d().direct_space_state
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", true, false):
		var menor: Shape3D = forma.shape.duplicate()
		if menor is BoxShape3D:
			(menor as BoxShape3D).size -= Vector3.ONE * ReglasDeLosObjetos.ROCE
		elif menor is CapsuleShape3D:
			(menor as CapsuleShape3D).radius -= ReglasDeLosObjetos.ROCE
		elif menor is CylinderShape3D:
			(menor as CylinderShape3D).radius -= ReglasDeLosObjetos.ROCE
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = menor
		consulta.transform = forma.global_transform
		consulta.collision_mask = cuerpo.collision_mask
		consulta.exclude = [cuerpo.get_rid()]
		for choque in espacio.intersect_shape(consulta, 8):
			if choque["collider"] is StaticBody3D:
				pisados.append(str(almacen.get_path_to(choque["collider"])))
	return pisados


func test_un_util_suelto_se_corre_al_caminar_contra_el() -> void:  # AC-PLY-150
	var almacen: Node3D = await _almacen_con_jugador_andando()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	for nombre in UTILES:
		var util: ObjetoAgarrable = almacen.get_node("Objetos/" + nombre)
		var lugar := PISO_LIBRE_DEL_DEPOSITO + Vector3.UP * SOLTADO_DESDE
		await _soltar_en(util, lugar)
		await _parar_detras_de(jugador, util.global_position, Vector3.FORWARD)
		var recorrido := await _empujar_caminando(jugador, util, Vector3.FORWARD, CUADROS_EMPUJANDO)
		(
			assert_float(recorrido["cuerpo"])
			. override_failure_message("%s no se corrió: %v" % [nombre, recorrido])
			. is_greater(SE_CORRIO)
		)
		(
			assert_float(recorrido["jugador"] - recorrido["cuerpo"])
			. override_failure_message("%s le ganó al jugador: %v" % [nombre, recorrido])
			. is_greater(0.0)
		)
		_retirar(util)


func test_una_bolsa_suelta_se_corre_al_caminar_contra_ella() -> void:  # AC-PLY-151
	var almacen: Node3D = await _almacen_con_jugador_andando()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var bolsa: ObjetoAgarrable = (almacen.get("_bolsas") as Array)[0]
	await _soltar_en(bolsa, PISO_LIBRE_DEL_DEPOSITO + Vector3.UP * SOLTADO_DESDE)
	await _parar_detras_de(jugador, bolsa.global_position, Vector3.FORWARD)
	var recorrido := await _empujar_caminando(jugador, bolsa, Vector3.FORWARD, CUADROS_EMPUJANDO)
	(
		assert_float(recorrido["cuerpo"])
		. override_failure_message("la bolsa no se corrió: %v" % [recorrido])
		. is_greater(SE_CORRIO)
	)
	(
		assert_float(recorrido["jugador"] - recorrido["cuerpo"])
		. override_failure_message("la bolsa le ganó al jugador: %v" % [recorrido])
		. is_greater(0.0)
	)


func test_lo_empujado_contra_una_pared_no_la_atraviesa() -> void:  # AC-PLY-152
	var almacen: Node3D = await _almacen_con_jugador_andando()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	# La pared sale de la escena: de las cuatro direcciones, la más cercana que deja lugar.
	var desde := PISO_LIBRE_DEL_DEPOSITO + Vector3.UP * SOLTADO_DESDE
	var hacia := Vector3.ZERO
	var distancia := INF
	for sentido: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var a_la_pared := _distancia_a_la_pared(almacen, desde, sentido)
		if a_la_pared >= PARED_MAS_CERCA and a_la_pared < distancia:
			distancia = a_la_pared
			hacia = sentido
	assert_bool(hacia != Vector3.ZERO).override_failure_message("no hay pared a mano").is_true()
	var pegado := desde + hacia * (distancia - SEPARADO_DE_LA_PARED)
	var cuerpos: Array[ObjetoAgarrable] = []
	cuerpos.append(almacen.get_node("Objetos/Balde"))
	cuerpos.append((almacen.get("_bolsas") as Array)[0])
	for cuerpo in cuerpos:
		await _soltar_en(cuerpo, pegado)
		await _parar_detras_de(jugador, cuerpo.global_position, hacia)
		await _empujar_caminando(jugador, cuerpo, hacia, CUADROS_EMPUJANDO)
		await get_tree().physics_frame
		assert_array(_solidos_que_pisa(almacen, cuerpo)).is_empty()
		_retirar(cuerpo)


func test_la_caja_recibe_la_parte_del_paso_que_declara_el_dominio() -> void:  # AC-PLY-153
	var almacen: Node3D = await _almacen_con_jugador_andando()
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.CHISITOS]
	caja.global_position = (
		PISO_LIBRE_DEL_DEPOSITO + Vector3.UP * (caja.global_position.y - PISO_LIBRE_DEL_DEPOSITO.y)
	)
	var antes := caja.global_position
	var paso := Vector3(0.0, 0.2, -0.1)
	caja.call(ReglasDeLosObjetos.METODO_EMPUJAR, paso)
	var esperado := Vector3(paso.x, 0.0, paso.z) * ReglasDeLosObjetos.ARRASTRE_DE_LA_CAJA
	assert_vector(caja.global_position - antes).is_equal_approx(esperado, Vector3.ONE * 0.001)
