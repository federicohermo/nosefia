## Caminar contra una unidad de producto tirada en el piso la corre hacia el costado del camino,
## sin frenar al jugador y sin meterla adentro de nada.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

## Piso libre del depósito, lejos de los estantes.
const PISO_LIBRE_DEL_DEPOSITO := Vector3(4.49, 0.102, -10.0)

## El producto cuya unidad se patea: uno cualquiera con unidades en la góndola.
const PRODUCTO_QUE_SE_PATEA := Producto.Id.MALBARDO

## Hacia dónde mira quien suelta algo en el piso, en grados: la mira cae en el piso, adelante.
const MIRANDO_ABAJO := -40.0

## Desde qué altura sobre el piso se deja la unidad, en metros.
const ALTURA_DE_SOLTADO := 0.1

## Cuánto antes de la unidad arranca el jugador, en metros.
const DETRAS_DE_LA_UNIDAD := 1.2

## Cuánto se aparta el camino del jugador del centro de la unidad, hacia el lado opuesto al
## sólido, en metros. Más que el radio del cuerpo, para que no toque el sólido, y menos que el
## radio de los pies, para que la pise.
const APARTADO_DEL_SOLIDO := 0.45

## Cuadros de física caminando. A 60 Hz es un segundo: se cruza la unidad y sobra.
const CUADROS_CAMINANDO := 60

## Cuadros de física para que lo soltado caiga y se asiente, y para que lo pateado frene.
const CUADROS_ASENTANDO := 90

## Cuánto se mueve la unidad hacia el sólido para quedar pegada a él, en metros por segundo.
const EMPUJON_CONTRA_EL_SOLIDO := 1.5

## A cuánto del sólido se deja la unidad antes de pegarla, y cuánto alcance tiene la sonda que lo
## busca, en metros.
const SEPARADA_DEL_SOLIDO := 0.4
const ALCANCE_DE_LA_SONDA := 12.0

## Lo mínimo de pared que tiene que haber para que el caso tenga un sólido, y de recorrido libre
## para que el jugador camine sin chocar con nada, en metros.
const PARED_MAS_CERCA := 1.5
const RECORRIDO_LIBRE := 2.0

## Cuadros caminando junto a un sólido: 1,75 m a 60 Hz, lo que pide pasar la unidad desde donde
## arranca el jugador sin salir del pasillo.
const CUADROS_JUNTO_AL_SOLIDO := 30

## Lo mismo en un pasillo angosto: el jugador arranca más cerca de la unidad, que igual lo pisa, y
## camina menos, en metros y en cuadros. Los pies llegan a 0,55 m del jugador.
const DETRAS_DE_LA_UNIDAD_EN_EL_PASILLO := 0.8
const CUADROS_EN_EL_PASILLO := 20
const RECORRIDO_EN_EL_PASILLO := 1.3

## Cuántas veces se empuja la unidad contra el sólido hasta que deja de avanzar, y cuánto es dejar
## de avanzar, en metros.
const INTENTOS_DE_PEGAR := 8
const YA_NO_AVANZA := 0.005

## Lo mínimo que se corre de costado la unidad pateada, en metros.
const SE_CORRIO := 0.05

## Cuánto puede moverse una unidad acorralada, y cuánto subir una pateada contra un mueble, en
## metros.
const SIN_MOVERSE := 0.05
const SIN_SUBIR := 0.1

## Cuánto se aparta la unidad de la cara del mueble antes de patearla, en metros.
const APARTADA_DEL_MUEBLE := 0.4

## Lo que mide de lado una caja grande, partido por dos, en metros.
const MEDIA_CAJA := 0.3037

## Cuánto se acepta que difiera lo caminado de lo esperado, como fracción.
const MARGEN_DEL_AVANCE := 0.06

## Cuánto se hunde un cuerpo vivo apoyado antes de contar como adentro, según el motor.
const PENETRACION_TOLERADA := "physics/jolt_physics_3d/simulation/penetration_slop"


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA, "medios": 0})
	)
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	return almacen


func _piso(almacen: Node3D) -> float:
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	return suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0


## Gira la vista como lo haría el mouse, a un yaw y un pitch absolutos en radianes.
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


