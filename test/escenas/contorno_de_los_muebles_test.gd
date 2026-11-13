## Que el jugador choque con el contorno de una góndola y no con su malla.
##
## **La malla es cara de rozar**: caminar pegado al lateral de una cabecera llevaba el cuadro de
## la web a 80 ms. Lo que se afirma acá es el cableado que lo evita, no el tiempo, que depende de
## la máquina: el jugador ignora la malla, el contorno lo frena, y la malla sigue ahí para los
## productos que caen y para la mira.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
const LadosDelMueble := preload("res://test/escenas/lados_del_mueble.gd")
## Cada góndola. Los lados donde el jugador se para para chocarla salen del mueble y de la escena:
## sólo cuentan los que tienen lugar para pararse. Las dos del fondo están contra la pared del
## fondo: del otro lado está el depósito.
const GONDOLAS := [
	"Estructura/gondolanueva",
	"Estructura/gondolanueva2",
	"Estructura/gondolanueva_001",
]

## A cuánto de la cara de la góndola se para el jugador para chocarla.
const DISTANCIA_AL_COSTADO := 0.6
## A cuánto de la cara se para quien suelta algo hacia la góndola.
const DISTANCIA_PARA_SOLTAR := 0.8
## A cuánto de la cabecera se para quien suelta una caja chica hacia ella.
const DISTANCIA_A_LA_CABECERA := 1.0
## Hacia qué alto mira quien suelta algo hacia la góndola, con la mano alta y con la baja.
const ALTURA_ALTA := 1.9
const ALTURA_BAJA := 0.5
## Cuánto fondo tiene que tener la góndola para apuntarle al piso: más angosta, la mano cae antes.
const FONDO_PARA_APUNTAR_AL_PISO := 0.9
## Cuánto entra en la cabecera el punto que mira quien suelta una caja chica, en metros.
const MEDIDA_DENTRO_DE_LA_CABECERA := 0.1
## Los huecos del costado que se miran, como fracción del largo y del alto del mueble.
const HUECOS_DEL_COSTADO := [[-0.25, 0.4], [-0.25, 0.7], [0.25, 0.4]]

## Lo que el contorno le agrega a la malla de cada lado, a lo sumo, en metros.
const HOLGURA_DEL_CONTORNO := 0.05


func test_el_jugador_que_camina_contra_una_gondola_choca_con_su_contorno() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	for ruta: String in GONDOLAS:
		var gondola := almacen.get_node(ruta) as MeshInstance3D
		var costados := LadosDelMueble.libres(almacen, gondola, DISTANCIA_AL_COSTADO, false)
		(
			assert_array(costados)
			. override_failure_message("%s no tiene un costado con lugar para pararse" % ruta)
			. is_not_empty()
		)
		for costado in costados:
			jugador.global_position = LadosDelMueble.pie_junto_a(
				gondola, costado, DISTANCIA_AL_COSTADO
			)
			await get_tree().physics_frame
			var choque := jugador.move_and_collide(-costado.hacia, true)
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
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
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
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	for ruta: String in GONDOLAS:
		var malla := almacen.get_node(ruta + "/StaticBody3D") as StaticBody3D
		var contorno := almacen.get_node(ruta + "/Contorno") as StaticBody3D
		assert_int(malla.collision_layer & 1).is_equal(1)
		assert_int(contorno.collision_layer & 1).is_zero()


func test_un_producto_soltado_hacia_la_gondola_no_queda_adentro_de_ella() -> void:
	# El punto de soltado debe caer en el hueco real, desde ambos pasillos y la cabecera.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var agarre: Agarre = almacen.get("_agarre")
	var gondola := almacen.get_node("Estructura/gondolanueva") as MeshInstance3D
	var mueble := LadosDelMueble.pieza(gondola)
	var centro := mueble.get_center()
	var casos := []
	var costados := LadosDelMueble.libres(almacen, gondola, DISTANCIA_PARA_SOLTAR, false)
	var cabeceras := LadosDelMueble.libres(almacen, gondola, DISTANCIA_PARA_SOLTAR, true)
	# Una góndola contra la pared puede no tener cabecera con lugar para pararse.
	assert_array(costados + cabeceras).is_not_empty()
	for costado in costados:
		var alturas: Array[float] = [ALTURA_ALTA]
		if costado.mitad * 2.0 >= FONDO_PARA_APUNTAR_AL_PISO:
			alturas.append(ALTURA_BAJA)
		for altura: float in alturas:
			casos.append(
				[
					LadosDelMueble.pie_junto_a(gondola, costado, DISTANCIA_PARA_SOLTAR),
					Vector3(centro.x, altura, centro.z),
					Producto.Id.MALBARDO
				]
			)
	for cabecera in cabeceras:
		casos.append(
			[
				LadosDelMueble.pie_junto_a(gondola, cabecera, DISTANCIA_PARA_SOLTAR),
				Vector3(centro.x, ALTURA_BAJA, centro.z),
				Producto.Id.OREMOS
			]
		)
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
				(
					"desde %v mirando %v, el punto de soltado %v no cae en la góndola"
					% [caso[0], caso[1], agarre.punto_de_soltado.global_position]
				)
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
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var gondola := almacen.get_node("Estructura/gondolanueva") as MeshInstance3D
	var mueble := LadosDelMueble.pieza(gondola)
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[Producto.Id.MALBARDO]
	var mano: Node3D = jugador.get_node("Giro/PuntoDeCaja")
	jugador.set_physics_process(false)
	var casos := []
	var costados := LadosDelMueble.libres(almacen, gondola, DISTANCIA_PARA_SOLTAR, false)
	var cabeceras := LadosDelMueble.libres(almacen, gondola, DISTANCIA_A_LA_CABECERA, true)
	# Una góndola contra la pared puede no tener cabecera con lugar para pararse.
	assert_array(costados + cabeceras).is_not_empty()
	for costado in costados:
		var desde := LadosDelMueble.pie_junto_a(gondola, costado, DISTANCIA_PARA_SOLTAR)
		var a_lo_largo := costado.hacia.cross(Vector3.UP)
		var largo := mueble.size.dot(a_lo_largo.abs())
		for hueco: Array in HUECOS_DEL_COSTADO:
			var punto := (
				mueble.get_center()
				+ a_lo_largo * largo * float(hueco[0])
				+ Vector3.UP * mueble.size.y * float(hueco[1])
				- Vector3.UP * mueble.size.y / 2.0
			)
			casos.append([desde, punto])
	for cabecera in cabeceras:
		var punto := (
			mueble.get_center() + cabecera.hacia * (cabecera.mitad - MEDIDA_DENTRO_DE_LA_CABECERA)
		)
		punto.y = mueble.position.y + 0.15
		casos.append(
			[LadosDelMueble.pie_junto_a(gondola, cabecera, DISTANCIA_A_LA_CABECERA), punto]
		)
	for caso: Array in casos:
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


