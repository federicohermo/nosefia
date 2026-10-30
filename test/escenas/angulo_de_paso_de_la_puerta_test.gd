## El ángulo de paso de cada hoja de paso es el menor al que la cápsula del jugador cruza el vano.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

## Las hojas interiores por las que el jugador pasa: el depósito, el baño y sus dos cabinas.
const HOJAS := ["puerta", "puerta2", "bano_puerta_1", "bano_puerta_2"]

## Cuántos cuadros se espera a que el motor registre la pose de la hoja.
const CUADROS_DE_ASENTAMIENTO := 3

## A qué distancia del vano empieza el jugador, y cuánto avanza para cruzarlo.
const DISTANCIA_DE_PARTIDA := 1.2

## Cuántos puntos se prueban a lo ancho del hueco que deja la hoja, a cada lado del centro.
const PUNTOS_A_CADA_LADO := 6
const SEPARACION_DE_PUNTOS := 0.05

## Separación del piso de la que parte el jugador.
const SEPARACION_DEL_PISO := 0.01


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	# La primera noche traba estas puertas y estos casos miden la hoja, no la traba.
	for nombre: String in HOJAS:
		_cuerpo_de(almacen, nombre).set("traba", 0)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	return almacen


func _hoja_de(almacen: Node3D, nombre: String) -> MeshInstance3D:
	return almacen.get_node("Estructura/" + nombre)


func _cuerpo_de(almacen: Node3D, nombre: String) -> PhysicsBody3D:
	for hijo in _hoja_de(almacen, nombre).get_children():
		if hijo.has_method("puerta"):
			return hijo
	return null


## Deja la hoja cerrada en `angulo` y quieta, sin que el giro la mueva.
func _dejar_la_hoja_en(cuerpo: PhysicsBody3D, angulo: float) -> void:
	cuerpo.set_physics_process(false)
	cuerpo.call("cerrar_de_golpe")
	var puerta: Puerta = cuerpo.call("puerta")
	puerta.alternar()
	puerta.avanzar(angulo / Puerta.VELOCIDAD_DEL_GIRO)
	cuerpo.call("_physics_process", 0.0)
	for cuadro in CUADROS_DE_ASENTAMIENTO:
		await get_tree().physics_frame


## Cruza la cápsula por el hueco, en uno de los dos sentidos y desde un punto del hueco.
func _cruza(
	almacen: Node3D, nombre: String, angulo: float, sentido: float, desplazamiento: float
) -> bool:
	var cuerpo := _cuerpo_de(almacen, nombre)
	await _dejar_la_hoja_en(cuerpo, angulo)
	var geometria := _geometria(almacen, nombre)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var largo: float = geometria["largo"]
	var proyeccion: float = largo * cos(angulo) + geometria["espesor"] * sin(angulo)
	var centro_del_hueco: float = (proyeccion + largo) / 2.0 + desplazamiento
	var cruce: Vector3 = geometria["bisagra"] + geometria["brazo"] * centro_del_hueco
	var por_donde: Vector3 = geometria["canto"] * sentido
	var partida := cruce - por_donde * DISTANCIA_DE_PARTIDA
	partida.y = geometria["piso"] + SEPARACION_DEL_PISO
	jugador.global_position = partida
	jugador.velocity = Vector3.ZERO
	await get_tree().physics_frame
	if not _partida_libre(jugador):
		return false
	var choque := jugador.move_and_collide(por_donde * DISTANCIA_DE_PARTIDA * 2.0)
	return choque == null


func _partida_libre(jugador: CharacterBody3D) -> bool:
	var espacio := jugador.get_world_3d().direct_space_state
	for forma: CollisionShape3D in jugador.find_children("*", "CollisionShape3D", false, false):
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.collision_mask = jugador.collision_mask
		consulta.exclude = [jugador.get_rid()]
		if not espacio.intersect_shape(consulta, 1).is_empty():
			return false
	return true


