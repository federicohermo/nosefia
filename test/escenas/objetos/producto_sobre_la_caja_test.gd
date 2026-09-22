## El producto apoyado sobre una caja del depósito cae cuando la caja se va de abajo.
##
## Un producto soltado sobre una tapa es un cuerpo rígido vivo que el motor duerme apenas se
## acomoda, y la caja es un cuerpo congelado: estático para el motor. Un cuerpo estático que se
## va de abajo de uno dormido no lo despierta, así que el producto se quedaba flotando donde
## estaba la tapa. Los cuadros y las medidas son los del caso de la pila, que es el mismo
## desarme con cajas.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## El caso de la pila: de ahí salen los cuadros de caída y las medidas de la caja grande.
const Pila := preload("res://test/escenas/objetos/caja_que_se_lleva_test.gd")

## El producto que se apoya sobre la caja. Uno cualquiera con más de una unidad en la góndola:
## se retira uno para la tapa y otro para el piso de al lado.
const PRODUCTO_QUE_SE_APOYA := Producto.Id.MALBARDO

## A qué distancia de la caja se deja el producto que NO tiene que despertarse, en metros.
const A_UN_METRO := 1.0

## Desde dónde el jugador empuja la caja, en metros delante de ella.
const DELANTE_DE_LA_CAJA := Vector3(0.0, 0.01, 1.2)


func _las_grandes(cajas: Array) -> Array[Node3D]:
	var grandes: Array[Node3D] = []
	for caja: Node3D in cajas:
		if (caja.get_node("Cuerpo") as Node3D).scale.x >= Pila.MEDIA_CAJA:
			grandes.append(caja)
	return grandes


## Le pone el foco al objetivo y le manda la acción, que es lo que hace el clic de verdad.
func _accion(jugador: Node3D, objetivo: Node3D, accion: StringName) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


## Lo que ocupa un cuerpo, en coordenadas del mundo.
func _limites_de(cuerpo: Node3D) -> AABB:
	var limites := AABB(cuerpo.global_position, Vector3.ZERO)
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", true, false):
		limites = limites.merge(forma.global_transform * forma.shape.get_debug_mesh().get_aabb())
	return limites


## Una caja grande apoyada en el piso libre del depósito, con el jugador parado enfrente.
func _caja_en_el_piso_libre(almacen: Node3D, piso: int) -> Node3D:
	var caja: Node3D = _las_grandes(almacen.get("_cajas_de_productos"))[piso]
	caja.global_position = (
		Pila.PISO_LIBRE_DEL_DEPOSITO + Vector3.UP * Pila.MEDIA_CAJA * (1 + 2 * piso)
	)
	caja.call("quedarse_quieta")
	return caja


## Retira una unidad de la góndola y la deja dormida encima de un lugar, apoyada sobre él.
##
## Dormida de verdad, y se afirma: el caso es que un cuerpo dormido no se entera de que lo que
## lo sostenía se fue, así que un producto que todavía estuviera despierto caería solo y el
## verde no diría nada.
func _producto_dormido_sobre(almacen: Node3D, lugar: Vector3) -> RigidBody3D:
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	puesto.call("retirar", PRODUCTO_QUE_SE_APOYA)
	var unidad: RigidBody3D = agarre.soltar(true)
	unidad.global_basis = Basis.IDENTITY
	unidad.linear_velocity = Vector3.ZERO
	unidad.angular_velocity = Vector3.ZERO
	var media_altura := _limites_de(unidad).size.y / 2.0
	unidad.global_position = lugar + Vector3.UP * (media_altura + Pila.HOLGURA_DEL_APOYO)
	for cuadro in Pila.CUADROS_CAYENDO:
		await get_tree().physics_frame
	(
		assert_bool(unidad.sleeping)
		. override_failure_message("`%s` no se durmió apoyado sobre %v" % [unidad.name, lugar])
		. is_true()
	)
	return unidad


## Que el cuerpo bajó al menos media caja y quedó apoyado: algo debajo a menos de media altura
## suya, medida como está ahora, que caído puede haber quedado de costado.
func _comprobar_que_cayo(almacen: Node3D, cuerpo: Node3D, desde: float, donde: String) -> void:
	(
		assert_float(cuerpo.global_position.y)
		. override_failure_message(
			(
				"%s: `%s` quedó flotando a %.3f, donde lo dejó la caja que ya no está"
				% [donde, cuerpo.name, cuerpo.global_position.y]
			)
		)
		. is_less(desde - Pila.MEDIA_CAJA)
	)
	var consulta := PhysicsRayQueryParameters3D.create(
		cuerpo.global_position, cuerpo.global_position + Vector3.DOWN * Pila.HASTA_EL_PISO
	)
	consulta.exclude = [(cuerpo as CollisionObject3D).get_rid()]
	var golpe := almacen.get_world_3d().direct_space_state.intersect_ray(consulta)
	(
		assert_bool(golpe.has("position"))
		. override_failure_message("%s: `%s` no tiene nada debajo" % [donde, cuerpo.name])
		. is_true()
	)
	if not golpe.has("position"):
		return
	var hueco: float = cuerpo.global_position.y - (golpe["position"] as Vector3).y
	var media_altura := _limites_de(cuerpo).size.y / 2.0
	(
		assert_float(hueco)
		. override_failure_message(
			(
				"%s: `%s` quedó a %.3f m de lo que tiene debajo, y media altura suya es %.3f"
				% [donde, cuerpo.name, hueco, media_altura]
			)
		)
		. is_less_equal(media_altura + Pila.HOLGURA_DE_LA_CAIDA)
	)


