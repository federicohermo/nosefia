## El balde se lleva inclinado hacia la vista, y al soltarlo queda derecho: donde se mira, cerca
## de ahí sobre el mismo apoyo, o en el piso al lado del jugador.
##
## El jugador no corre su física: cada caso lo para, le apunta la vista y suelta.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const UtilDeLimpieza := preload("res://src/escenas/objetos/util_de_limpieza.gd")

const LAVATORIO := "Estructura/vanitory/StaticBody3D"
const MOSTRADOR := "Estructura/EscritorioComputadora"
const ESTANTE_DEL_DEPOSITO := "Estructura/gondola_deposito03_001/StaticBody3D/Volumen3"

## Hacia dónde mira quien suelta, en grados: 40° abajo inclinaba el balde, y se volcaba.
const MIRANDO_ABAJO := -40.0

## El piso se mira más abajo: el ojo está a 1,7 m y a 40° la mira lo toca a 2,64, fuera de su
## alcance.
const MIRANDO_AL_PISO := -45.0

## Cuánto puede quedar inclinado lo que queda derecho, en grados.
const DERECHO := 1.0

## Cuánto puede errarle la inclinación en la mano, en grados.
const TOLERANCIA_EN_LA_MANO := 0.5

## Cuánto puede separarse lo apoyado del punto, y moverse después, en metros.
const MISMO_LUGAR := 0.01

## A cuánto del jugador queda lo que va a su lado, como mucho, en metros.
const AL_LADO := 1.0

## Un tramo libre de la pared de la fachada, lejos de la ventanilla, de las góndolas y de la puerta.
const PARED_LIBRE := Vector2(-5.0, 7.871)

## Un tramo de piso libre del local, delante de donde arranca el jugador.
const PISO_LIBRE := Vector2(-1.91, 5.2)

## A cuánto de la caja se mira el piso, en metros: menos que el radio del balde.
const PEGADO_A_LA_CAJA := 0.05

## Media pared del hueco, y cuánto lugar deja adentro: el cuerpo mide 0,4 de radio.
const MEDIO_HUECO := 0.45
const GROSOR_DEL_HUECO := 0.5


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	return almacen


func _balde(almacen: Node3D) -> UtilDeLimpieza:
	return almacen.get_node("Objetos/Balde")


func _piso(almacen: Node3D) -> float:
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	return suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0


func _agarrar(almacen: Node3D, objeto: Node3D) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(objeto.get("datos"), objeto)).is_true()


## Gira la vista como lo haría el mouse, a un yaw y un pitch absolutos en radianes.
func _mirar(jugador: Node3D, giro: float, alto: float) -> void:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var evento := InputEventMouseMotion.new()
	evento.relative = (
		Vector2(jugador.get_node("Giro").rotation.y - giro, camara.rotation.x - alto)
		/ ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE
	)
	jugador.call("_unhandled_input", evento)
	(jugador.get("_control") as ControlDelJugador).avanzar_el_dibujo(SuavizadoDelGiro.VENTANA)
	jugador.call("_aplicar_la_rotacion")


## Para al jugador en `pie`, mirando hacia `hacia` con la vista `alto` grados arriba del horizonte.
func _parar(jugador: CharacterBody3D, pie: Vector2, hacia: Vector3, alto: float) -> void:
	jugador.global_position = Vector3(pie.x, jugador.global_position.y, pie.y)
	jugador.velocity = Vector3.ZERO
	_mirar(jugador, atan2(-hacia.x, -hacia.z), deg_to_rad(alto))
	await get_tree().physics_frame
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	assert_float(rad_to_deg(camara.global_rotation.x)).is_equal_approx(alto, 0.01)


## Para al jugador donde su mira, con ese rumbo y `alto` grados hacia abajo, toca `punto`.
func _mirar_a(jugador: CharacterBody3D, punto: Vector3, hacia: Vector3, alto: float) -> void:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var lejos := (camara.global_position.y - punto.y) / tan(deg_to_rad(-alto))
	var pie := punto - hacia * lejos
	await _parar(jugador, Vector2(pie.x, pie.z), hacia, alto)


