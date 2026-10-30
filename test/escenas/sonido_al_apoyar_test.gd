## Lo que suena al apoyar una cosa: cajas, bidones y el balde. Se cuenta cuántas veces se pidió el
## sonido del contacto al reproductor, porque el driver de los tests no mezcla.
extends GdUnitTestSuite

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const ESCENA_DEL_OBJETO := "res://src/escenas/objetos/objeto_agarrable.tscn"
const REPRODUCTOR := "Servicios/AudioDelAlmacen/Reproductor"

var _almacen: Node3D
var _agarre: Agarre
var _apoyos: Array[int] = []


func before_test() -> void:
	_almacen = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(_almacen)
	await get_tree().physics_frame
	(_almacen.get("_jugador") as Node3D).set_physics_process(false)
	_agarre = _almacen.get("_agarre")
	_apoyos.clear()
	var reproductor: ReproductorDeSonidos = _almacen.get_node(REPRODUCTOR)
	reproductor.sonido_pedido.connect(_anotar)


func _anotar(evento: EntradaSonora.Evento) -> void:
	if evento == EntradaSonora.Evento.OBJETO_SOLTADO:
		_apoyos.append(1)


## Lo levanta y lo suelta mirando al piso, que es como se apoya una caja a los pies.
func _levantar_y_apoyar(cuerpo: RigidBody3D) -> void:
	var camara: Camera3D = (_almacen.get("_jugador") as Node3D).get_node("Giro/Camara")
	camara.rotation = Vector3(-0.7, 0.0, 0.0)
	assert_bool(_agarre.pedir_agarrar(cuerpo.get("datos"), cuerpo)).is_true()
	_agarre.soltar(false)
	assert_object(_agarre.manos().sostenido()).is_null()


func test_apoyar_una_caja_suena_una_vez_por_apoyo() -> void:
	var caja: RigidBody3D = (_almacen.get("_cajas_de_productos") as Array)[0]
	for vez in 3:
		_levantar_y_apoyar(caja)
		assert_int(_apoyos.size()).is_equal(vez + 1)


func test_apoyar_un_bidon_suena_una_vez_por_apoyo() -> void:
	var bidon: RigidBody3D = _almacen.get_node("Objetos/JabonAzul")
	_levantar_y_apoyar(bidon)
	assert_int(_apoyos.size()).is_equal(1)
	_levantar_y_apoyar(bidon)
	assert_int(_apoyos.size()).is_equal(2)


func test_empujar_una_caja_no_repite_el_sonido() -> void:
	var caja: RigidBody3D = (_almacen.get("_cajas_de_productos") as Array)[0]
	_levantar_y_apoyar(caja)
	var al_apoyar := _apoyos.size()
	for _cuadro in 30:
		caja.call("empujar", Vector3(0.02, 0.0, 0.0))
		await get_tree().physics_frame
	assert_int(_apoyos.size()).is_equal(al_apoyar)


## Lo levanta y lo suelta con el `Agarre` real, y cuenta los contactos que avisó hasta que se quedó
## quieto. Los puntos del agarre están sobre el piso: lo suelta a caer.
func _contactos_de_una_caida(agarre: Agarre, objeto: ObjetoAgarrable) -> int:
	var contactos: Array[int] = []
	var al_contacto := func(_nodo: Node3D, _rapidez: float) -> void: contactos.append(1)
	objeto.contacto_recibido.connect(al_contacto)
	assert_bool(agarre.pedir_agarrar(objeto.datos, objeto)).is_true()
	for _cuadro in 5:
		await get_tree().physics_frame
	agarre.soltar(true)
	for _cuadro in 90:
		await get_tree().physics_frame
	objeto.contacto_recibido.disconnect(al_contacto)
	return contactos.size()


func test_el_objeto_avisa_cada_vez_que_cae_sobre_el_mismo_piso() -> void:
	var piso: StaticBody3D = auto_free(StaticBody3D.new())
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(20.0, 0.2, 20.0)
	forma.shape = caja
	piso.add_child(forma)
	add_child(piso)
	piso.global_position = Vector3(500.0, 0.0, 500.0)
	var agarre: Agarre = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	agarre.punto_de_soltado = auto_free(Node3D.new())
	agarre.punto_de_respaldo = auto_free(Node3D.new())
	for punto: Node3D in [agarre.punto_de_carga, agarre.punto_de_soltado, agarre.punto_de_respaldo]:
		piso.add_child(punto)
		punto.position = Vector3(0.0, 0.6, 0.0)
	var objeto: ObjetoAgarrable = auto_free(load(ESCENA_DEL_OBJETO).instantiate())
	piso.add_child(objeto)
	objeto.global_position = piso.global_position + Vector3(0.0, 0.6, 0.0)
	piso.collision_layer = objeto.collision_mask
	for vez in 3:
		var contactos := await _contactos_de_una_caida(agarre, objeto)
		(
			assert_int(contactos)
			. override_failure_message("la caída %d sobre el mismo piso no avisó" % (vez + 1))
			. is_greater(0)
		)