## Que el producto que no estaba sobre la caja sigue dormido y donde estaba.
func _comprobar_que_no_se_movio(unidad: RigidBody3D, desde: Vector3, donde: String) -> void:
	(
		assert_bool(unidad.sleeping)
		. override_failure_message("%s: `%s` se despertó sin estar encima" % [donde, unidad.name])
		. is_true()
	)
	(
		assert_float(unidad.global_position.distance_to(desde))
		. override_failure_message(
			"%s: `%s` se movió de %v a %v" % [donde, unidad.name, desde, unidad.global_position]
		)
		. is_less(Pila.HOLGURA_DEL_APOYO)
	)


func test_levantar_la_caja_hace_caer_el_producto_apoyado_encima() -> void:
	# La cascada que desarma una pila lo tiene que despertar también a él, y sólo a él: el
	# producto del piso, a un metro, no estaba encima de nada.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja := _caja_en_el_piso_libre(almacen, 0)
	jugador.global_position = Pila.PISO_LIBRE_DEL_DEPOSITO + DELANTE_DE_LA_CAJA
	await get_tree().physics_frame
	var encima := await _producto_dormido_sobre(
		almacen, caja.global_position + Vector3.UP * Pila.MEDIA_CAJA
	)
	var lejos := await _producto_dormido_sobre(
		almacen, Pila.PISO_LIBRE_DEL_DEPOSITO + Vector3.RIGHT * A_UN_METRO
	)
	var altura := encima.global_position.y
	var donde_estaba := lejos.global_position
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(caja.get_parent()).is_same(jugador.get_node("PuntoDeCaja"))
	for cuadro in Pila.CUADROS_CAYENDO:
		await get_tree().physics_frame
	_comprobar_que_cayo(almacen, encima, altura, "al levantar la caja")
	_comprobar_que_no_se_movio(lejos, donde_estaba, "al levantar la caja")


func test_empujar_la_caja_hasta_sacarla_de_abajo_hace_caer_el_producto() -> void:
	# Empujar no levanta: la caja congelada se corre por debajo del producto dormido sin
	# avisarle, y cuando sale entera de abajo el producto se queda en el aire. Se empuja el
	# doble que el caso del arrastre, porque tiene que salir entera y no sólo moverse.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja := _caja_en_el_piso_libre(almacen, 0)
	jugador.global_position = Pila.PISO_LIBRE_DEL_DEPOSITO + DELANTE_DE_LA_CAJA
	jugador.rotation.y = 0.0
	await get_tree().physics_frame
	var encima := await _producto_dormido_sobre(
		almacen, caja.global_position + Vector3.UP * Pila.MEDIA_CAJA
	)
	var lejos := await _producto_dormido_sobre(
		almacen, Pila.PISO_LIBRE_DEL_DEPOSITO + Vector3.RIGHT * A_UN_METRO
	)
	var altura := encima.global_position.y
	var donde_estaba := lejos.global_position
	var huella := _limites_de(encima).size
	var media_huella := maxf(huella.x, huella.z) / 2.0
	var partida := caja.global_position
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	for cuadro in Pila.CUADROS_EMPUJANDO * 2:
		await get_tree().physics_frame
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)
	var corrida := (caja.global_position - partida).dot(Vector3.FORWARD)
	(
		assert_float(corrida)
		. override_failure_message(
			"la caja no salió de abajo del producto: se corrió %.3f m" % corrida
		)
		. is_greater(Pila.MEDIA_CAJA + media_huella)
	)
	for cuadro in Pila.CUADROS_CAYENDO:
		await get_tree().physics_frame
	_comprobar_que_cayo(almacen, encima, altura, "al empujar la caja")
	_comprobar_que_no_se_movio(lejos, donde_estaba, "al empujar la caja")


func test_el_producto_sobre_la_pila_cae_cuando_se_saca_la_caja_de_abajo() -> void:
	# La cascada llega hasta el producto de arriba de todo y no se corta en la última caja:
	# sacada la de abajo, la del medio cae, y el producto cae con ella.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var abajo := _caja_en_el_piso_libre(almacen, 0)
	var arriba := _caja_en_el_piso_libre(almacen, 1)
	jugador.global_position = Pila.PISO_LIBRE_DEL_DEPOSITO + DELANTE_DE_LA_CAJA
	await get_tree().physics_frame
	var encima := await _producto_dormido_sobre(
		almacen, arriba.global_position + Vector3.UP * Pila.MEDIA_CAJA
	)
	var altura := encima.global_position.y
	var altura_de_arriba := arriba.global_position.y
	_accion(jugador, abajo, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(abajo.get_parent()).is_same(jugador.get_node("PuntoDeCaja"))
	for cuadro in Pila.CUADROS_CAYENDO:
		await get_tree().physics_frame
	_comprobar_que_cayo(almacen, arriba, altura_de_arriba, "al sacar la caja de abajo")
	_comprobar_que_cayo(almacen, encima, altura, "al sacar la caja de abajo de la pila")
