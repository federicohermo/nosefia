## Llevar la caja del depósito: qué la levanta, qué le saca una unidad y dónde queda al soltarla.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## El estante vacío del depósito: el único donde una caja entra sin apilarse sobre otra.
const ESTANTE_DEL_DEPOSITO := "Estructura/gondola_deposito01/StaticBody3D"

## Media caja, en metros: lo que separa el centro de una caja apoyada de lo que la sostiene.
const MEDIA_CAJA := 0.3037

## Desde dónde se camina hacia la pared del depósito.
const RINCON_CERRADO := Vector2(10.4, -4.0)

## Cuadros de física caminando. A 60 Hz son cuatro segundos, de sobra para cruzar el depósito.
const CUADROS_CAMINANDO := 240

## Desde dónde se arranca a caminar hacia un estante, en metros de su frente.
const CARRERA_HASTA_EL_ESTANTE := 1.5

## Cuadros de física retrocediendo: pegado al estante no hay piso libre donde apoyar la caja.
const CUADROS_ATRAS := 20

## Los dos gestos de soltar, en grados de la vista.
const MIRANDO_ARRIBA := 10.0
const MIRANDO_ABAJO := -40.0


## Le pone el foco al objetivo y le manda la acción, que es lo que hace el clic de verdad.
func _accion(jugador: Node3D, objetivo: Node3D, accion: StringName) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _almacen_con_jugador_quieto() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func test_la_caja_entrega_en_el_piso_y_no_en_el_estante() -> void:  # 047-AC2 047-AC3
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var repositor: Repositor = almacen.get("_repositor")
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var caja: Node3D = almacen.get("_cajas_de_productos")[producto.id]
	var antes := repositor.estante().disponibles_para_retirar(producto)
	(
		assert_bool(ReglasDeLosObjetos.se_puede_retirar(caja.global_position.y))
		. override_failure_message("la caja ya arranca apoyada: el caso no distingue nada")
		. is_false()
	)
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(repositor.estante().disponibles_para_retirar(producto)).is_equal(antes)
	caja.global_position.y = ReglasDeLosObjetos.ALTURA_PARA_RETIRAR
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
	var unidad := agarre.manos().sostenido() as UnidadDeProducto
	assert_object(unidad).is_not_null()
	if unidad == null:
		return
	assert_int(unidad.producto.id).is_equal(producto.id)
	assert_int(repositor.estante().disponibles_para_retirar(producto)).is_equal(antes - 1)


func test_el_clic_izquierdo_levanta_la_caja_y_no_entrega_producto() -> void:  # 047-AC4
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var repositor: Repositor = almacen.get("_repositor")
	var producto := Catalogo.de(Producto.Id.ARROZ)
	var caja: Node3D = almacen.get("_cajas_de_productos")[producto.id]
	var antes := repositor.estante().disponibles_para_retirar(producto)
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.manos().sostenido()).is_same(caja.datos)
	assert_bool(agarre.manos().sostenido() is UnidadDeProducto).is_false()
	assert_int(repositor.estante().disponibles_para_retirar(producto)).is_equal(antes)
	assert_object(caja.get_parent()).is_same(jugador.get_node("PuntoDeCaja"))
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.manos().sostenido()).is_null()


func test_la_caja_llevada_no_tapa_la_mira_ni_atraviesa_la_pared() -> void:  # 047-AC6
	# **Camina de verdad contra la pared.** Teleportar al jugador contra ella probaría otra cosa:
	# lo que tiene que impedir que la caja entre en la madera es que el cuerpo no llegue, y eso
	# sólo se ejerce con `move_and_slide` corriendo.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ARROZ]
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	# De frente y no de costado: un producto se mira girado en la mano, una caja se lleva con
	# las dos manos y muestra su cara rotulada.
	(
		assert_float(caja.global_basis.x.dot(jugador.global_basis.z))
		. override_failure_message("la caja va de costado en la mano")
		. is_equal_approx(1.0, 0.001)
	)
	jugador.global_position = Vector3(RINCON_CERRADO.x, jugador.global_position.y, RINCON_CERRADO.y)
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	for cuadro in CUADROS_CAMINANDO:
		await get_tree().physics_frame
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)
	await get_tree().physics_frame
	(
		assert_bool(jugador.test_move(jugador.global_transform, -jugador.global_basis.z))
		. override_failure_message("el jugador no llegó a chocar: el caso no ejerce nada")
		. is_true()
	)
	_comprobar_la_mira_libre(jugador, caja, "contra la pared")
	_comprobar_que_no_atraviesa_nada(jugador, caja, "contra la pared")