## Lo que la mira toca, contra lo que el balde choca. Su máscara se pasa: en la mano vale cero.
func _golpe_de_la_mira(jugador: Node3D, cuerpo: RigidBody3D, mascara: int) -> Dictionary:
	var ojo: Transform3D = jugador.call("mira")
	var consulta := PhysicsRayQueryParameters3D.create(
		ojo.origin, ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA, mascara
	)
	consulta.exclude = [(jugador as CollisionObject3D).get_rid(), cuerpo.get_rid()]
	return jugador.get_world_3d().direct_space_state.intersect_ray(consulta)


static func _formas(cuerpo: RigidBody3D) -> Array[CollisionShape3D]:
	var formas: Array[CollisionShape3D] = []
	formas.assign(cuerpo.find_children("*", "CollisionShape3D", false, false))
	return formas


static func _base(cuerpo: RigidBody3D) -> float:
	var base := INF
	for forma in _formas(cuerpo):
		var limites := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		base = minf(base, limites.position.y)
	return base


## Si se superpone con algo: lo que choca con él, el contorno de los muebles y el jugador.
static func _encimado(cuerpo: RigidBody3D) -> bool:
	for forma in _formas(cuerpo):
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.collision_mask = cuerpo.collision_mask | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
		consulta.exclude = [cuerpo.get_rid()]
		if not cuerpo.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty():
			return true
	return false


static func _inclinacion(cuerpo: Node3D) -> float:
	return rad_to_deg(cuerpo.global_basis.y.angle_to(Vector3.UP))


static func _en_el_piso(vector: Vector3) -> Vector2:
	return Vector2(vector.x, vector.z)


func _dos_segundos_de_fisica() -> void:
	for cuadro in 2 * Engine.physics_ticks_per_second:
		await get_tree().physics_frame


func _comprobar_derecho(balde: Node3D, donde: String) -> void:
	(
		assert_float(_inclinacion(balde))
		. override_failure_message("%s, quedó inclinado %.1f°" % [donde, _inclinacion(balde)])
		. is_less(DERECHO)
	)


func _comprobar_la_mano_vacia(almacen: Node3D, donde: String) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	(
		assert_object(agarre.manos().sostenido())
		. override_failure_message("%s, el balde sigue en la mano" % donde)
		. is_null()
	)


## Derecho, con la base sobre `apoyo` y sin encimarse con nada.
func _comprobar_apoyado(balde: RigidBody3D, apoyo: float, donde: String) -> void:
	_comprobar_derecho(balde, donde)
	(
		assert_float(_base(balde) - apoyo)
		. override_failure_message(
			"%s, la base quedó a %.3f m del apoyo" % [donde, _base(balde) - apoyo]
		)
		. is_between(0.0, MISMO_LUGAR)
	)
	(
		assert_bool(_encimado(balde))
		. override_failure_message("%s, quedó encimado con algo" % donde)
		. is_false()
	)


## Sigue derecho y donde quedó después de dos segundos de física.
func _comprobar_que_se_queda(balde: RigidBody3D, donde: String) -> void:
	var quedo := balde.global_position
	await _dos_segundos_de_fisica()
	_comprobar_derecho(balde, donde + ", dos segundos después")
	(
		assert_float(balde.global_position.distance_to(quedo))
		. override_failure_message(
			"%s, se movió de %v a %v en dos segundos" % [donde, quedo, balde.global_position]
		)
		. is_less(MISMO_LUGAR)
	)


## Derecho en el piso, sin encimarse con nada y a menos de `AL_LADO` del jugador.
func _comprobar_al_lado(almacen: Node3D, balde: RigidBody3D, donde: String) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	_comprobar_la_mano_vacia(almacen, donde)
	_comprobar_apoyado(balde, _piso(almacen), donde)
	var lejos := _en_el_piso(balde.global_position - jugador.global_position).length()
	(
		assert_float(lejos)
		. override_failure_message("%s, quedó a %.2f m del jugador" % [donde, lejos])
		. is_less(AL_LADO)
	)