func _apuntar(jugador: Node3D, punto: Vector3) -> void:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var hacia := punto - camara.global_position
	_mirar(jugador, atan2(-hacia.x, -hacia.z), atan2(hacia.y, Vector2(hacia.x, hacia.z).length()))


## Le pone el foco al objetivo y le manda la acción, que es lo que hace el clic de verdad.
func _accion(jugador: Node3D, objetivo: Node3D, accion: StringName) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _asentar(cuadros: int = CUADROS_ASENTANDO) -> void:
	for cuadro in cuadros:
		await get_tree().physics_frame


## Una unidad del producto, suelta y despierta sobre el piso en `lugar`. La suelta el gesto de
## verdad, con la mira en el piso, y después se la lleva adonde el caso la necesita.
func _unidad_suelta_en(almacen: Node3D, lugar: Vector3) -> RigidBody3D:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var puesto: Node3D = almacen.get("_reposicion_manual")
	puesto.call("retirar", PRODUCTO_QUE_SE_PATEA)
	var en_la_mano := agarre.manos().sostenido()
	assert_object(en_la_mano).override_failure_message("no salió ninguna unidad").is_not_null()
	if en_la_mano == null:
		return null
	var unidad := agarre.punto_de_producto.get_child(0) as RigidBody3D
	jugador.global_position = PISO_LIBRE_DEL_DEPOSITO + Vector3.UP * 0.01
	jugador.velocity = Vector3.ZERO
	_mirar(jugador, 0.0, deg_to_rad(MIRANDO_ABAJO))
	await get_tree().physics_frame
	_accion(jugador, unidad, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.manos().sostenido()).override_failure_message("no la soltó").is_null()
	unidad.global_position = lugar
	unidad.global_basis = Basis.IDENTITY
	unidad.linear_velocity = Vector3.ZERO
	unidad.angular_velocity = Vector3.ZERO
	unidad.sleeping = false
	unidad.reset_physics_interpolation()
	await _asentar()
	return unidad


## El lugar libre del depósito donde se deja la unidad, sobre el piso.
func _lugar_libre(almacen: Node3D) -> Vector3:
	return Vector3(
		PISO_LIBRE_DEL_DEPOSITO.x, _piso(almacen) + ALTURA_DE_SOLTADO, PISO_LIBRE_DEL_DEPOSITO.z
	)


## Camina `cuadros` cuadros hacia `camino` desde el piso bajo `desde`, y devuelve cuánto avanzó
## el jugador en ese sentido y la menor velocidad horizontal que tuvo.
func _caminar(
	jugador: CharacterBody3D, desde: Vector3, camino: Vector3, cuadros: int
) -> Dictionary[String, float]:
	jugador.global_position = Vector3(desde.x, jugador.global_position.y, desde.z)
	jugador.velocity = Vector3.ZERO
	_mirar(jugador, atan2(-camino.x, -camino.z), 0.0)
	await get_tree().physics_frame
	var inicio := jugador.global_position
	var velocidad_minima := INF
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	for cuadro in cuadros:
		await get_tree().physics_frame
		velocidad_minima = minf(
			velocidad_minima, Vector2(jugador.velocity.x, jugador.velocity.z).length()
		)
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)
	await get_tree().physics_frame
	var marcha: Dictionary[String, float] = {}
	marcha["avance"] = (jugador.global_position - inicio).dot(camino)
	marcha["velocidad_minima"] = velocidad_minima
	return marcha


func _avance_esperado(cuadros: int) -> float:
	return ReglasDelJugador.VELOCIDAD_DE_CAMINATA * cuadros / Engine.physics_ticks_per_second


## A qué distancia hay un sólido fijo desde `desde` en la dirección `hacia`, o -1.0 si no hay.
func _distancia_al_solido(almacen: Node3D, desde: Vector3, hacia: Vector3) -> float:
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