func test_la_caja_soltada_queda_apoyada_en_el_piso_sin_caer() -> void:  # 047-AC7
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ARROZ]
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	# Sin un solo cuadro de física de por medio: la caja no cae, se apoya.
	var consulta := PhysicsRayQueryParameters3D.create(
		caja.global_position, caja.global_position + Vector3.DOWN
	)
	consulta.exclude = [(caja as CollisionObject3D).get_rid()]
	var golpe := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	assert_bool(golpe.has("position")).is_true()
	if not golpe.has("position"):
		return
	var hueco: float = caja.global_position.y - (golpe["position"] as Vector3).y
	(
		assert_float(hueco)
		. override_failure_message(
			"la caja quedó a %.4f m de su apoyo y media caja es %.4f" % [hueco, MEDIA_CAJA]
		)
		. is_equal_approx(MEDIA_CAJA, 0.001)
	)


## Que la caja llevada no se cruce delante de la mira.
func _comprobar_la_mira_libre(jugador: Node3D, caja: Node3D, donde: String) -> void:
	var camara: Camera3D = jugador.get_node("Camara")
	var limites := _limites_de(caja)
	(
		assert_bool(limites.intersects_ray(camara.global_position, -camara.global_basis.z) == null)
		. override_failure_message("%s, la caja se cruza delante de la mira" % donde)
		. is_true()
	)


## Que la caja llevada no se meta adentro de nada.
func _comprobar_que_no_atraviesa_nada(jugador: Node3D, caja: Node3D, donde: String) -> void:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = forma.global_transform
	consulta.exclude = [jugador.get_rid(), (caja as CollisionObject3D).get_rid()]
	var pisados: Array[String] = []
	for choque in jugador.get_world_3d().direct_space_state.intersect_shape(consulta, 4):
		pisados.append(str(jugador.get_parent().get_path_to(choque["collider"])))
	(
		assert_array(pisados)
		. override_failure_message("%s, la caja atraviesa %s" % [donde, ", ".join(pisados)])
		. is_empty()
	)


## Lo que ocupa un cuerpo, en coordenadas del mundo.
func _limites_de(cuerpo: Node3D) -> AABB:
	var limites := AABB(cuerpo.global_position, Vector3.ZERO)
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", true, false):
		limites = limites.merge(forma.global_transform * forma.shape.get_debug_mesh().get_aabb())
	return limites


## Gira la vista como lo haría el mouse, a un yaw y un pitch absolutos en radianes.
func _mirar(jugador: Node3D, giro: float, alto: float) -> void:
	var camara: Camera3D = jugador.get_node("Camara")
	var evento := InputEventMouseMotion.new()
	evento.relative = (
		Vector2(jugador.rotation.y - giro, camara.rotation.x - alto)
		/ ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE
	)
	jugador.call("_unhandled_input", evento)


## Pone la mira sobre la tapa de un cuerpo.
func _apuntar_a(jugador: Node3D, objetivo: Node3D) -> void:
	var camara: Camera3D = jugador.get_node("Camara")
	var blanco := _limites_de(objetivo)
	var hacia := (
		Vector3(blanco.get_center().x, blanco.end.y, blanco.get_center().z) - camara.global_position
	)
	_mirar(jugador, atan2(-hacia.x, -hacia.z), atan2(hacia.y, Vector2(hacia.x, hacia.z).length()))