## El ángulo entre el eje del balde y el arriba de la vista, y de qué lado queda la boca.
func _comprobar_inclinado_en_la_mano(jugador: Node3D, balde: Node3D, donde: String) -> void:
	var vista: Transform3D = jugador.call("mira")
	var eje := vista.basis.inverse() * balde.global_basis.y
	(
		assert_float(rad_to_deg(eje.angle_to(Vector3.UP)))
		. override_failure_message(
			"%s, el balde va inclinado %.1f°" % [donde, rad_to_deg(eje.angle_to(Vector3.UP))]
		)
		. is_equal_approx(
			rad_to_deg(ReglasDeLaLimpieza.INCLINACION_DEL_BALDE_EN_LA_MANO), TOLERANCIA_EN_LA_MANO
		)
	)
	# La vista mira hacia su -z: con `z` positivo la boca queda del lado del jugador.
	(
		assert_float(eje.z)
		. override_failure_message("%s, la boca no mira hacia la vista" % donde)
		. is_greater(0.0)
	)


func test_el_balde_en_la_mano_va_inclinado_hacia_la_vista() -> void:  # AC-PLY-050
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var balde := _balde(almacen)
	for alto: float in [0.0, MIRANDO_ABAJO]:
		await _parar(jugador, PISO_LIBRE, Vector3.FORWARD, alto)
		_agarrar(almacen, balde)
		_comprobar_inclinado_en_la_mano(jugador, balde, "mirando %.0f°" % alto)
		agarre.soltar(true)
		await _dos_segundos_de_fisica()
		_comprobar_derecho(balde, "soltado mirando %.0f°" % alto)
	_agarrar(almacen, balde)
	assert_object(agarre.manos().sostenido()).is_same(balde.datos)
	_comprobar_inclinado_en_la_mano(jugador, balde, "vuelto a agarrar")


## Los cuatro apoyos: el punto que se mira, hacia dónde mira el jugador y cuánto baja la vista.
func _apoyos(almacen: Node3D) -> Dictionary[String, Array]:
	var piso := _piso(almacen)
	# Una caja chica sobre una grande: la tapa que se mira es la de una caja en una pila.
	var cajas: Array = almacen.get("_cajas_de_productos")
	var abajo: RigidBody3D = cajas[Producto.Id.SALADIK]
	var arriba: RigidBody3D = cajas[Producto.Id.ARVEJAS]
	var media_de_abajo := (abajo.get_node("Cuerpo") as Node3D).scale.y
	var media_de_arriba := (arriba.get_node("Cuerpo") as Node3D).scale.y
	var pila := Vector3(PISO_LIBRE.x + 2.0, piso, PISO_LIBRE.y)
	for caja: RigidBody3D in [abajo, arriba]:
		caja.global_basis = Basis.IDENTITY
	abajo.global_position = pila + Vector3.UP * media_de_abajo
	arriba.global_position = pila + Vector3.UP * (2.0 * media_de_abajo + media_de_arriba)
	abajo.call("quedarse_quieta")
	arriba.call("quedarse_quieta")
	var tabla: CollisionShape3D = almacen.get_node(ESTANTE_DEL_DEPOSITO)
	var estante := tabla.global_transform * tabla.shape.get_debug_mesh().get_aabb()
	var mostrador: MeshInstance3D = almacen.get_node(MOSTRADOR)
	var limites := mostrador.global_transform * mostrador.get_aabb()
	var brazo: CollisionShape3D = almacen.get_node(MOSTRADOR + "/StaticBody3D/Volumen")
	var tapa := limites.end.y
	return {
		"el piso libre":
		[Vector3(PISO_LIBRE.x, piso, PISO_LIBRE.y), Vector3.FORWARD, MIRANDO_ABAJO],
		"la tapa de una caja apilada":
		[
			pila + Vector3.UP * 2.0 * (media_de_abajo + media_de_arriba),
			Vector3.FORWARD,
			MIRANDO_ABAJO
		],
		"un estante del depósito":
		[
			Vector3(estante.position.x + 0.4, estante.end.y, estante.get_center().z),
			Vector3.FORWARD,
			MIRANDO_ABAJO
		],
		"el mostrador":
		[
			Vector3(limites.get_center().x + limites.size.x / 4.0, tapa, brazo.global_position.z),
			Vector3.BACK,
			MIRANDO_ABAJO
		],
	}


