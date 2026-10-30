## Lo que suena al apoyar una cosa: cajas, bidones y el balde. Se cuenta cuántas veces se pidió el
## sonido del contacto al reproductor, porque el driver de los tests no mezcla.
extends GdUnitTestSuite

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const ESCENA_DEL_OBJETO := "res://src/escenas/objetos/objeto_agarrable.tscn"
const REPRODUCTOR := "Servicios/AudioDelAlmacen/Reproductor"
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")

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


## Un piso liso y despejado donde parar al jugador, para apilar sin muebles de por medio.
func _piso_liso_para(jugador: Node3D, capa: int) -> void:
	var piso: StaticBody3D = auto_free(StaticBody3D.new())
	var forma := CollisionShape3D.new()
	var plano := BoxShape3D.new()
	plano.size = Vector3(20.0, 0.2, 20.0)
	forma.shape = plano
	piso.add_child(forma)
	piso.collision_layer = capa
	add_child(piso)
	piso.global_position = Vector3(500.0, -0.1, 500.0)
	jugador.global_position = Vector3(500.0, 0.05, 500.0)


func test_apilar_una_caja_sobre_otra_suena_una_vez_por_apoyo() -> void:
	var cajas: Array = _almacen.get("_cajas_de_productos")
	var de_abajo: RigidBody3D = cajas[0]
	var de_arriba: RigidBody3D = cajas[1]
	var jugador: Node3D = _almacen.get("_jugador")
	_piso_liso_para(jugador, de_abajo.collision_mask)
	# La segunda caja arranca fuera del juego, sin colisiones; acá es una más del local.
	de_arriba.collision_layer = de_abajo.collision_layer
	de_arriba.collision_mask = de_abajo.collision_mask
	de_abajo.freeze = false
	de_abajo.global_position = jugador.global_position + jugador.call("frente") * 1.2 + Vector3.UP
	for _cuadro in 40:
		await get_tree().physics_frame
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.look_at(de_abajo.global_position)
	for vez in 2:
		var antes := _apoyos.size()
		assert_bool(_agarre.pedir_agarrar(de_arriba.get("datos"), de_arriba)).is_true()
		_agarre.soltar(true)
		(
			assert_float(de_arriba.global_position.y)
			. override_failure_message("la caja %d no quedó encima de la otra" % (vez + 1))
			. is_greater(de_abajo.global_position.y)
		)
		assert_int(_apoyos.size() - antes).is_equal(1)


## Un punto sobre el piso, en el medio del primer volumen de un cuarto, en coordenadas del mundo.
func _centro_del(cuartos: Array[AABB]) -> Vector3:
	var habitaciones: Node3D = _almacen.get("_habitaciones")
	var volumen := cuartos[0]
	var sobre_el_piso := (
		volumen.get_center() * Vector3(1, 0, 1) + Vector3.UP * (volumen.position.y + 0.05)
	)
	return habitaciones.to_global(sobre_el_piso)


## El balde se levanta y se suelta con el `Agarre` y el `Jugador` reales, tal como lo devuelve al
## mundo el juego, y se espera a que se quede quieto: lo que avisa es el contacto con el piso.
func _apoyar_el_balde_en(
	balde: RigidBody3D, piso: Vector3, esperado: ReglasDelCierre.Habitacion
) -> int:
	var jugador: Node3D = _almacen.get("_jugador")
	var habitaciones: Node3D = _almacen.get("_habitaciones")
	jugador.global_position = piso
	assert_int(habitaciones.de(jugador.global_position)).is_equal(esperado)
	var antes := _apoyos.size()
	assert_bool(_agarre.pedir_agarrar(balde.get("datos"), balde)).is_true()
	await get_tree().physics_frame
	_agarre.soltar(true)
	for _cuadro in 60:
		await get_tree().physics_frame
	return _apoyos.size() - antes


func test_el_balde_suena_cada_vez_que_se_apoya_en_cada_cuarto() -> void:
	var habitaciones: Node3D = _almacen.get("_habitaciones")
	var balde: RigidBody3D = _almacen.get_node("Objetos/Balde")
	var camara: Camera3D = (_almacen.get("_jugador") as Node3D).get_node("Giro/Camara")
	camara.rotation = Vector3(-0.7, 0.0, 0.0)
	var recorrido := {
		ReglasDelCierre.Habitacion.BANO: habitaciones.bano,
		ReglasDelCierre.Habitacion.LOCAL: habitaciones.local,
		ReglasDelCierre.Habitacion.DEPOSITO: habitaciones.deposito,
	}
	var cuartos: Array[ReglasDelCierre.Habitacion] = [
		ReglasDelCierre.Habitacion.BANO,
		ReglasDelCierre.Habitacion.LOCAL,
		ReglasDelCierre.Habitacion.DEPOSITO,
		ReglasDelCierre.Habitacion.BANO,
	]
	for cuarto: ReglasDelCierre.Habitacion in cuartos:
		for vez in 3:
			var sonidos := await _apoyar_el_balde_en(balde, _centro_del(recorrido[cuarto]), cuarto)
			(
				assert_int(sonidos)
				. override_failure_message("el balde apoyado la vez %d no sonó una vez" % (vez + 1))
				. is_equal(1)
			)


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