## Camina —caminando, no teleportando— hasta chocar contra la cara de `limites` que mira al
## jugador. Teleportar probaría otra cosa: lo que decide dónde frena es `move_and_slide`.
func _caminar_hasta(almacen: Node3D, limites: AABB, direccion: Vector3) -> void:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var fondo: float = (limites.size * direccion.abs()).length() / 2.0
	var arranque := limites.get_center() - direccion * (fondo + CARRERA_HASTA_EL_ESTANTE)
	jugador.global_position = Vector3(arranque.x, jugador.global_position.y, arranque.z)
	_mirar(jugador, atan2(-direccion.x, -direccion.z), 0.0)
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	for cuadro in CUADROS_CAMINANDO:
		await get_tree().physics_frame
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)
	await get_tree().physics_frame


## Sobre qué cuerpo quedó apoyada la caja.
func _apoyo_de(almacen: Node3D, caja: Node3D) -> Node3D:
	var consulta := PhysicsRayQueryParameters3D.create(
		caja.global_position, caja.global_position + Vector3.DOWN * 3.0
	)
	consulta.exclude = [(caja as CollisionObject3D).get_rid()]
	var golpe := almacen.get_world_3d().direct_space_state.intersect_ray(consulta)
	return golpe.get("collider")


func test_la_caja_soltada_se_acomoda_adentro_de_su_apoyo() -> void:  # 047-AC10
	# Mirando la tapa de otra caja queda centrada sobre ella, que es el caso donde el apoyo mide
	# lo mismo que la caja y las dos cuentas del margen se cruzan.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ARROZ]
	var debajo: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.JABON]
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	# Las cajas del piso están contra la pared: se llega a ellas desde el pasillo, o sea -x.
	await _caminar_hasta(almacen, _limites_de(debajo), Vector3.LEFT)
	_apuntar_a(jugador, debajo)
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_float(caja.global_position.x).is_equal_approx(debajo.global_position.x, 0.001)
	assert_float(caja.global_position.z).is_equal_approx(debajo.global_position.z, 0.001)
	(
		assert_float(caja.global_position.y)
		. override_failure_message("la caja no quedó arriba de la otra")
		. is_greater(debajo.global_position.y)
	)
	_comprobar_apoyo_entero(almacen, caja, "sobre otra caja")


func test_la_caja_vuelta_a_su_lugar_apoya_entera() -> void:  # 047-AC10
	# El caso de arriba mide un apoyo del tamaño de la caja; éste mide los ocho apoyos de
	# verdad, que son el estante del depósito y el suelo.
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var cajas: Array = almacen.get("_cajas_de_productos")
	assert_int(cajas.size()).is_equal(Catalogo.todos().size())
	for caja: Node3D in cajas:
		_comprobar_apoyo_entero(almacen, caja, caja.name)


## Que la huella de la caja entre adentro de lo que la sostiene.
func _comprobar_apoyo_entero(almacen: Node3D, caja: Node3D, donde: String) -> void:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var media: Vector3 = (forma.shape as BoxShape3D).size * forma.scale / 2.0
	var consulta := PhysicsRayQueryParameters3D.create(
		caja.global_position, caja.global_position + Vector3.DOWN * 3.0
	)
	consulta.exclude = [(caja as CollisionObject3D).get_rid()]
	var golpe := almacen.get_world_3d().direct_space_state.intersect_ray(consulta)
	assert_bool(golpe.has("collider")).is_true()
	if not golpe.has("collider"):
		return
	var apoyo: CollisionObject3D = golpe["collider"]
	var limites := AABB(apoyo.global_position, Vector3.ZERO)
	for suya: CollisionShape3D in apoyo.find_children("*", "CollisionShape3D", true, false):
		limites = limites.merge(suya.global_transform * suya.shape.get_debug_mesh().get_aabb())
	var huella := AABB(caja.global_position - media, media * 2.0)
	huella.position.y = limites.position.y
	huella.size.y = limites.size.y
	(
		assert_bool(limites.grow(0.001).encloses(huella))
		. override_failure_message(
			"%s: la caja en %v se sale de su apoyo %v" % [donde, caja.global_position, limites]
		)
		. is_true()
	)