func test_el_balde_se_apoya_derecho_donde_se_mira() -> void:  # AC-PLY-051
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	# El piso a 40 grados entra al alcance con el ojo un poco mas bajo.
	# Se acondiciona la premisa del caso, sin cambiar la altura del juego.
	(jugador.get_node("Giro/Camara") as Camera3D).position.y = 1.5
	var agarre: Agarre = almacen.get("_agarre")
	var balde := _balde(almacen)
	var mascara := balde.collision_mask
	# Con agua: el balde se llena en el lavatorio, y el agua tiene que seguir a la vista.
	_agarrar(almacen, balde)
	jugador.set("_enfocado", almacen.get_node(LAVATORIO))
	var uso := InputEventAction.new()
	uso.action = ReglasDelJugador.ACCION_USAR
	uso.pressed = true
	jugador.call("_unhandled_input", uso)
	assert_bool(balde.carga.visible).is_true()
	var agua: Color = (balde.carga.material_override as StandardMaterial3D).albedo_color
	var apoyos := _apoyos(almacen)
	for donde: String in apoyos:
		var punto: Vector3 = apoyos[donde][0]
		await _mirar_a(jugador, punto, apoyos[donde][1], apoyos[donde][2])
		var golpe := _golpe_de_la_mira(jugador, balde, mascara)
		(
			assert_bool(golpe.is_empty())
			. override_failure_message("el caso no ejerce nada: la mira no toca %s" % donde)
			. is_false()
		)
		if golpe.is_empty():
			continue
		var toca: Vector3 = golpe["position"]
		var ojo: Transform3D = jugador.call("mira")
		assert_float(ojo.origin.distance_to(toca)).is_less(ReglasDelJugador.ALCANCE_DE_LA_MIRA)
		(
			assert_float(toca.distance_to(punto))
			. override_failure_message(
				"el caso no ejerce nada: la mira toca %v y %s está en %v" % [toca, donde, punto]
			)
			. is_less(0.03)
		)
		assert_float(golpe["normal"].y).is_greater(ReglasDeLosObjetos.APOYO_HORIZONTAL)
		agarre.soltar(true)
		_comprobar_la_mano_vacia(almacen, donde)
		_comprobar_apoyado(balde, toca.y, donde)
		var corrido := _en_el_piso(balde.global_position - toca).length()
		(
			assert_float(corrido)
			. override_failure_message(
				"sobre %s, la base quedó a %.3f m del punto que la mira toca" % [donde, corrido]
			)
			. is_less(MISMO_LUGAR)
		)
		await _comprobar_que_se_queda(balde, "sobre " + donde)
		assert_bool(balde.carga.visible).override_failure_message(donde).is_true()
		assert_that((balde.carga.material_override as StandardMaterial3D).albedo_color).is_equal(
			agua
		)
		_agarrar(almacen, balde)


