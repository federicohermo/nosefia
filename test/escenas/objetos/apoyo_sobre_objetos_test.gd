## Lo soltado se apoya sobre unidades de tapa lisa, y levantar lo de abajo hace caer lo de arriba.
##
## Cada unidad sale de la reposición, como la arma el juego, y se asienta sola sobre el piso libre
## del depósito: la pila es la que deja la física, no una pose escrita a mano.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

## Piso libre del depósito, lejos de los muebles y sin nada encima.
const PISO_LIBRE := Vector3(4.18, 0.0, -8.95)

## Cuánto se levanta cada unidad sobre lo que la sostiene antes de soltarla, en metros.
const HOLGURA := 0.02

## Cuánto tiene para dormirse, y cuánto se mira una caída, en segundos de física.
const SEGUNDOS_PARA_DORMIR := 8
const SEGUNDOS_DE_LA_CAIDA := 2

## A qué distancia del jugador queda la pila, en metros: dentro del alcance de la mira.
const DISTANCIA_AL_JUGADOR := 0.9

## Cuánto puede quedar corrida una base respecto de lo que sostiene, en metros.
const TOLERANCIA := 0.01


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	return almacen


## Una unidad del producto, suelta y viva: la reposición la retira y la mano la suelta.
func _unidad(almacen: Node3D, id: Producto.Id) -> ObjetoAgarrable:
	almacen.get("_reposicion_manual").call("retirar", id)
	var agarre: Agarre = almacen.get("_agarre")
	var unidad := agarre.soltar(true) as ObjetoAgarrable
	assert_object(unidad).is_not_null()
	return unidad


func _piso_en(almacen: Node3D, punto: Vector3) -> float:
	var consulta := PhysicsRayQueryParameters3D.create(
		punto + Vector3.UP * 3.0, punto + Vector3.DOWN * 3.0
	)
	var golpe := almacen.get_world_3d().direct_space_state.intersect_ray(consulta)
	var donde: Vector3 = golpe.get("position", punto)
	return donde.y


func _limites(cuerpo: RigidBody3D) -> AABB:
	var limites := AABB()
	var primera := true
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		var de_la_forma := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		limites = de_la_forma if primera else limites.merge(de_la_forma)
		primera = false
	return limites


## Deja la unidad quieta con la base a `base` metros de altura, centrada en `centro`.
func _poner(unidad: ObjetoAgarrable, centro: Vector3, base: float) -> void:
	unidad.global_basis = Basis.IDENTITY
	unidad.global_position = centro
	var limites := _limites(unidad)
	unidad.global_position += Vector3(
		centro.x - limites.get_center().x,
		base - limites.position.y,
		centro.z - limites.get_center().z
	)
	unidad.linear_velocity = Vector3.ZERO
	unidad.angular_velocity = Vector3.ZERO
	unidad.sleeping = false


func _esperar_a_que_duerma(unidades: Array[ObjetoAgarrable]) -> void:
	for cuadro in SEGUNDOS_PARA_DORMIR * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		var todas := true
		for unidad in unidades:
			todas = todas and unidad.sleeping
		if todas:
			return


## Apila las unidades en el piso libre, una sobre otra, y espera a que la física las duerma.
## Cada una se asienta antes de poner la siguiente.
func _apilar(almacen: Node3D, ids: Array[Producto.Id], centro: Vector3) -> Array[ObjetoAgarrable]:
	var pila: Array[ObjetoAgarrable] = []
	var base := _piso_en(almacen, centro) + HOLGURA
	for id in ids:
		var unidad := _unidad(almacen, id)
		_poner(unidad, centro, base)
		pila.append(unidad)
		await _esperar_a_que_duerma([unidad])
		base = _limites(unidad).end.y + HOLGURA
	return pila