func test_la_caja_va_donde_apunta_la_mira() -> void:  # 047-AC11
	# Los dos gestos que decide el spec: pegado al estante y mirando arriba queda en el estante,
	# y mirando abajo queda en el piso. Sin esto la caja vuelve siempre al mismo lado.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var estante: Node3D = almacen.get_node(ESTANTE_DEL_DEPOSITO)
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ARROZ]
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	await _caminar_hasta(almacen, _limites_de(estante), Vector3.FORWARD)
	_mirar(jugador, jugador.rotation.y, deg_to_rad(MIRANDO_ARRIBA))
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	(
		assert_object(_apoyo_de(almacen, caja))
		. override_failure_message("mirando arriba la caja no quedó en el estante")
		. is_same(estante)
	)
	_comprobar_apoyo_entero(almacen, caja, "en el estante")
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	# Pegado al estante no hay piso libre donde dejarla: entre el cuerpo y la madera no entra
	# una caja. Se retrocede un paso, que es lo que haría cualquiera.
	Input.action_press(ReglasDelJugador.ACCION_ATRAS)
	for cuadro in CUADROS_ATRAS:
		await get_tree().physics_frame
	Input.action_release(ReglasDelJugador.ACCION_ATRAS)
	await get_tree().physics_frame
	_mirar(jugador, jugador.rotation.y, deg_to_rad(MIRANDO_ABAJO))
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	(
		assert_object(caja.get_parent())
		. override_failure_message("con lugar de sobra la caja se quedó en la mano")
		. is_same(almacen)
	)
	(
		assert_object(_apoyo_de(almacen, caja))
		. override_failure_message("mirando abajo la caja no quedó en el piso")
		. is_not_same(estante)
	)
	_comprobar_apoyo_entero(almacen, caja, "en el piso")


func test_la_caja_soltada_nunca_queda_adentro_de_nada() -> void:  # 047-AC12
	# El barrido que antes fallaba: parado de costado al estante, la caja terminaba metida en la
	# madera. Se prueban las dos vueltas y los cuatro ángulos, no sólo el tiro de frente.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var estante: Node3D = almacen.get_node(ESTANTE_DEL_DEPOSITO)
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ARROZ]
	var mano: Node3D = jugador.get_node("PuntoDeCaja")
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	await _caminar_hasta(almacen, _limites_de(estante), Vector3.FORWARD)
	assert_object(caja.get_parent()).is_same(mano)
	var derecho := jugador.rotation.y
	var soltadas := 0
	for giro: float in [-45.0, -20.0, 0.0, 20.0, 45.0]:
		for alto: float in [MIRANDO_ABAJO, 0.0, MIRANDO_ARRIBA, 30.0]:
			if caja.get_parent() != mano:
				_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
			_mirar(jugador, derecho + deg_to_rad(giro), deg_to_rad(alto))
			_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
			# Donde no entra no se suelta: pegado al estante y mirando al piso no hay hueco
			# entre el cuerpo y la madera, y la caja se queda en la mano.
			if caja.get_parent() == mano:
				continue
			soltadas += 1
			_comprobar_que_no_atraviesa_nada(
				jugador, caja, "girado %.0f grados y mirando %.0f" % [giro, alto]
			)
	(
		assert_int(soltadas)
		. override_failure_message("casi ninguna se soltó: el caso no ejerce nada")
		. is_greater(10)
	)


func test_agarrar_la_caja_del_estante_no_mueve_al_jugador() -> void:  # 047-AC6
	# La caja llevada entra donde entra el cuerpo, así que darle su volumen no puede empujar a
	# nadie. Antes nacía 0,8 m adelante: agarrando de cerca el jugador se subía al estante.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ACTRONCITO]
	await _caminar_hasta(almacen, _limites_de(caja), Vector3.RIGHT)
	var antes := jugador.global_position
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	await get_tree().physics_frame
	assert_object(caja.get_parent()).is_same(jugador.get_node("PuntoDeCaja"))
	(
		assert_float(jugador.global_position.distance_to(antes))
		. override_failure_message(
			"agarrar la caja movió al jugador de %v a %v" % [antes, jugador.global_position]
		)
		. is_less(0.001)
	)