func test_si_justo_ahi_no_entra_el_balde_queda_cerca_sobre_el_mismo_apoyo() -> void:  # AC-PLY-052
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var balde := _balde(almacen)
	var mascara := balde.collision_mask
	var ancho := (balde.get_node("Forma").shape as CylinderShape3D).radius * 2.0
	var piso := _piso(almacen)
	# Una caja en el piso, y la mira sobre el piso pegada a su cara de adelante: el balde no entra
	# justo ahí. La tapa de la caja es el otro apoyo, libre y más cerca que el piso libre.
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[Producto.Id.SALADIK]
	var media := (caja.get_node("Cuerpo") as Node3D).scale.x
	var punto := Vector3(PISO_LIBRE.x, piso, PISO_LIBRE.y)
	caja.global_basis = Basis.IDENTITY
	caja.global_position = punto + Vector3(0.0, media, -media - PEGADO_A_LA_CAJA)
	caja.call("quedarse_quieta")
	_agarrar(almacen, balde)
	await _mirar_a(jugador, punto, Vector3.FORWARD, MIRANDO_AL_PISO)
	var golpe := _golpe_de_la_mira(jugador, balde, mascara)
	assert_bool(golpe.is_empty()).is_false()
	if golpe.is_empty():
		return
	var toca: Vector3 = golpe["position"]
	assert_float(toca.distance_to(punto)).is_less(0.03)
	assert_float(golpe["normal"].y).is_greater(ReglasDeLosObjetos.APOYO_HORIZONTAL)
	assert_float(PEGADO_A_LA_CAJA).is_less(ancho / 2.0)
	agarre.soltar(true)
	_comprobar_la_mano_vacia(almacen, "pegado a la caja")
	_comprobar_apoyado(balde, toca.y, "pegado a la caja")
	var corrido := _en_el_piso(balde.global_position - toca).length()
	(
		assert_float(corrido)
		. override_failure_message(
			"pegado a la caja, quedó a %.3f m del punto: el ancho es %.3f" % [corrido, ancho]
		)
		. is_between(PEGADO_A_LA_CAJA, ancho)
	)


## Una rampa con la inclinación justo debajo del corte de horizontal, delante del jugador.
func _rampa(almacen: Node3D, centro: Vector3) -> StaticBody3D:
	var rampa := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(1.0, 0.05, 1.0)
	forma.shape = caja
	rampa.add_child(forma)
	almacen.add_child(rampa)
	rampa.global_transform = Transform3D(
		Basis(Vector3.RIGHT, acos(ReglasDeLosObjetos.APOYO_HORIZONTAL - 0.01)), centro
	)
	return rampa


func test_sin_apoyo_el_balde_queda_derecho_al_lado_del_jugador() -> void:  # AC-PLY-053
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var balde := _balde(almacen)
	var mascara := balde.collision_mask
	var piso := _piso(almacen)
	var pared := Vector2(PARED_LIBRE.x, PARED_LIBRE.y - 1.0)

	_agarrar(almacen, balde)
	await _parar(jugador, pared, Vector3.BACK, 0.0)
	var en_la_pared := _golpe_de_la_mira(jugador, balde, mascara)
	assert_bool(en_la_pared.is_empty()).is_false()
	assert_float(en_la_pared.get("normal", Vector3.UP).y).is_less(
		ReglasDeLosObjetos.APOYO_HORIZONTAL
	)
	agarre.soltar(true)
	_comprobar_al_lado(almacen, balde, "mirando una pared")

	_agarrar(almacen, balde)
	await _parar(jugador, PISO_LIBRE, Vector3.FORWARD, 30.0)
	assert_bool(_golpe_de_la_mira(jugador, balde, mascara).is_empty()).is_true()
	agarre.soltar(true)
	_comprobar_al_lado(almacen, balde, "mirando a nada al alcance")

	# La mopa acostada tiene una cabeza horizontal, pero no admite nada encima.
	var mopa: RigidBody3D = almacen.get_node("Objetos/Mopa")
	mopa.freeze = true
	var acostada := Basis(Vector3.BACK, PI / 2.0)
	mopa.global_transform = Transform3D(acostada, Vector3(PISO_LIBRE.x, piso + 0.09, PISO_LIBRE.y))
	_agarrar(almacen, balde)
	var cabeza := mopa.global_transform * Vector3(0.0836, -0.77, 0.0)
	await _mirar_a(jugador, cabeza, Vector3.FORWARD, MIRANDO_ABAJO)
	var en_la_mopa := _golpe_de_la_mira(jugador, balde, mascara)
	assert_object(en_la_mopa.get("collider")).is_same(mopa)
	assert_float(en_la_mopa.get("normal", Vector3.ZERO).y).is_greater(
		ReglasDeLosObjetos.APOYO_HORIZONTAL
	)
	agarre.soltar(true)
	_comprobar_al_lado(almacen, balde, "mirando la mopa")
	mopa.global_transform = mopa.call(ReglasDeLosObjetos.METODO_LUGAR_DE_ORIGEN)

	var centro := Vector3(PISO_LIBRE.x, piso + 0.8, PISO_LIBRE.y)
	var rampa := _rampa(almacen, centro)
	_agarrar(almacen, balde)
	await _mirar_a(jugador, centro, Vector3.FORWARD, MIRANDO_ABAJO)
	var en_la_rampa := _golpe_de_la_mira(jugador, balde, mascara)
	assert_object(en_la_rampa.get("collider")).is_same(rampa)
	assert_float(en_la_rampa.get("normal", Vector3.ZERO).y).is_between(
		ReglasDeLosObjetos.APOYO_HORIZONTAL - 0.02, ReglasDeLosObjetos.APOYO_HORIZONTAL - 0.001
	)
	agarre.soltar(true)
	_comprobar_al_lado(almacen, balde, "mirando una rampa")
	rampa.free()

	# A medio metro de la pared y mirando abajo, el balde saltaba 28 cm.
	_agarrar(almacen, balde)
	await _parar(jugador, Vector2(PARED_LIBRE.x, PARED_LIBRE.y - 0.5), Vector3.BACK, MIRANDO_ABAJO)
	var al_pie := _golpe_de_la_mira(jugador, balde, mascara)
	assert_bool(al_pie.is_empty()).is_false()
	assert_float(al_pie.get("normal", Vector3.UP).y).is_less(ReglasDeLosObjetos.APOYO_HORIZONTAL)
	agarre.soltar(true)
	_comprobar_al_lado(almacen, balde, "a medio metro de la pared")
	await _comprobar_que_se_queda(balde, "a medio metro de la pared")