## El jugador de pie delante de la pila, mirando el centro de la tapa de `unidad`.
func _mirar_la_tapa(almacen: Node3D, unidad: ObjetoAgarrable) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	var tapa := _limites(unidad)
	var punto := Vector3(tapa.get_center().x, tapa.end.y, tapa.get_center().z)
	var altura_de_los_pies: float = (
		jugador.global_position.y - _piso_en(almacen, jugador.global_position)
	)
	jugador.global_position = Vector3(
		punto.x,
		(
			_piso_en(almacen, Vector3(punto.x, 0.0, punto.z + DISTANCIA_AL_JUGADOR))
			+ altura_de_los_pies
		),
		punto.z + DISTANCIA_AL_JUGADOR
	)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.look_at(punto)


func _golpe_de_la_mira(almacen: Node3D, cuerpo: RigidBody3D) -> Dictionary:
	return almacen.get("_jugador").call("_golpe_de_la_mira", cuerpo)


## Lo que la unidad tiene debajo, a menos de media altura suya de su base. El rayo sale de su
## centro: una base apenas hundida en el piso quedaría adentro de él, y no lo vería.
func _tiene_apoyo(unidad: ObjetoAgarrable) -> bool:
	var limites := _limites(unidad)
	var centro := limites.get_center()
	var consulta := PhysicsRayQueryParameters3D.create(
		centro, Vector3(centro.x, limites.position.y - limites.size.y / 2.0, centro.z)
	)
	consulta.exclude = [unidad.get_rid()]
	return not unidad.get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()


func test_lo_soltado_se_apoya_en_la_tapa_de_una_unidad_de_tapa_lisa() -> void:  # AC-PLY-033
	var almacen := await _almacen()
	var agarre: Agarre = almacen.get("_agarre")
	var pila := await _apilar(almacen, [Producto.Id.MAROLINI], PISO_LIBRE)
	var abajo := pila[0]
	var mano := _unidad(almacen, Producto.Id.MALBARDO)
	_poner(mano, PISO_LIBRE + Vector3.RIGHT * 2.0, _piso_en(almacen, PISO_LIBRE) + HOLGURA)
	_mirar_la_tapa(almacen, abajo)
	var tapa := _limites(abajo)
	# Se mira antes de agarrar: agarrada, la unidad no choca con nada y la mira no toca nada.
	var golpe := _golpe_de_la_mira(almacen, mano)
	assert_bool(agarre.pedir_agarrar(mano.datos, mano)).is_true()
	# La premisa: la mira toca la tapa de la unidad de abajo, y no el piso.
	assert_dict(golpe).is_not_empty()
	assert_object(golpe["collider"]).is_same(abajo)
	agarre.soltar(true)
	var toca: Vector3 = golpe["position"]
	var base := _limites(mano).position.y
	assert_float(base - toca.y).is_between(0.0, TOLERANCIA)
	assert_float(mano.global_position.x).is_equal_approx(toca.x, TOLERANCIA)
	assert_float(mano.global_position.z).is_equal_approx(toca.z, TOLERANCIA)
	await _esperar_a_que_duerma([mano])
	assert_bool(mano.sleeping).is_true()
	assert_float(_limites(mano).position.y).is_greater_equal(tapa.end.y - TOLERANCIA)
	assert_bool(agarre.manos().sostenido() == null).is_true()


func test_la_mira_sobre_lo_que_no_admite_otro_encima_no_apoya() -> void:  # AC-PLY-035
	var almacen := await _almacen()
	var blanda := _unidad(almacen, Producto.Id.CHISITOS)
	_poner(blanda, PISO_LIBRE, _piso_en(almacen, PISO_LIBRE) + HOLGURA)
	await _esperar_a_que_duerma([blanda])
	var mano := _unidad(almacen, Producto.Id.MALBARDO)
	_poner(mano, PISO_LIBRE + Vector3.RIGHT * 2.0, _piso_en(almacen, PISO_LIBRE) + HOLGURA)
	_mirar_la_tapa(almacen, blanda)
	# La mira toca la tapa de la unidad blanda, y esa superficie no admite lo soltado.
	var ojo: Transform3D = almacen.get("_jugador").mira()
	var consulta := PhysicsRayQueryParameters3D.create(
		ojo.origin, ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA
	)
	var golpe := blanda.get_world_3d().direct_space_state.intersect_ray(consulta)
	assert_object(golpe["collider"]).is_same(blanda)
	assert_dict(_golpe_de_la_mira(almacen, mano)).is_empty()