## Si el cuerpo del jugador, parado en `desde`, camina `RECORRIDO_LIBRE` metros hacia `camino` sin
## tocar nada. Lo mide el propio cuerpo, con su forma entera y no con un rayo a ras del piso.
func _recorrido_libre(
	jugador: CharacterBody3D, desde: Vector3, camino: Vector3, metros: float = RECORRIDO_LIBRE
) -> bool:
	var parado := Transform3D(Basis.IDENTITY, Vector3(desde.x, jugador.global_position.y, desde.z))
	return not jugador.test_move(parado, camino * metros)


## Con qué choca el cuerpo del jugador al caminar `metros` hacia `camino` desde `desde`: para que
## un caso sin recorrido libre diga qué lo tapa.
func _lo_que_tapa(
	jugador: CharacterBody3D, desde: Vector3, camino: Vector3, metros: float
) -> String:
	var parado := Transform3D(Basis.IDENTITY, Vector3(desde.x, jugador.global_position.y, desde.z))
	var choque := KinematicCollision3D.new()
	if not jugador.test_move(parado, camino * metros, choque):
		return "nada"
	var tapa := choque.get_collider() as Node
	return "%s en %v" % ["?" if tapa == null else tapa.name, choque.get_position()]


## Los sólidos fijos que el cuerpo pisa de verdad, sin contar lo que se hunde apoyado. Un cuerpo
## vivo se hunde un poco en lo que lo sostiene y el motor lo tolera hasta su margen.
func _solidos_que_pisa(cuerpo: RigidBody3D) -> Array[String]:
	var tolerado: float = (
		ReglasDeLosObjetos.ROCE + ProjectSettings.get_setting(PENETRACION_TOLERADA, 0.0)
	)
	var prueba := PhysicsTestMotionParameters3D.new()
	prueba.from = cuerpo.global_transform
	prueba.max_collisions = 32
	prueba.recovery_as_collision = true
	var resultado := PhysicsTestMotionResult3D.new()
	PhysicsServer3D.body_test_motion(cuerpo.get_rid(), prueba, resultado)
	var pisados: Array[String] = []
	for indice in resultado.get_collision_count():
		var sacado := resultado.get_travel().dot(resultado.get_collision_normal(indice))
		var hondo := resultado.get_collision_depth(indice) + sacado
		var solido := resultado.get_collider(indice) as StaticBody3D
		if solido != null and hondo > tolerado:
			pisados.append("%s (%.3f m)" % [solido.name, hondo])
	return pisados


## La red de seguridad no tuvo que rescatar nada: un verde con rescates escondería una prevención
## rota detrás de la red.
func _comprobar_sin_rescates(almacen: Node3D, donde: String) -> void:
	var red: RedDeSeguridad = almacen.get_node("Servicios/RedDeSeguridad")
	var avisos: Array[String] = []
	for rescate: Dictionary in red.rescates:
		avisos.append(str(rescate["aviso"]))
	(
		assert_array(red.rescates)
		. override_failure_message(
			"%s, la red tuvo que rescatar: la prevención falló. %s" % [donde, " | ".join(avisos)]
		)
		. is_empty()
	)


## Que la unidad no quede adentro de ningún sólido, que la red no haya rescatado nada y que la
## mira la enfoque parado en `desde`.
func _comprobar_libre_y_enfocable(
	almacen: Node3D, unidad: RigidBody3D, desde: Vector3, donde: String
) -> void:
	_comprobar_sin_rescates(almacen, donde)
	var pisados := _solidos_que_pisa(unidad)
	(
		assert_array(pisados)
		. override_failure_message("%s, quedó adentro de %s" % [donde, ", ".join(pisados)])
		. is_empty()
	)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.global_position = Vector3(desde.x, jugador.global_position.y, desde.z)
	_apuntar(jugador, unidad.global_position)
	await get_tree().physics_frame
	var candidato: CampoDeInteraccion.Candidato = jugador.call("_medir_candidato", unidad)
	var enfocable := (
		candidato.visible and candidato.distancia <= ReglasDelJugador.ALCANCE_DE_LA_MIRA
	)
	(
		assert_bool(enfocable)
		. override_failure_message(
			(
				"%s, la mira no la enfoca desde %v: está en %v, a %.2f m"
				% [donde, desde, unidad.global_position, candidato.distancia]
			)
		)
		. is_true()
	)


