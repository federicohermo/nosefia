## La red de seguridad en un mundo chico: un piso, una pared gruesa y un objeto que se agarra.
extends GdUnitTestSuite

const OBJETO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")

## La pared ocupa de x = 2 a x = 6: más gruesa que cualquier anillo alrededor de un objeto.
const PARED := Vector3(4.0, 1.0, 0.0)

## Apoyado en el piso y metido cinco centímetros en la pared: a su lado hay piso libre.
const CONTRA_LA_PARED := Vector3(1.99, 0.08, 0.0)


func _cuerpo_estatico(raiz: Node3D, tamano: Vector3, lugar: Vector3) -> StaticBody3D:
	var cuerpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tamano
	forma.shape = caja
	cuerpo.add_child(forma)
	raiz.add_child(cuerpo)
	cuerpo.global_position = lugar
	return cuerpo


## Devuelve la red, con el piso, la pared, el jugador y un objeto quieto en el piso.
func _mundo() -> Array:
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	_cuerpo_estatico(raiz, Vector3(20.0, 1.0, 20.0), Vector3(0.0, -0.5, 0.0))
	_cuerpo_estatico(raiz, Vector3(4.0, 2.0, 4.0), PARED)
	var jugador := CharacterBody3D.new()
	var capsula := CollisionShape3D.new()
	capsula.shape = CapsuleShape3D.new()
	capsula.position = Vector3.UP
	jugador.add_child(capsula)
	raiz.add_child(jugador)
	jugador.global_position = Vector3(-2.0, 0.0, 0.0)
	var agarre := Agarre.new()
	raiz.add_child(agarre)
	var objeto: RigidBody3D = OBJETO.instantiate()
	raiz.add_child(objeto)
	objeto.global_position = Vector3(0.0, 0.08, 0.0)
	var red := RedDeSeguridad.new()
	red.agarre = agarre
	red.jugador = jugador
	raiz.add_child(red)
	await get_tree().physics_frame
	return [red, objeto, agarre, jugador]


func test_lo_que_no_se_superpone_no_se_toca() -> void:
	var mundo: Array = await _mundo()
	var red: RedDeSeguridad = mundo[0]
	var objeto: RigidBody3D = mundo[1]
	var antes := objeto.global_position
	red.revisar(objeto)
	assert_array(red.rescates).is_empty()
	assert_vector(objeto.global_position).is_equal(antes)


func test_lo_soltado_adentro_de_la_pared_sale_al_piso_al_lado_del_jugador() -> void:
	var mundo: Array = await _mundo()
	var red: RedDeSeguridad = mundo[0]
	var objeto: RigidBody3D = mundo[1]
	var agarre: Agarre = mundo[2]
	var jugador: CharacterBody3D = mundo[3]
	objeto.global_position = PARED
	agarre.objeto_soltado.emit(objeto)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(red.rescates.size()).is_equal(1)
	assert_int(red.rescates[0]["clase"]).is_equal(Rescate.Clase.DESHACER)
	assert_float(objeto.global_position.distance_to(jugador.global_position)).is_less(1.5)


func test_sin_ningun_lugar_libre_queda_donde_esta_y_se_registra() -> void:
	var mundo: Array = await _mundo()
	var red: RedDeSeguridad = mundo[0]
	var objeto: RigidBody3D = mundo[1]
	var jugador: CharacterBody3D = mundo[3]
	# El origen del objeto se tapa con la pared, y el jugador queda adentro de ella: no hay piso
	# a su lado.
	objeto.global_position = PARED
	objeto.set("_origen_en_el_mundo", objeto.global_transform)
	jugador.global_position = PARED + Vector3.UP * 5.0
	red.revisar(objeto)
	assert_int(red.rescates.size()).is_equal(1)
	assert_int(red.rescates[0]["clase"]).is_equal(Rescate.NINGUNO)
	assert_vector(objeto.global_position).is_equal(PARED)


func test_el_aviso_nombra_el_objeto_el_solido_y_la_posicion() -> void:
	var mundo: Array = await _mundo()
	var red: RedDeSeguridad = mundo[0]
	var objeto: RigidBody3D = mundo[1]
	objeto.global_position = PARED
	red.revisar(objeto)
	var aviso: String = red.rescates[0]["aviso"]
	assert_str(aviso).contains(str(objeto.name))
	assert_str(aviso).contains(str(red.rescates[0]["solido"].name))
	assert_str(aviso).contains(str(PARED))


## Deshacer va antes que buscar alrededor, y deja lo soltado adelante del jugador.
func test_lo_soltado_adentro_sale_adelante_del_jugador() -> void:
	var mundo: Array = await _mundo()
	var red: RedDeSeguridad = mundo[0]
	var objeto: RigidBody3D = mundo[1]
	var agarre: Agarre = mundo[2]
	var jugador: CharacterBody3D = mundo[3]
	# Como en el jugador, el cuerpo no gira: gira lo que cuelga de él. Mira hacia +X.
	var giro := Node3D.new()
	jugador.add_child(giro)
	giro.rotation.y = -PI / 2.0
	agarre.punto_de_respaldo = giro
	objeto.freeze = true
	objeto.global_position = CONTRA_LA_PARED
	agarre.objeto_soltado.emit(objeto)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(red.rescates[0]["clase"]).is_equal(Rescate.Clase.DESHACER)
	assert_float(objeto.global_position.x - jugador.global_position.x).is_greater(0.3)
