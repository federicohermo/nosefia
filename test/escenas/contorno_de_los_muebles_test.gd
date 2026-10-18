## Que el jugador choque con el contorno de una góndola y no con su malla.
##
## **La malla es cara de rozar**: caminar pegado al lateral de una cabecera llevaba el cuadro de
## la web a 80 ms. Lo que se afirma acá es el cableado que lo evita, no el tiempo, que depende de
## la máquina: el jugador ignora la malla, el contorno lo frena, y la malla sigue ahí para los
## productos que caen y para la mira.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
## Cada góndola, y hacia dónde camina el jugador para chocarla. Las dos del fondo están contra la
## pared del fondo: del otro lado está el depósito.
const GONDOLAS := {
	"Estructura/gondolanueva": Vector3.RIGHT,
	"Estructura/gondolanueva2": Vector3.RIGHT,
	"Estructura/gondolanueva_001": Vector3.FORWARD,
}

## Lo que el contorno le agrega a la malla de cada lado, a lo sumo, en metros.
const HOLGURA_DEL_CONTORNO := 0.05


func test_el_jugador_que_camina_contra_una_gondola_choca_con_su_contorno() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	for ruta: String in GONDOLAS:
		var gondola := almacen.get_node(ruta) as MeshInstance3D
		var caja := gondola.global_transform * gondola.get_aabb()
		var hacia: Vector3 = GONDOLAS[ruta]
		var desde := caja.get_center() - hacia * (caja.size.dot(hacia.abs()) / 2.0 + 0.6)
		desde.y = 0.11
		jugador.global_position = desde
		await get_tree().physics_frame
		var choque := jugador.move_and_collide(hacia, true)
		(
			assert_object(choque)
			. override_failure_message("%s no frena al jugador" % ruta)
			. is_not_null()
		)
		if choque != null:
			assert_object(choque.get_collider()).is_same(gondola.get_node("Contorno"))
		# A frenarlo lo frena la caja aunque la malla siga ahí, porque la envuelve. Lo que cuesta
		# es que el jugador la siga probando en cada paso, y eso lo dice la excepción.
		var malla := gondola.get_node("StaticBody3D")
		assert_bool(jugador.get_collision_exceptions().has(malla)).is_true()


## El contorno sigue a la malla: la envuelve entera, y no le sobra más que la holgura. **Achicar
## un estante en el `.blend` cambia la malla y no el contorno**: una cabecera que se achica deja
## una pared invisible delante de su mercadería, y un estante que crece asoma por fuera de la caja
## y el jugador lo atraviesa.
func test_el_contorno_envuelve_la_malla_sin_que_le_sobre() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	for ruta: String in GONDOLAS:
		var gondola := almacen.get_node(ruta) as MeshInstance3D
		var malla := gondola.global_transform * gondola.get_aabb()
		var cuerpo := gondola.get_node("Contorno") as StaticBody3D
		var contorno := gondola.global_transform * _limites_del_contorno(cuerpo)
		for eje in 3:
			var antes := malla.position[eje] - contorno.position[eje]
			var despues := contorno.end[eje] - malla.end[eje]
			var mensaje := (
				"%s: el contorno sobra %.3f y %.3f en el eje %d; va %s con tamaño %s"
				% [
					ruta,
					antes,
					despues,
					eje,
					malla.get_center() - gondola.global_position,
					malla.size + Vector3(2.0, 0.0, 2.0) * HOLGURA_DEL_CONTORNO,
				]
			)
			assert_float(antes).override_failure_message(mensaje).is_between(
				-0.001, HOLGURA_DEL_CONTORNO + 0.001
			)
			assert_float(despues).override_failure_message(mensaje).is_between(
				-0.001, HOLGURA_DEL_CONTORNO + 0.001
			)


func test_la_malla_de_la_gondola_sigue_siendo_la_colision_de_los_productos() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	for ruta: String in GONDOLAS:
		var malla := almacen.get_node(ruta + "/StaticBody3D") as StaticBody3D
		var contorno := almacen.get_node(ruta + "/Contorno") as StaticBody3D
		assert_int(malla.collision_layer & 1).is_equal(1)
		assert_int(contorno.collision_layer & 1).is_zero()


func test_un_producto_soltado_hacia_la_gondola_no_queda_adentro_de_ella() -> void:
	# El punto de soltado debe caer en el hueco real, desde ambos pasillos y la cabecera.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var agarre: Agarre = almacen.get("_agarre")
	var gondola := almacen.get_node("Estructura/gondolanueva") as MeshInstance3D
	var mueble := gondola.global_transform * gondola.get_aabb()
	var centro := mueble.get_center()
	var casos := [
		[
			Vector3(mueble.position.x - 0.8, 0.11, centro.z),
			Vector3(centro.x, 1.9, centro.z),
			Producto.Id.MALBARDO
		],
		[
			Vector3(mueble.end.x + 0.8, 0.11, centro.z),
			Vector3(centro.x, 0.5, centro.z),
			Producto.Id.MALBARDO
		],
		[
			Vector3(centro.x, 0.11, mueble.end.z + 0.8),
			Vector3(centro.x, 0.5, mueble.end.z - 2.1),
			Producto.Id.OREMOS
		],
	]
	var sueltas: Array[Node3D] = []
	for caso: Array in casos:
		jugador.global_position = caso[0]
		_mirar(jugador, caso[1])
		almacen.get("_reposicion_manual").retirar(caso[2])
		# Con el punto de soltado en el pasillo, lo soltado cae al piso y el caso no ejerce nada:
		# es lo que pasa si la góndola se angosta y los casos no se mueven con ella.
		(
			assert_bool(mueble.has_point(agarre.punto_de_soltado.global_position))
			. override_failure_message(
				"desde %v, el punto de soltado no cae en la góndola" % caso[0]
			)
			. is_true()
		)
		sueltas.append(agarre.soltar(true))
	for cuadro in 90:
		await get_tree().physics_frame
	for suelta in sueltas:
		(
			assert_bool(mueble.grow(-0.03).has_point(suelta.global_position))
			. override_failure_message(
				"quedó adentro de la góndola, en %v" % suelta.global_position
			)
			. is_false()
		)