## Lo que se corrió la unidad, con el jugador y la unidad ya quietos.
func _comprobar_corrida_de_costado(
	jugador: Node3D,
	unidad: Node3D,
	antes: Vector3,
	camino: Vector3,
	marcha: Dictionary[String, float]
) -> Vector3:
	var desplazamiento := unidad.global_position - antes
	var costado := camino.cross(Vector3.UP).normalized()
	(
		assert_float(marcha["velocidad_minima"])
		. override_failure_message("el jugador perdió velocidad al pisarla: %s" % [marcha])
		. is_equal_approx(ReglasDelJugador.VELOCIDAD_DE_CAMINATA, 0.05)
	)
	(
		assert_float(marcha["avance"])
		. override_failure_message("el jugador avanzó menos de lo que camina: %s" % [marcha])
		. is_equal_approx(
			_avance_esperado(CUADROS_CAMINANDO),
			_avance_esperado(CUADROS_CAMINANDO) * MARGEN_DEL_AVANCE
		)
	)
	(
		assert_float(absf(desplazamiento.dot(costado)))
		. override_failure_message("no se corrió de costado: %v" % [desplazamiento])
		. is_greater(SE_CORRIO)
	)
	(
		assert_float(absf(desplazamiento.dot(camino)))
		. override_failure_message("se fue hacia adelante como una pelota: %v" % [desplazamiento])
		. is_less(absf(desplazamiento.dot(costado)))
	)
	(
		assert_float(desplazamiento.length())
		. override_failure_message("se corrió más de lo que alcanza la mira: %v" % [desplazamiento])
		. is_less(ReglasDelJugador.ALCANCE_DE_LA_MIRA)
	)
	assert_float(absf(desplazamiento.y)).is_less(SIN_SUBIR)
	(
		assert_float((unidad.global_position - jugador.global_position).dot(camino))
		. override_failure_message("la unidad quedó adelante del jugador")
		. is_less(0.0)
	)
	return desplazamiento


func test_caminar_contra_una_unidad_la_corre_sin_frenar_al_jugador() -> void:  # AC-PLY-155
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var camino := Vector3.FORWARD
	var unidad := await _unidad_suelta_en(almacen, _lugar_libre(almacen))
	var antes := unidad.global_position
	var desde := antes - camino * DETRAS_DE_LA_UNIDAD
	var marcha := await _caminar(jugador, desde, camino, CUADROS_CAMINANDO)
	await _asentar()
	var corrida := _comprobar_corrida_de_costado(jugador, unidad, antes, camino, marcha)
	assert_float(corrida.length()).is_greater(SE_CORRIO)
	await _comprobar_libre_y_enfocable(almacen, unidad, desde, "la unidad pateada")


func test_el_jugador_quieto_sobre_la_unidad_no_la_mueve() -> void:  # AC-PLY-155
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var unidad := await _unidad_suelta_en(almacen, _lugar_libre(almacen))
	var antes := unidad.global_position
	jugador.global_position = Vector3(antes.x, jugador.global_position.y, antes.z)
	jugador.velocity = Vector3.ZERO
	await _asentar()
	assert_vector(unidad.global_position).is_equal_approx(antes, Vector3.ONE * SIN_MOVERSE)


## Empuja la unidad contra el sólido hasta que ya no avanza: el roce la frena antes de llegar.
func _pegar_al_solido(unidad: RigidBody3D, hacia: Vector3) -> void:
	var avanzo := INF
	for intento in INTENTOS_DE_PEGAR:
		var antes := unidad.global_position
		unidad.linear_velocity = hacia * EMPUJON_CONTRA_EL_SOLIDO
		await _asentar(30)
		avanzo = unidad.global_position.distance_to(antes)
		if avanzo < YA_NO_AVANZA:
			return
	assert_float(avanzo).override_failure_message("no quedó pegada al sólido").is_less(YA_NO_AVANZA)