func test_en_un_hueco_del_cuerpo_el_balde_no_vuelve_a_la_mano() -> void:  # AC-PLY-053
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var balde := _balde(almacen)
	await _parar(jugador, PISO_LIBRE, Vector3.FORWARD, MIRANDO_ABAJO)
	var lejos := MEDIO_HUECO + GROSOR_DEL_HUECO / 2.0
	var largo := 2.0 * (MEDIO_HUECO + GROSOR_DEL_HUECO)
	for lado: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var pared := StaticBody3D.new()
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(
			GROSOR_DEL_HUECO if lado.x != 0.0 else largo,
			3.0,
			GROSOR_DEL_HUECO if lado.z != 0.0 else largo
		)
		forma.shape = caja
		pared.add_child(forma)
		almacen.add_child(pared)
		pared.global_position = jugador.global_position + lado * lejos + Vector3.UP * 1.5
	await get_tree().physics_frame
	_agarrar(almacen, balde)
	agarre.soltar(true)
	_comprobar_la_mano_vacia(almacen, "en un hueco")
	_comprobar_derecho(balde, "en un hueco")
	# Sin lugar al lado: quedó adentro del hueco, donde lo dejó el barrido.
	var afuera := _en_el_piso(balde.global_position - jugador.global_position).length()
	assert_float(afuera).is_less(MEDIO_HUECO)
	# Vaciar las manos tampoco encuentra lugar al lado: queda a los pies, y derecho igual.
	_agarrar(almacen, balde)
	agarre.vaciar_las_manos()
	_comprobar_la_mano_vacia(almacen, "al vaciar las manos en un hueco")
	_comprobar_derecho(balde, "al vaciar las manos en un hueco")


func test_vaciar_las_manos_deja_el_balde_derecho_a_los_pies() -> void:
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var balde := _balde(almacen)
	await _parar(jugador, PISO_LIBRE, Vector3.FORWARD, MIRANDO_AL_PISO)
	_agarrar(almacen, balde)
	agarre.vaciar_las_manos()
	assert_object(agarre.manos().sostenido()).is_null()
	_comprobar_al_lado(almacen, balde, "al vaciar las manos")
	await _comprobar_que_se_queda(balde, "al vaciar las manos")
