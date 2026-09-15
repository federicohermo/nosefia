## Llevar la caja del depósito: qué la levanta, qué le saca una unidad y dónde queda al soltarla.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Media caja, en metros: lo que separa el centro de una caja apoyada de lo que la sostiene.
const MEDIA_CAJA := 0.3037

## Desde dónde se camina hacia la pared del depósito.
const RINCON_CERRADO := Vector2(10.4, -4.0)

## Cuadros de física caminando. A 60 Hz son cuatro segundos, de sobra para cruzar el depósito.
const CUADROS_CAMINANDO := 240


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
	_comprobar_la_caja_en_la_mano(jugador, caja, "contra la pared")


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
	var limites := _limites(caja)
	(
		assert_bool(limites.intersects_ray(camara.global_position, -camara.global_basis.z) == null)
		. override_failure_message("%s, la caja se cruza delante de la mira" % donde)
		. is_true()
	)


## Que la caja llevada no se meta adentro de nada.
func _comprobar_la_caja_en_la_mano(jugador: Node3D, caja: Node3D, donde: String) -> void:
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


func _limites(caja: Node3D) -> AABB:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	return forma.global_transform * forma.shape.get_debug_mesh().get_aabb()


func test_la_caja_soltada_se_acomoda_adentro_de_su_apoyo() -> void:  # 047-AC10
	# Soltada corrida sobre otra caja queda centrada sobre ella, que es el caso donde el apoyo
	# mide lo mismo que la caja y las dos cuentas del margen se cruzan.
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var reposicion: Node3D = almacen.get("_reposicion_manual")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ARROZ]
	var debajo: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ACTRONCITO]
	caja.reparent(almacen, true)
	caja.global_position = debajo.global_position + Vector3(0.15, 1.0, 0.12)
	reposicion.call("_apoyar_la_caja", caja)
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