func test_una_caja_chica_soltada_hacia_la_gondola_no_atraviesa_sus_solidos() -> void:
	# Los huecos entre bandejas pertenecen al AABB del mueble, pero no son metal. El resultado
	# se contrasta contra las formas actuales y sigue siendo recogible desde el pasillo.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var gondola := almacen.get_node("Estructura/gondolanueva") as MeshInstance3D
	var mueble := gondola.global_transform * gondola.get_aabb()
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[Producto.Id.MALBARDO]
	var mano: Node3D = jugador.get_node("Giro/PuntoDeCaja")
	jugador.set_physics_process(false)
	var centro := mueble.get_center()
	var desde := Vector3(mueble.position.x - 0.8, 0.11, centro.z)
	for caso: Array in [
		[desde, mueble.position + mueble.size * Vector3(0.5, 0.4, 0.25)],
		[desde, mueble.position + mueble.size * Vector3(0.5, 0.7, 0.25)],
		[desde, mueble.position + mueble.size * Vector3(0.5, 0.4, 0.75)],
		[
			Vector3(mueble.get_center().x, 0.11, mueble.end.z + 1.0),
			Vector3(mueble.get_center().x, mueble.position.y + 0.15, mueble.end.z - 0.1),
		],
	]:
		if caja.get_parent() != mano:
			_accion(jugador, caja)
		# Mirando al pasillo, la caja cae al piso y el caso no ejerce nada.
		(
			assert_bool(mueble.has_point(caso[1]))
			. override_failure_message("mirando %v no se mira la góndola" % caso[1])
			. is_true()
		)
		jugador.global_position = caso[0]
		_mirar(jugador, caso[1])
		for cuadro in 6:
			await get_tree().physics_frame
		_accion(jugador, caja)
		assert_object(caja.get_parent()).is_not_same(mano)
		await get_tree().physics_frame
		var forma: CollisionShape3D = caja.get_node("Cuerpo")
		var interior := BoxShape3D.new()
		interior.margin = 0.0
		interior.size = (
			LimitesDeForma.de(forma.shape).size * forma.global_basis.get_scale()
			- Vector3.ONE * 0.02
		)
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = interior
		consulta.transform = Transform3D(
			forma.global_basis.orthonormalized(), forma.global_position
		)
		consulta.collision_mask = 1 | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
		consulta.exclude = [caja.get_rid(), jugador.get_rid()]
		(
			assert_array(almacen.get_world_3d().direct_space_state.intersect_shape(consulta))
			. override_failure_message("la caja atraviesa un sólido mirando %v" % caso[1])
			. is_empty()
		)
		_mirar(jugador, caja.global_position)
		jugador.call("_leer_la_mira")
		assert_object(jugador.get("_enfocado")).is_same(caja)


func _accion(jugador: Node, objetivo: Node) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _mirar(jugador: CharacterBody3D, punto: Vector3) -> void:
	var control: ControlDelJugador = jugador.get("_control")
	var hacia := (
		punto - (jugador.global_position + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	)
	var yaw := atan2(-hacia.x, -hacia.z)
	var pitch := atan2(hacia.y, Vector2(hacia.x, hacia.z).length())
	var giro := Vector2(wrapf(control.yaw() - yaw, -PI, PI), control.pitch() - pitch)
	control.girar(giro / ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE)
	control.avanzar_el_dibujo(SuavizadoDelGiro.VENTANA)
	jugador.call("_aplicar_la_rotacion")
	jugador.force_update_transform()


## Unión local de las formas físicas habilitadas; no demuestra contacto ni rellena huecos.
func _limites_del_contorno(cuerpo: StaticBody3D) -> AABB:
	var salida := AABB()
	var primera := true
	for forma: CollisionShape3D in cuerpo.get_children():
		if forma.disabled or forma.shape == null:
			continue
		var parte := forma.transform * forma.shape.get_debug_mesh().get_aabb()
		salida = parte if primera else salida.merge(parte)
		primera = false
	return cuerpo.transform * salida


func test_el_ancho_del_contorno_compuesto_incluye_todas_sus_formas_habilitadas() -> void:
	var cuerpo: StaticBody3D = auto_free(StaticBody3D.new())
	for desplazamiento: float in [-1.0, 1.0, 100.0]:
		var forma := CollisionShape3D.new()
		var convexa := ConvexPolygonShape3D.new()
		var puntos := PackedVector3Array()
		for x: float in [-0.5, 0.5]:
			for y: float in [-0.5, 0.5]:
				for z: float in [-0.5, 0.5]:
					puntos.append(Vector3(x, y, z))
		convexa.points = puntos
		forma.shape = convexa
		forma.position.x = desplazamiento
		forma.disabled = desplazamiento == 100.0
		cuerpo.add_child(forma)
	var limites := _limites_del_contorno(cuerpo)
	assert_float(limites.position.x).is_equal_approx(-1.5, 0.00001)
	assert_float(limites.size.x).is_equal_approx(3.0, 0.00001)
