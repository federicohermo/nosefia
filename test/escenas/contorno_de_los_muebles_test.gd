## Que el jugador choque con el contorno de una góndola y no con su malla.
##
## **La malla es cara de rozar**: caminar pegado al lateral de una cabecera llevaba el cuadro de
## la web a 80 ms. Lo que se afirma acá es el cableado que lo evita, no el tiempo, que depende de
## la máquina: el jugador ignora la malla, el contorno lo frena, y la malla sigue ahí para los
## productos que caen y para la mira.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
## Cada góndola, y hacia dónde camina el jugador para chocarla. Las dos del fondo están contra la
## pared del oeste: del otro lado no hay piso.
const GONDOLAS := {
	"Estructura/gondolanueva": Vector3.RIGHT,
	"Estructura/gondolanueva2": Vector3.RIGHT,
	"Estructura/gondolanueva_001": Vector3.LEFT,
	"Estructura/gondolanueva_002": Vector3.LEFT,
}


func test_el_jugador_que_camina_contra_una_gondola_choca_con_su_contorno() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	for ruta in GONDOLAS:
		var gondola := almacen.get_node(ruta) as MeshInstance3D
		var caja := gondola.global_transform * gondola.get_aabb()
		var hacia: Vector3 = GONDOLAS[ruta]
		var desde := caja.position.x - 0.6 if hacia == Vector3.RIGHT else caja.end.x + 0.6
		jugador.global_position = Vector3(desde, 0.1, caja.end.z - 0.3)
		await get_tree().physics_frame
		var choque := jugador.move_and_collide(hacia, true)
		(
			assert_object(choque)
			. override_failure_message("%s no frena al jugador" % ruta)
			. is_not_null()
		)
		assert_object(choque.get_collider()).is_same(gondola.get_node("Contorno"))
		# A frenarlo lo frena la caja aunque la malla siga ahí, porque la envuelve. Lo que cuesta
		# es que el jugador la siga probando en cada paso, y eso lo dice la excepción.
		var malla := gondola.get_node("StaticBody3D")
		assert_bool(jugador.get_collision_exceptions().has(malla)).is_true()


func test_la_malla_de_la_gondola_sigue_siendo_la_colision_de_los_productos() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	for ruta in GONDOLAS:
		var malla := almacen.get_node(ruta + "/StaticBody3D") as StaticBody3D
		var contorno := almacen.get_node(ruta + "/Contorno") as StaticBody3D
		assert_int(malla.collision_layer & 1).is_equal(1)
		assert_int(contorno.collision_layer & 1).is_zero()


func test_un_producto_soltado_hacia_la_gondola_no_queda_adentro_de_ella() -> void:
	# Adentro del mueble se pierde de vista y se superpone con la mercadería, que no tiene cuerpo.
	# Los tres casos están medidos: parado en el pasillo o frente a una cabecera, mirando una
	# bandeja, el punto de soltado cae en el hueco del estante, y ahí hay lugar libre.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var agarre: Agarre = almacen.get("_agarre")
	var gondola := almacen.get_node("Estructura/gondolanueva") as MeshInstance3D
	var mueble := gondola.global_transform * gondola.get_aabb()
	var casos := [
		[Vector3(-0.43, 0.11, -2.79), Vector3(1.44, 1.9, -2.79), Producto.Id.MALBARDO],
		[Vector3(3.07, 0.11, -2.79), Vector3(1.44, 0.5, -2.79), Producto.Id.MALBARDO],
		[Vector3(0.97, 0.11, 2.11), Vector3(0.97, 0.5, -1.28), Producto.Id.OREMOS],
	]
	var sueltas: Array[Node3D] = []
	for caso: Array in casos:
		jugador.global_position = caso[0]
		_mirar(jugador, caso[1])
		almacen.get("_reposicion_manual").retirar(caso[2])
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


func _mirar(jugador: CharacterBody3D, punto: Vector3) -> void:
	var control: ControlDelJugador = jugador.get("_control")
	var hacia := (
		punto - (jugador.global_position + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	)
	var yaw := atan2(-hacia.x, -hacia.z)
	var pitch := atan2(hacia.y, Vector2(hacia.x, hacia.z).length())
	var giro := Vector2(wrapf(control.yaw() - yaw, -PI, PI), control.pitch() - pitch)
	control.girar(giro / ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE)
	jugador.call("_aplicar_la_rotacion")
	jugador.force_update_transform()