func test_una_unidad_acorralada_contra_la_pared_no_se_mueve() -> void:  # AC-PLY-156
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var desde := _lugar_libre(almacen)
	var hacia_el_solido := Vector3.ZERO
	var camino := Vector3.ZERO
	var a_la_pared := 0.0
	for sentido: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var distancia := _distancia_al_solido(almacen, desde, sentido)
		if distancia < PARED_MAS_CERCA:
			continue
		for paralelo: Vector3 in [
			sentido.rotated(Vector3.UP, PI / 2.0), sentido.rotated(Vector3.UP, -PI / 2.0)
		]:
			var salida := (
				desde
				+ sentido * (distancia - SEPARADA_DEL_SOLIDO - APARTADO_DEL_SOLIDO)
				- paralelo * DETRAS_DE_LA_UNIDAD
			)
			if hacia_el_solido == Vector3.ZERO and _recorrido_libre(jugador, salida, paralelo):
				hacia_el_solido = sentido
				camino = paralelo
				a_la_pared = distancia
	(
		assert_bool(hacia_el_solido != Vector3.ZERO)
		. override_failure_message("no hay pared a mano")
		. is_true()
	)
	if hacia_el_solido == Vector3.ZERO:
		return
	var lugar := desde + hacia_el_solido * (a_la_pared - SEPARADA_DEL_SOLIDO)
	var unidad := await _unidad_suelta_en(almacen, lugar)
	# Se la pega a la pared antes de pisarla: acorralada es la que ya no tiene adónde ir.
	await _pegar_al_solido(unidad, hacia_el_solido)
	var antes := unidad.global_position
	var arranque := antes - hacia_el_solido * APARTADO_DEL_SOLIDO - camino * DETRAS_DE_LA_UNIDAD
	var marcha := await _caminar(jugador, arranque, camino, CUADROS_JUNTO_AL_SOLIDO)
	await _asentar()
	(
		assert_float(marcha["avance"])
		. override_failure_message("el jugador no atravesó la unidad: %s" % [marcha])
		. is_greater(_avance_esperado(CUADROS_JUNTO_AL_SOLIDO) * (1.0 - MARGEN_DEL_AVANCE))
	)
	assert_float((jugador.global_position - unidad.global_position).dot(camino)).is_greater(0.0)
	(
		assert_vector(unidad.global_position)
		. override_failure_message(
			"la unidad acorralada se movió: %v" % [unidad.global_position - antes]
		)
		. is_equal_approx(antes, Vector3.ONE * SIN_MOVERSE)
	)
	await _comprobar_libre_y_enfocable(almacen, unidad, arranque, "la unidad acorralada")


func test_con_una_caja_en_la_mano_la_unidad_tambien_se_patea() -> void:  # AC-PLY-157
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var camino := Vector3.FORWARD
	var unidad := await _unidad_suelta_en(almacen, _lugar_libre(almacen))
	var antes := unidad.global_position
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.CHISITOS]
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	(
		assert_object(agarre.manos().sostenido())
		. override_failure_message("no levantó la caja")
		. is_not_null()
	)
	await _asentar(30)
	var desde := antes - camino * DETRAS_DE_LA_UNIDAD
	var marcha := await _caminar(jugador, desde, camino, CUADROS_CAMINANDO)
	await _asentar()
	var corrida := _comprobar_corrida_de_costado(jugador, unidad, antes, camino, marcha)
	assert_float(corrida.length()).is_greater(SE_CORRIO)