func test_el_balde_soltado_sobre_una_unidad_de_tapa_lisa_queda_derecho() -> void:  # AC-PLY-051
	var almacen := await _almacen()
	var agarre: Agarre = almacen.get("_agarre")
	var pila := await _apilar(almacen, [Producto.Id.TERMINATOR], PISO_LIBRE)
	var balde: RigidBody3D = almacen.get_node("Objetos/Balde")
	_mirar_la_tapa(almacen, pila[0])
	assert_dict(_golpe_de_la_mira(almacen, balde)).is_not_empty()
	assert_bool(agarre.pedir_agarrar(balde.get("datos"), balde)).is_true()
	agarre.soltar(true)
	assert_float(rad_to_deg(balde.global_basis.y.angle_to(Vector3.UP))).is_less(1.0)
	assert_bool(agarre.manos().sostenido() == null).is_true()
	# Entra entero encima o queda en el piso: en ningún caso se mete adentro de la unidad.
	var metido := _limites(pila[0]).grow(-TOLERANCIA).intersects(_limites(balde))
	assert_bool(metido).is_false()


func test_agarrar_lo_de_abajo_hace_caer_lo_de_arriba() -> void:  # AC-PLY-110
	var almacen := await _almacen()
	var agarre: Agarre = almacen.get("_agarre")
	var pila := await _apilar(almacen, [Producto.Id.MAROLINI, Producto.Id.MALBARDO], PISO_LIBRE)
	var abajo := pila[0]
	var arriba := pila[1]
	# La premisa: la de arriba está dormida sobre la de abajo.
	assert_bool(arriba.sleeping).is_true()
	assert_float(_limites(arriba).position.y).is_greater_equal(_limites(abajo).end.y - TOLERANCIA)
	var antes := _limites(arriba).position.y
	var altura_de_abajo := _limites(abajo).size.y
	assert_bool(agarre.pedir_agarrar(abajo.datos, abajo)).is_true()
	for cuadro in SEGUNDOS_DE_LA_CAIDA * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
	assert_bool(_tiene_apoyo(arriba)).is_true()
	assert_float(antes - _limites(arriba).position.y).is_greater_equal(altura_de_abajo - TOLERANCIA)


func test_agarrar_una_unidad_sin_nada_encima_no_despierta_a_nadie() -> void:  # AC-PLY-110
	var almacen := await _almacen()
	var agarre: Agarre = almacen.get("_agarre")
	var pila := await _apilar(almacen, [Producto.Id.MAROLINI], PISO_LIBRE)
	var lejos := await _apilar(almacen, [Producto.Id.MALBARDO], PISO_LIBRE + Vector3.RIGHT * 1.0)
	assert_bool(lejos[0].sleeping).is_true()
	assert_bool(agarre.pedir_agarrar(pila[0].datos, pila[0])).is_true()
	for cuadro in Engine.physics_ticks_per_second:
		await get_tree().physics_frame
	assert_bool(lejos[0].sleeping).is_true()


func test_la_caida_sigue_para_arriba_en_una_pila_de_tres() -> void:  # AC-PLY-111
	var almacen := await _almacen()
	var agarre: Agarre = almacen.get("_agarre")
	var ids: Array[Producto.Id] = [
		Producto.Id.MAROLINI, Producto.Id.MALBARDO, Producto.Id.ZUCARACHAS
	]
	var pila := await _apilar(almacen, ids, PISO_LIBRE)
	var antes: Array[float] = []
	for unidad in pila:
		assert_bool(unidad.sleeping).is_true()
		antes.append(_limites(unidad).position.y)
	var altura_de_abajo := _limites(pila[0]).size.y
	assert_bool(agarre.pedir_agarrar(pila[0].datos, pila[0])).is_true()
	for cuadro in SEGUNDOS_DE_LA_CAIDA * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
	for piso: int in [1, 2]:
		assert_bool(_tiene_apoyo(pila[piso])).is_true()
		assert_float(antes[piso] - _limites(pila[piso]).position.y).is_greater_equal(
			altura_de_abajo - TOLERANCIA
		)