## La fachada de madera del fondo no tiene malla de colisión propia: lo único que frena es su
## `Contorno`. Los puntos salen de su caja envolvente y de las cajas del contorno, y cada disparo
## va a un montante o a una cabecera, nunca a un hueco de heladera ni al de la góndola.
func _disparos_contra_la_fachada_del_fondo(fachada: AABB, contorno: Node3D) -> Array[Dictionary]:
	var centro_z := fachada.position.z + fachada.size.z / 2.0
	var derecha := fachada.end.x - 0.1
	var izquierda := fachada.position.x + 0.1
	var del_medio := (contorno.get_node("MontanteDelMedio") as Node3D).global_position.x
	var cabecera := fachada.get_center().x
	var cabecera_de_la_gondola := (
		(contorno.get_node("CabeceraDeLaGondola") as Node3D).global_position.x
	)
	var casos: Array[Dictionary] = []
	for altura: float in [0.2, 1.5, 3.2]:
		casos.append(
			{
				"desde": Vector3(fachada.end.x + 0.6, altura, centro_z),
				"hacia": Vector3.LEFT,
				"cara": fachada.end.x
			}
		)
		for x: float in [derecha, izquierda, del_medio]:
			casos.append(
				{
					"desde": Vector3(x, altura, fachada.end.z + 0.6),
					"hacia": Vector3.FORWARD,
					"cara": fachada.end.z
				}
			)
	for x: float in [cabecera, cabecera_de_la_gondola]:
		casos.append(
			{
				"desde": Vector3(x, 3.2, fachada.end.z + 0.6),
				"hacia": Vector3.FORWARD,
				"cara": fachada.end.z
			}
		)
	return casos


func test_un_producto_tirado_contra_la_madera_del_fondo_no_la_atraviesa() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	await get_tree().physics_frame
	var fachada_malla := almacen.get_node("Estructura/mueble_continuo") as MeshInstance3D
	var fachada := fachada_malla.global_transform * fachada_malla.get_aabb()
	var mitad := 0.05
	var contorno := fachada_malla.get_node("Contorno") as Node3D
	for caso: Dictionary in _disparos_contra_la_fachada_del_fondo(fachada, contorno):
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3.ONE * mitad * 2.0
		forma.shape = caja
		var producto: RigidBody3D = auto_free(RigidBody3D.new())
		producto.add_child(forma)
		producto.collision_layer = 0
		producto.collision_mask = ReglasDeLosObjetos.MASCARA_DEL_PRODUCTO
		producto.gravity_scale = 0.0
		producto.can_sleep = false
		add_child(producto)
		var hacia: Vector3 = caso["hacia"]
		producto.global_position = caso["desde"]
		producto.linear_velocity = hacia * 4.0
		for cuadro in 40:
			await get_tree().physics_frame
		var eje := 0 if absf(hacia.x) > 0.5 else 2
		# Frena del lado de afuera: llegó hasta la cara, y no pasó de largo.
		var afuera := -hacia[eje] * (producto.global_position[eje] - float(caso["cara"]))
		(
			assert_float(afuera)
			. override_failure_message(
				"desde %v hacia %v quedó en %v" % [caso["desde"], hacia, producto.global_position]
			)
			. is_between(0.0, mitad + 0.05)
		)
		producto.queue_free()


func test_el_jugador_que_camina_contra_la_madera_del_fondo_choca_con_su_contorno() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var fachada_malla := almacen.get_node("Estructura/mueble_continuo") as MeshInstance3D
	var fachada := fachada_malla.global_transform * fachada_malla.get_aabb()
	# El montante del extremo derecho da a un pasillo libre. El izquierdo está pegado a la pared,
	# y el cuerpo del jugador chocaría antes contra ella.
	var x := fachada.end.x - 0.1
	jugador.global_position = Vector3(x, 0.11, fachada.end.z + 0.6)
	await get_tree().physics_frame
	var choque := jugador.move_and_collide(Vector3.FORWARD, true)
	(
		assert_object(choque)
		. override_failure_message("la madera del fondo no frena al jugador")
		. is_not_null()
	)
	if choque != null:
		assert_object(choque.get_collider()).is_same(fachada_malla.get_node("Contorno"))


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