## Patea la unidad hacia la cara de un mueble, caminando junto a ella por el pasillo de enfrente.
func _patear_hacia(almacen: Node3D, mueble: MeshInstance3D, donde: String) -> Vector3:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var limites := mueble.global_transform * mueble.get_aabb()
	var lugar := Vector3(
		limites.get_center().x,
		_piso(almacen) + ALTURA_DE_SOLTADO,
		limites.end.z + APARTADA_DEL_MUEBLE
	)
	var camino := Vector3.ZERO
	for paralelo: Vector3 in [Vector3.RIGHT, Vector3.LEFT]:
		var salida := (
			lugar
			+ Vector3.BACK * APARTADO_DEL_SOLIDO
			- paralelo * DETRAS_DE_LA_UNIDAD_EN_EL_PASILLO
		)
		if (
			camino == Vector3.ZERO
			and _recorrido_libre(jugador, salida, paralelo, RECORRIDO_EN_EL_PASILLO)
		):
			camino = paralelo
	var tapan: Array[String] = []
	if camino == Vector3.ZERO:
		for paralelo: Vector3 in [Vector3.RIGHT, Vector3.LEFT]:
			var salida := (
				lugar
				+ Vector3.BACK * APARTADO_DEL_SOLIDO
				- paralelo * DETRAS_DE_LA_UNIDAD_EN_EL_PASILLO
			)
			tapan.append(_lo_que_tapa(jugador, salida, paralelo, RECORRIDO_EN_EL_PASILLO))
	(
		assert_bool(camino != Vector3.ZERO)
		. override_failure_message("%s, sin recorrido libre, lo tapa %s" % [donde, tapan])
		. is_true()
	)
	if camino == Vector3.ZERO:
		return Vector3.ZERO
	var unidad := await _unidad_suelta_en(almacen, lugar)
	var antes := unidad.global_position
	var arranque := (
		antes + Vector3.BACK * APARTADO_DEL_SOLIDO - camino * DETRAS_DE_LA_UNIDAD_EN_EL_PASILLO
	)
	await _caminar(jugador, arranque, camino, CUADROS_EN_EL_PASILLO)
	await _asentar()
	var desplazamiento := unidad.global_position - antes
	(
		assert_float(unidad.global_position.z)
		. override_failure_message("%s, entró en el mueble: %v" % [donde, unidad.global_position])
		. is_greater(limites.end.z - ReglasDeLosObjetos.ROCE)
	)
	await _comprobar_libre_y_enfocable(
		almacen, unidad, unidad.global_position + Vector3.BACK, donde
	)
	return desplazamiento


func test_la_unidad_pateada_hacia_una_gondola_se_frena_en_el_piso() -> void:  # AC-PLY-158
	var almacen: Node3D = await _almacen()
	var gondola: MeshInstance3D = almacen.get_node("Estructura/gondola_deposito03_001")
	var corrida := await _patear_hacia(almacen, gondola, "contra la góndola del depósito")
	assert_float(corrida.dot(Vector3.FORWARD)).is_greater(0.0)
	assert_float(absf(corrida.y)).is_less(SIN_SUBIR)


func test_la_unidad_pateada_hacia_la_heladera_se_frena_en_el_piso() -> void:  # AC-PLY-158
	var almacen: Node3D = await _almacen()
	var heladera: MeshInstance3D = almacen.get_node("Estructura/heladeranueva")
	var corrida := await _patear_hacia(almacen, heladera, "contra la heladera")
	assert_float(corrida.dot(Vector3.FORWARD)).is_greater(0.0)
	assert_float(absf(corrida.y)).is_less(SIN_SUBIR)


func test_patear_una_unidad_cuesta_menos_que_empujar_una_caja() -> void:  # AC-PLY-159
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var camino := Vector3.FORWARD
	var lugar := _lugar_libre(almacen)
	var unidad := await _unidad_suelta_en(almacen, lugar)
	var desde := unidad.global_position - camino * DETRAS_DE_LA_UNIDAD
	var pateando := await _caminar(jugador, desde, camino, CUADROS_CAMINANDO)
	await _asentar()
	var caja: Node3D = null
	for candidata: Node3D in almacen.get("_cajas_de_productos"):
		if (candidata.get_node("Cuerpo") as Node3D).scale.x >= MEDIA_CAJA:
			caja = candidata
			break
	assert_object(caja).override_failure_message("no hay una caja grande").is_not_null()
	caja.global_basis = Basis.IDENTITY
	caja.global_position = Vector3(lugar.x, _piso(almacen) + MEDIA_CAJA, lugar.z)
	caja.call("quedarse_quieta")
	await _asentar()
	var caja_antes := caja.global_position
	var empujando := await _caminar(jugador, desde, camino, CUADROS_CAMINANDO)
	(
		assert_float((caja.global_position - caja_antes).dot(camino))
		. override_failure_message("la caja no se corrió: no se empujó nada")
		. is_greater(SE_CORRIO)
	)
	(
		assert_float(empujando["avance"])
		. override_failure_message(
			"empujar la caja no frenó al jugador: %s contra %s" % [empujando, pateando]
		)
		. is_less(pateando["avance"])
	)
