## Llevar la caja del depósito: qué la levanta, qué le saca una unidad y dónde queda al soltarla.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Media caja, en metros: lo que separa el centro de una caja apoyada de lo que la sostiene.
const MEDIA_CAJA := 0.3037

## Un rincón del que no se puede seguir avanzando. Ahí el brazo de la caja tiene que acortar, y
## el caso lo afirma en vez de darlo por hecho.
const RINCON_CERRADO := Vector2(10.4, -7.4)


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


func test_la_caja_llevada_no_tapa_la_mira_ni_atraviesa_nada() -> void:  # 047-AC6
	# El jugador conserva su `_physics_process`: el brazo que acomoda la caja corre ahí.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ARROZ]
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	for cuadro in 40:
		await get_tree().physics_frame
	_comprobar_la_caja_en_la_mano(jugador, caja, "al aire")
	_comprobar_la_mira_libre(jugador, caja, "al aire")
	var brazo: SpringArm3D = jugador.get_node("BrazoDeCaja")
	jugador.global_position = Vector3(RINCON_CERRADO.x, jugador.global_position.y, RINCON_CERRADO.y)
	for cuadro in 40:
		await get_tree().physics_frame
	(
		assert_float(brazo.get_hit_length())
		. override_failure_message("en el rincón el brazo no acortó: el caso no ejerce nada")
		. is_less(brazo.spring_length)
	)
	# Y no se repliega hasta adentro de la cámara: ahí la caja tapa la pantalla entera.
	var punto: Node3D = jugador.get_node("PuntoDeCaja")
	var tope := brazo.spring_length * ReglasDeLosObjetos.REPLIEGUE_MAXIMO_DE_LA_CAJA
	(
		assert_float((punto.position - brazo.position).length())
		. override_failure_message("la caja se replegó más allá del tope")
		. is_greater_equal(tope - 0.01)
	)
	_comprobar_la_mira_libre(jugador, caja, "contra la pared")


## Que la caja llevada no se cruce delante de la mira. Vale siempre, también replegada.
func _comprobar_la_mira_libre(jugador: Node3D, caja: Node3D, donde: String) -> void:
	var camara: Camera3D = jugador.get_node("Camara")
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var limites: AABB = forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
	(
		assert_bool(limites.intersects_ray(camara.global_position, -camara.global_basis.z) == null)
		. override_failure_message("%s, la caja se cruza delante de la mira" % donde)
		. is_true()
	)


## Que la caja llevada no se meta adentro de nada. Contra una pared sí se mete: el repliegue
## está topeado para que no termine adentro de la cámara, y ése es el canje.
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
