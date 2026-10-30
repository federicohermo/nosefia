## La boca queda libre y las paredes frenan el paso; soltar por la boca no cuenta como tiro.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const BolsaEnLaMano := preload("res://test/escenas/bolsa_en_la_mano.gd")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
const TapaDelLocal := preload("res://src/escenas/puestos/tapa_del_contenedor.gd")
const BASE_DEL_CONTENEDOR := "Estructura/deposito_contenedor_grande_soporte/"
const RUTA_DE_LA_TAPA := (
	BASE_DEL_CONTENEDOR + "deposito_contenedor_bisagra_izquierda/CuerpoDeLaTapa"
)
const OBJETO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")


func test_la_boca_abierta_no_tiene_una_tapa_de_colision_invisible() -> void:
	var almacen := await _abrir()
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_grande_cuerpo/StaticBody3D"
	)
	for offset: Vector3 in [Vector3.ZERO, Vector3(-0.15, 0, 0.15), Vector3(0.15, 0, -0.15)]:
		var centro := _centro_interior(contenedor) + offset
		var golpe := _rayo(almacen, _boca(contenedor) + offset + Vector3.UP * 0.3, centro)
		assert_bool(golpe.is_empty()).is_false()
		if golpe.is_empty():
			continue
		assert_str(str(almacen.get_path_to(golpe.collider))).contains("deposito_contenedor")
		# Un único casco convexo cerraría la boca a un metro; el fondo está a unos 13 cm.
		assert_float(golpe.position.y).is_between(
			_limites(contenedor).position.y,
			_limites(contenedor).position.y + _limites(contenedor).size.y * 0.25
		)
		assert_float(golpe.normal.y).is_greater(0.99)


func test_el_cuerpo_del_contenedor_frena_un_rayo_desde_el_pasillo() -> void:
	var almacen := await _abrir()
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_grande_cuerpo/StaticBody3D"
	)
	var centro := _limites(contenedor).get_center()
	var golpe := _rayo(almacen, centro + Vector3.BACK, centro)
	assert_bool(golpe.is_empty()).is_false()
	if golpe.is_empty():
		return
	assert_str(str(almacen.get_path_to(golpe.collider))).contains("deposito_contenedor")
	assert_bool(_limites(contenedor).grow(0.003).has_point(golpe.position)).is_true()
	assert_float(golpe.normal.z).is_greater(0.9)


func test_una_bolsa_soltada_por_la_boca_se_recoge_y_se_tira_despues() -> void:  # AC-CLN-009
	var almacen := await _abrir()
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_grande_cuerpo/StaticBody3D"
	)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	jugador.global_position = contenedor.global_position + Vector3.BACK
	var bolsa := BolsaEnLaMano.preparar(almacen)
	var datos := bolsa.datos
	var agarre: Agarre = jugador.get("agarre")
	assert_bool(agarre.pedir_agarrar(datos, bolsa)).is_true()
	agarre.punto_de_soltado.global_position = _boca(contenedor) + Vector3.UP * 0.2
	assert_object(agarre.soltar(true)).is_same(bolsa)
	for cuadro in 10:
		await get_tree().physics_frame
	var recolector: RecolectorDeBasura = almacen.get_node("Servicios/Recolector")
	assert_bool(recolector.tarea().esta_depositada(datos.id)).is_false()
	assert_int(recolector.tarea().depositadas()).is_zero()
	assert_bool(agarre.pedir_agarrar(datos, bolsa)).is_true()
	jugador.set("_enfocado", contenedor)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	jugador.call("_unhandled_input", clic)
	assert_bool(recolector.tarea().esta_depositada(datos.id)).is_true()
	assert_object(agarre.manos().sostenido()).is_null()


func _abrir() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return almacen


