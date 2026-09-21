## Que el jugador choque con el contorno de una góndola y no con su malla.
##
## **La malla es cara de rozar**: caminar pegado al lateral de una cabecera llevaba el cuadro de
## la web a 80 ms. Lo que se afirma acá es el cableado que lo evita, no el tiempo, que depende de
## la máquina: el jugador ignora la malla, el contorno lo frena, y la malla sigue ahí para los
## productos que caen y para la mira.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const GONDOLAS := ["Estructura/gondolanueva", "Estructura/gondolanueva2"]


func test_el_jugador_que_camina_contra_una_gondola_choca_con_su_contorno() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	for ruta in GONDOLAS:
		var gondola := almacen.get_node(ruta) as MeshInstance3D
		var caja := gondola.global_transform * gondola.get_aabb()
		jugador.global_position = Vector3(caja.position.x - 0.6, 0.1, caja.end.z - 0.3)
		await get_tree().physics_frame
		var choque := jugador.move_and_collide(Vector3(1.0, 0.0, 0.0), true)
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