## La hoja cerrada en el plano, medida desde su bisagra: el brazo hacia su centro, el canto que
## lo cruza, el largo y el espesor, y la altura del piso.
func _geometria(almacen: Node3D, nombre: String) -> Dictionary:
	var hoja := _hoja_de(almacen, nombre)
	var cuerpo := _cuerpo_de(almacen, nombre)
	var padre: Transform3D = hoja.global_transform * hoja.transform.affine_inverse()
	var cerrada: Transform3D = cuerpo.get("_cerrada")
	var bisagra: Vector3 = padre * cuerpo.get("_bisagra")
	var caja := hoja.get_aabb()
	var centro: Vector3 = padre * cerrada * caja.get_center() - bisagra
	centro.y = 0.0
	var brazo := centro.normalized()
	var canto := Vector3.UP.cross(brazo)
	var lejos := -INF
	var ancho_menor := INF
	var espesor_mayor := -INF
	var espesor_menor := INF
	for indice in 8:
		var radio: Vector3 = padre * cerrada * caja.get_endpoint(indice) - bisagra
		lejos = maxf(lejos, radio.dot(brazo))
		ancho_menor = minf(ancho_menor, radio.dot(brazo))
		espesor_mayor = maxf(espesor_mayor, radio.dot(canto))
		espesor_menor = minf(espesor_menor, radio.dot(canto))
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	return {
		"bisagra": bisagra,
		"brazo": brazo,
		"canto": canto,
		"largo": lejos,
		"espesor": espesor_mayor - espesor_menor,
		"piso": suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0,
	}


## Si la cápsula cruza el vano con la hoja en `angulo`, en algún punto del hueco y en el sentido
## pedido.
func _cruza_en_algun_punto(almacen: Node3D, nombre: String, angulo: float, sentido: float) -> bool:
	for punto in range(-PUNTOS_A_CADA_LADO, PUNTOS_A_CADA_LADO + 1):
		if await _cruza(almacen, nombre, angulo, sentido, punto * SEPARACION_DE_PUNTOS):
			return true
	return false


## El menor número entero de grados al que cruza, buscado por bisección. Parte de que cruza con
## la hoja abierta del todo.
func _grados_de_paso(almacen: Node3D, nombre: String, sentido: float) -> int:
	var sin_paso := 0
	var con_paso := 90
	while con_paso - sin_paso > 1:
		var medio := (sin_paso + con_paso) / 2
		if await _cruza_en_algun_punto(almacen, nombre, deg_to_rad(medio), sentido):
			con_paso = medio
		else:
			sin_paso = medio
	return con_paso


## Lo medido en una hoja: el ángulo adoptado, si cruza con la hoja abierta y desde qué grado
## cruza, en cada sentido.
func _medir(nombre: String) -> Dictionary:
	var almacen: Node3D = await _almacen()
	var adoptado := roundi(rad_to_deg(_cuerpo_de(almacen, nombre).get("_angulo_de_paso")))
	var medida := {"adoptado": adoptado, "abierta": [], "desde": []}
	for sentido: float in [1.0, -1.0]:
		medida["abierta"].append(
			await _cruza_en_algun_punto(almacen, nombre, Puerta.ANGULO_ABIERTA, sentido)
		)
		medida["desde"].append(await _grados_de_paso(almacen, nombre, sentido))
	return medida


func test_el_angulo_de_paso_del_deposito_es_el_que_cruza_la_capsula() -> void:  # AC-PLY-147
	var medida := await _medir("puerta")
	assert_array(medida["abierta"]).contains_exactly([true, true])
	(
		assert_array(medida["desde"])
		. override_failure_message(
			"puerta cruza desde %s° y se adoptó %d°" % [medida["desde"], medida["adoptado"]]
		)
		. contains_exactly([medida["adoptado"], medida["adoptado"]])
	)


func test_el_angulo_de_paso_de_la_segunda_hoja_es_el_que_cruza_la_capsula() -> void:  # AC-PLY-147
	var medida := await _medir("puerta2")
	assert_array(medida["abierta"]).contains_exactly([true, true])
	(
		assert_array(medida["desde"])
		. override_failure_message(
			"puerta2 cruza desde %s° y se adoptó %d°" % [medida["desde"], medida["adoptado"]]
		)
		. contains_exactly([medida["adoptado"], medida["adoptado"]])
	)


func test_el_angulo_de_paso_de_la_primera_cabina_es_el_que_cruza_la_capsula() -> void:  # AC-PLY-147
	var medida := await _medir("bano_puerta_1")
	assert_array(medida["abierta"]).contains_exactly([true, true])
	(
		assert_array(medida["desde"])
		. override_failure_message(
			"bano_puerta_1 cruza desde %s° y se adoptó %d°" % [medida["desde"], medida["adoptado"]]
		)
		. contains_exactly([medida["adoptado"], medida["adoptado"]])
	)


func test_el_angulo_de_paso_de_la_segunda_cabina_es_el_que_cruza_la_capsula() -> void:  # AC-PLY-147
	var medida := await _medir("bano_puerta_2")
	assert_array(medida["abierta"]).contains_exactly([true, true])
	(
		assert_array(medida["desde"])
		. override_failure_message(
			"bano_puerta_2 cruza desde %s° y se adoptó %d°" % [medida["desde"], medida["adoptado"]]
		)
		. contains_exactly([medida["adoptado"], medida["adoptado"]])
	)