func test_cerrar_tapa_bloquea_la_boca_y_abrir_la_deja_libre() -> void:  # AC-CLN-034
	var almacen := await _abrir()
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_grande_cuerpo/StaticBody3D"
	)
	var bisagra := tapa.bisagra.global_position
	assert_bool(tapa.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	assert_array(tapa.mallas).has_size(2)
	assert_bool(tapa.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_false()
	tapa.accionar()
	await _terminar_el_giro(tapa)
	var centro := _centro_interior(contenedor)
	var golpe := _rayo(almacen, _boca(contenedor) + Vector3.UP * 0.3, centro)
	assert_bool(golpe.is_empty()).is_false()
	if not golpe.is_empty():
		assert_object(golpe.collider).is_same(tapa)
		assert_float(golpe.position.y).is_greater(_boca(contenedor).y)
	assert_bool(tapa.call("recibe_objetos")).is_false()
	assert_vector(tapa.bisagra.global_position).is_equal_approx(bisagra, Vector3.ONE * 0.00001)
	tapa.accionar()
	await _terminar_el_giro(tapa)
	golpe = _rayo(almacen, _boca(contenedor) + Vector3.UP * 0.3, centro)
	assert_bool(golpe.is_empty()).is_false()
	if not golpe.is_empty():
		assert_float(golpe.position.y).is_between(
			_limites(contenedor).position.y,
			_limites(contenedor).position.y + _limites(contenedor).size.y * 0.25
		)
	assert_bool(tapa.call("recibe_objetos")).is_true()
	assert_vector(tapa.bisagra.global_position).is_equal_approx(bisagra, Vector3.ONE * 0.00001)


func test_el_cuerpo_no_alterna_y_solo_el_primario_sobre_tapa_alterna() -> void:  # AC-CLN-034
	var almacen := await _abrir()
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_grande_cuerpo/StaticBody3D"
	)
	var centro := _limites(contenedor).get_center()
	var golpe := _rayo(almacen, centro + Vector3.BACK, centro)
	assert_bool(golpe.is_empty()).is_false()
	if golpe.is_empty():
		return
	var cuerpo: StaticBody3D = golpe.collider
	assert_str(str(almacen.get_path_to(cuerpo))).contains("deposito_contenedor_grande_cuerpo")
	assert_bool(cuerpo.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	assert_bool(cuerpo.has_method(ReglasDeLosObjetos.METODO_USAR)).is_false()
	assert_object(cuerpo.call(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_null()
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	jugador.set("_enfocado", cuerpo)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_RIGHT
	clic.pressed = true
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	jugador.call("_unhandled_input", clic)
	assert_bool(tapa.call("recibe_objetos")).is_true()
	clic.button_index = MOUSE_BUTTON_LEFT
	jugador.call("_unhandled_input", clic)
	assert_bool(tapa.call("recibe_objetos")).is_true()
	jugador.set("_enfocado", tapa)
	jugador.call("_unhandled_input", clic)
	await _terminar_el_giro(tapa)
	assert_bool(tapa.call("recibe_objetos")).is_false()
	golpe = _rayo(almacen, _boca(contenedor) + Vector3.UP * 0.3, _centro_interior(contenedor))
	assert_object(golpe.get("collider")).is_same(tapa)
	jugador.call("_unhandled_input", clic)
	await _terminar_el_giro(tapa)
	assert_bool(tapa.call("recibe_objetos")).is_true()


func test_bolsa_con_tapa_cerrada_se_conserva_hasta_el_clic_abierta() -> void:  # AC-CLN-035
	var almacen := await _abrir()
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	tapa.accionar()
	await _terminar_el_giro(tapa)
	var bolsa := BolsaEnLaMano.preparar(almacen)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(bolsa.datos, bolsa)).is_true()
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set("_enfocado", almacen.get("_contenedor"))
	var clic := InputEventAction.new()
	clic.action = ReglasDeLosObjetos.ACCION_AGARRAR
	clic.pressed = true
	jugador.call("_unhandled_input", clic)
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	tapa.accionar()
	await _terminar_el_giro(tapa)
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_zero()
	jugador.call("_unhandled_input", clic)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_equal(1)


func test_reiniciar_restaura_tapa_abierta() -> void:  # AC-CLN-034
	var almacen := await _abrir()
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	var abierta := tapa.bisagra.global_transform
	tapa.accionar()
	await _terminar_el_giro(tapa)
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_grande_cuerpo/StaticBody3D"
	)
	assert_bool(tapa.call("recibe_objetos")).is_true()
	assert_vector(tapa.bisagra.global_position).is_equal_approx(
		abierta.origin, Vector3.ONE * 0.00001
	)
	assert_vector(tapa.bisagra.global_basis.z).is_equal_approx(
		abierta.basis.z, Vector3.ONE * 0.00001
	)


func test_la_tapa_se_detiene_ante_un_objeto_y_continua_cuando_se_retira() -> void:  # AC-CLN-034
	var almacen := await _abrir()
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_grande_cuerpo/StaticBody3D"
	)
	var obstaculo: ObjetoAgarrable = OBJETO.instantiate()
	obstaculo.freeze = true
	almacen.add_child(obstaculo)
	obstaculo.global_position = _boca(contenedor) + Vector3.UP * 0.07
	await get_tree().physics_frame
	await get_tree().physics_frame
	tapa.accionar()
	for cuadro in 60:
		await get_tree().physics_frame
	var estado: TapaDelContenedor = tapa.get("_tapa")
	var detenida := estado.angulo()
	assert_float(detenida).is_between(0.05, TapaDelContenedor.ANGULO_ABIERTA - 0.05)
	var consulta := PhysicsShapeQueryParameters3D.new()
	var forma: CollisionShape3D = tapa.get_node("Volumen")
	consulta.shape = forma.shape
	consulta.transform = forma.global_transform
	consulta.exclude = [tapa.get_rid()]
	for choque in almacen.get_world_3d().direct_space_state.intersect_shape(consulta, 32):
		assert_object(choque.collider).is_not_same(obstaculo)
	for cuadro in 15:
		await get_tree().physics_frame
	assert_float(estado.angulo()).is_equal(detenida)
	obstaculo.queue_free()
	for cuadro in 60:
		await get_tree().physics_frame
	assert_float(estado.angulo()).is_equal(0.0)
	assert_bool(tapa.call("recibe_objetos")).is_false()
	tapa.accionar()
	for cuadro in 60:
		await get_tree().physics_frame
	assert_float(estado.angulo()).is_equal(TapaDelContenedor.ANGULO_ABIERTA)
	assert_bool(tapa.call("recibe_objetos")).is_true()


func test_las_paredes_contienen_la_tolerancia_de_penetracion_del_motor() -> void:
	var almacen := await _abrir()
	var soporte: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_grande_cuerpo/StaticBody3D"
	)
	var tolerancia: float = ProjectSettings.get_setting(
		"physics/jolt_physics_3d/simulation/penetration_slop"
	)
	for alto: float in [0.2, 0.45, 0.65, 0.9]:
		for lado: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var limites := _limites(soporte)
			var centro := limites.get_center()
			centro.y = limites.position.y + limites.size.y * alto
			var afuera := centro + lado * limites.size.length()
			var interior := _rayo_de_pared(almacen, centro, afuera)
			var exterior := _rayo_de_pared(almacen, afuera, centro)
			assert_object(interior.get("collider")).is_same(soporte)
			assert_object(exterior.get("collider")).is_same(soporte)
			if interior.is_empty() or exterior.is_empty():
				continue
			var espesor: float = interior.position.distance_to(exterior.position)
			assert_float(espesor).is_greater(tolerancia)


func test_lo_soltado_mirando_el_contenedor_no_se_apoya_en_su_cuerpo() -> void:  # AC-CLN-079
	var almacen := await _abrir_con_semilla()
	var contenedor: StaticBody3D = almacen.get("_contenedor")
	var jugador: Node3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[0]
	var bidon: RigidBody3D = almacen.get_node("Objetos/JabonAzul")
	var balde: RigidBody3D = almacen.get_node("Objetos/Balde")
	var limites := _limites(contenedor)
	var delante := Vector3(limites.get_center().x, limites.position.y, limites.end.z + 1.2)
	var piso := _rayo(almacen, delante + Vector3.UP, delante + Vector3.DOWN)
	assert_bool(piso.is_empty()).is_false()
	# El control: sobre el piso libre junto al contenedor la misma caja queda donde la mira toca, y
	# entonces el test sabe ver un apoyo.
	var al_pie := Vector3(delante.x, piso["position"].y, limites.end.z + 0.7)
	jugador.call(
		"ubicar", Transform3D(Basis.IDENTITY, al_pie + Vector3.BACK * 1.2 + Vector3.UP * 0.005)
	)
	camara.look_at(al_pie)
	var toca: Vector3 = _golpe_de_la_mira(jugador, caja)["position"]
	_soltar(almacen, caja)
	# El juego la corre un poco de lo que estorba: queda a menos de media caja del punto.
	var forma: CollisionShape3D = caja.find_children("*", "CollisionShape3D", false, false)[0]
	var media := LimitesDeForma.de(forma.shape).size * forma.scale * 0.5
	(
		assert_float(
			Vector2(caja.global_position.x - toca.x, caja.global_position.z - toca.z).length()
		)
		. is_less(minf(media.x, media.z))
	)
	jugador.call("ubicar", Transform3D(Basis.IDENTITY, piso["position"] + Vector3.UP * 0.005))
	var fondo := _rayo(almacen, _boca(contenedor) + Vector3.UP * 0.3, _centro_interior(contenedor))
	assert_object(fondo.get("collider")).is_same(contenedor)
	var borde := _borde_del_contenedor(almacen, contenedor)
	assert_bool(borde.is_finite()).is_true()
	for cuerpo: RigidBody3D in [caja, bidon, balde]:
		for apuntado: Vector3 in [fondo["position"], borde]:
			camara.global_position = apuntado + Vector3(0.0, 0.8, 0.3)
			camara.look_at(apuntado)
			var golpe := _golpe_de_la_mira(jugador, cuerpo)
			assert_object(golpe.get("collider")).is_same(contenedor)
			_soltar(almacen, cuerpo)
			_afirmar_fuera_del_contenedor(almacen, cuerpo, jugador, contenedor)


func test_parado_junto_al_contenedor_lo_soltado_sin_mira_no_queda_adentro() -> void:  # AC-CLN-079
	var almacen := await _abrir_con_semilla()
	var contenedor: StaticBody3D = almacen.get("_contenedor")
	var jugador: Node3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[0]
	var limites := _limites(contenedor)
	var cuerpo_del_jugador: CollisionShape3D = jugador.get_node("Cuerpo")
	var pegado: float = (cuerpo_del_jugador.shape as CapsuleShape3D).radius + 0.05
	var probados := 0
	for lado: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
		var junto := limites.get_center() + lado * (limites.size * 0.5 + Vector3.ONE * pegado)
		junto.y = limites.position.y
		var piso := _rayo(almacen, junto + Vector3.UP, junto + Vector3.DOWN)
		if piso.is_empty() or piso["collider"] == contenedor:
			continue
		probados += 1
		jugador.call("ubicar", Transform3D(Basis.IDENTITY, piso["position"] + Vector3.UP * 0.005))
		# Con la mira en el cielo no hay superficie que apoyar: la caja cae al lado del jugador.
		camara.look_at(camara.global_position + Vector3.UP * 5.0 + jugador.frente())
		_soltar(almacen, caja)
		_afirmar_fuera_del_contenedor(almacen, caja, jugador, contenedor)
	assert_int(probados).is_greater(0)


func _abrir_con_semilla() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_semilla(almacen)
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	return almacen


## Fuera del volumen del contenedor, sobre otra superficie y sin encimarse con nada.
func _afirmar_fuera_del_contenedor(
	almacen: Node3D, cuerpo: RigidBody3D, jugador: Node3D, contenedor: StaticBody3D
) -> void:
	var limites := _limites(contenedor)
	var centro := cuerpo.global_position
	var huella := Rect2(limites.position.x, limites.position.z, limites.size.x, limites.size.z)
	assert_bool(huella.has_point(Vector2(centro.x, centro.z))).is_false()
	var debajo := _debajo_de(almacen, cuerpo, jugador)
	assert_object(debajo.get("collider")).is_not_null()
	assert_object(debajo.get("collider")).is_not_same(contenedor)
	assert_bool(_encimado_con_algo(almacen, cuerpo, jugador)).is_false()


## Si el cuerpo, con sus formas reales, comparte lugar con algo que no es él ni el jugador. Se lo
## sube un roce para que el piso que lo sostiene no cuente como choque.
func _encimado_con_algo(almacen: Node3D, cuerpo: RigidBody3D, jugador: Node3D) -> bool:
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		if forma.disabled or forma.shape == null:
			continue
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.transform.origin += Vector3.UP * ReglasDeLosObjetos.ROCE * 2.0
		consulta.collision_mask = cuerpo.collision_mask
		consulta.exclude = [cuerpo.get_rid(), jugador.get_rid()]
		if not almacen.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty():
			return true
	return false


func _terminar_el_giro(tapa: TapaDelLocal) -> void:
	tapa.set_physics_process(false)
	tapa.call("_physics_process", 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _rayo(almacen: Node3D, desde: Vector3, hasta: Vector3) -> Dictionary:
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
	return almacen.get_world_3d().direct_space_state.intersect_ray(consulta)


## El recipiente puede estar contra una pared: acá se mide su espesor, no el del edificio.
func _rayo_de_pared(almacen: Node3D, desde: Vector3, hasta: Vector3) -> Dictionary:
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
	var soporte: StaticBody3D = almacen.get("_contenedor")
	var excluidos: Array[RID] = []
	for cuerpo: CollisionObject3D in almacen.find_children("*", "CollisionObject3D", true, false):
		if cuerpo != soporte:
			excluidos.append(cuerpo.get_rid())
	consulta.exclude = excluidos
	return almacen.get_world_3d().direct_space_state.intersect_ray(consulta)


func test_el_contenedor_fijo_conserva_los_viajes_del_local_y_las_bolsas() -> void:  # AC-CLN-008
	var almacen := await _abrir()
	var contenedor: StaticBody3D = almacen.get_node(
		BASE_DEL_CONTENEDOR + "deposito_contenedor_grande_cuerpo/StaticBody3D"
	)
	var piso: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Fondo")
	var forma := piso.shape as BoxShape3D
	var punto := piso.to_local(contenedor.global_position)
	(
		assert_bool(AABB(-forma.size / 2.0, forma.size).has_point(Vector3(punto.x, 0, punto.z)))
		. is_true()
	)
	assert_object(contenedor.call("interactuar")).is_null()
	var puntos: Array[Node3D] = []
	for ruta: String in [
		"Estructura/gondolanueva/StaticBody3D",
		"Estructura/Ventanilla",
		"Estructura/base compu/StaticBody3D"
	]:
		puntos.append(almacen.get_node(ruta))
	for ruta: NodePath in BolsaEnLaMano.RUTAS:
		puntos.append(almacen.get_node(ruta))
	# Las manchas del local son tareas del local; las del depósito, como la que está al lado del
	# contenedor, no.
	var del_local := 0
	for mancha: Node in almacen.find_children("Mancha*", "Node3D", true, false):
		var lugar: PisoDelLocal.Lugar = mancha.call("lugar_de_la_mancha")
		if PisoDelLocal.habitacion_de(lugar) == PisoDelLocal.ReglasDelCierre.Habitacion.LOCAL:
			puntos.append(mancha as Node3D)
			del_local += 1
	assert_int(del_local).is_greater(0)
	assert_int(puntos.size()).is_equal(3 + ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA + del_local)
	for nodo in puntos:
		assert_float(nodo.global_position.distance_to(contenedor.global_position)).is_greater_equal(
			ReglasDeLaBasura.DISTANCIA_MINIMA_AL_CONTENEDOR
		)


func _limites(contenedor: StaticBody3D) -> AABB:
	var malla := contenedor.get_parent() as MeshInstance3D
	return malla.global_transform * malla.get_aabb()


func _centro_interior(contenedor: StaticBody3D) -> Vector3:
	var limites := _limites(contenedor)
	# Se comprueba una hoja, evitando la junta entre las dos tapas.
	return Vector3(
		limites.position.x + limites.size.x * 0.25,
		contenedor.global_position.y,
		limites.get_center().z
	)


func _boca(contenedor: StaticBody3D) -> Vector3:
	var centro := _centro_interior(contenedor)
	centro.y = _limites(contenedor).end.y
	return centro


## El punto más alto del borde del contenedor que queda más cerca del pasillo.
func _borde_del_contenedor(almacen: Node3D, contenedor: StaticBody3D) -> Vector3:
	var limites := _limites(contenedor)
	var arriba: Array[Vector3] = []
	var x := limites.position.x
	while x <= limites.end.x:
		var z := limites.position.z
		while z <= limites.end.z:
			var golpe := _rayo(
				almacen, Vector3(x, limites.end.y + 0.5, z), Vector3(x, limites.position.y - 0.5, z)
			)
			if golpe.get("collider") == contenedor and golpe["normal"].y > 0.99:
				arriba.append(golpe["position"])
			z += 0.02
		x += 0.02
	var tope := -INF
	for punto in arriba:
		tope = maxf(tope, punto.y)
	var borde := Vector3.INF
	for punto in arriba:
		if punto.y > tope - 0.03 and (not borde.is_finite() or punto.z > borde.z):
			borde = punto
	return borde


## Lo que la mira toca, contra lo que el cuerpo choca.
func _golpe_de_la_mira(jugador: Node3D, cuerpo: RigidBody3D) -> Dictionary:
	var ojo: Transform3D = jugador.mira()
	var consulta := PhysicsRayQueryParameters3D.create(
		ojo.origin,
		ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA,
		cuerpo.collision_mask
	)
	consulta.exclude = [jugador.get_rid(), cuerpo.get_rid()]
	return jugador.get_world_3d().direct_space_state.intersect_ray(consulta)


func _debajo_de(almacen: Node3D, cuerpo: RigidBody3D, jugador: Node3D) -> Dictionary:
	var consulta := PhysicsRayQueryParameters3D.create(
		cuerpo.global_position, cuerpo.global_position + Vector3.DOWN * 2.0
	)
	consulta.exclude = [jugador.get_rid(), cuerpo.get_rid()]
	return almacen.get_world_3d().direct_space_state.intersect_ray(consulta)


func _soltar(almacen: Node3D, cuerpo: RigidBody3D) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(cuerpo.get("datos"), cuerpo)).is_true()
	agarre.soltar(true)
	assert_object(agarre.manos().sostenido()).is_null()
