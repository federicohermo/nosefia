## El ángulo de paso de cada hoja de paso es el menor al que la cápsula del jugador cruza el vano.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

## Las hojas interiores por las que el jugador pasa: el depósito, el baño y sus dos cabinas.
const HOJAS := ["puerta", "puerta2", "bano_puerta_1", "bano_puerta_2"]

## Cuántos cuadros se espera a que el motor registre la pose de la hoja.
const CUADROS_DE_ASENTAMIENTO := 3

## Cada cuántos metros se prueba la cápsula a lo largo del cruce.
const SEPARACION_DE_PUNTOS := 0.05

## Hasta dónde se prolonga el cruce a cada lado del vano: más que lo que la hoja entra en el cuarto.
const LARGO_DEL_CRUCE := 2.5

## A qué altura del piso se mide la pared que cierra el vano, y qué tan lejos se la busca.
const ALTURA_DE_LA_PARED := 1.0
const ALCANCE_DE_LA_PARED := 4.0

## El motor redondea las esquinas del casco convexo de la hoja, y la cápsula puede cruzar hasta
## un grado antes del ángulo adoptado. Nunca después: en el adoptado siempre cruza.
const GRADOS_DE_REDONDEO_DEL_MOTOR := 1

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


## Si la cápsula cruza el vano de lado a lado con la hoja en `angulo`. Va apoyada contra la pared
## lejana, con el aire que pide el paso, y no debe tocar la hoja en todo el cruce. Sólo cuenta la
## hoja: el piso y lo demás del local no se miden.
func _cruza(almacen: Node3D, nombre: String, angulo: float) -> bool:
	var cuerpo := _cuerpo_de(almacen, nombre)
	await _dejar_la_hoja_en(cuerpo, angulo)
	var geometria := _geometria(almacen, nombre)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var forma := _forma_del_jugador(jugador)
	var capsula := forma.shape as CapsuleShape3D
	var aire := CapsuleShape3D.new()
	aire.radius = capsula.radius + FrenoDeLaPuerta.MARGEN_DEL_PASO
	aire.height = capsula.height
	var pared := _distancia_a_la_pared(almacen, nombre, geometria)
	var cruce: Vector3 = geometria["bisagra"] + geometria["brazo"] * (pared - capsula.radius)
	var pasos := roundi(LARGO_DEL_CRUCE / SEPARACION_DE_PUNTOS)
	for paso in range(-pasos, pasos + 1):
		var donde: Vector3 = cruce + geometria["canto"] * paso * SEPARACION_DE_PUNTOS
		donde.y = geometria["piso"] + SEPARACION_DEL_PISO + forma.position.y
		if _toca_la_hoja(jugador, aire, donde, cuerpo):
			return false
	return true


## La cápsula con la que el jugador choca con el mundo: las otras formas no cuentan.
func _forma_del_jugador(jugador: CharacterBody3D) -> CollisionShape3D:
	for forma: CollisionShape3D in jugador.find_children("*", "CollisionShape3D", false, false):
		if not forma.disabled and forma.shape is CapsuleShape3D:
			return forma
	return null


func _toca_la_hoja(
	jugador: CharacterBody3D, forma: Shape3D, donde: Vector3, cuerpo: PhysicsBody3D
) -> bool:
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis.IDENTITY, donde)
	consulta.collision_mask = cuerpo.collision_layer
	consulta.exclude = [jugador.get_rid()]
	for golpe in jugador.get_world_3d().direct_space_state.intersect_shape(consulta, 32):
		if golpe["collider"] == cuerpo:
			return true
	return false


## Hasta dónde llega el vano desde la bisagra, medido hasta la pared que lo cierra.
func _distancia_a_la_pared(almacen: Node3D, nombre: String, geometria: Dictionary) -> float:
	var origen: Vector3 = geometria["bisagra"]
	origen.y = geometria["piso"] + ALTURA_DE_LA_PARED
	var consulta := PhysicsRayQueryParameters3D.create(
		origen, origen + geometria["brazo"] * ALCANCE_DE_LA_PARED
	)
	consulta.exclude = [
		_cuerpo_de(almacen, nombre).get_rid(),
		(almacen.get("_jugador") as CharacterBody3D).get_rid()
	]
	var espacio := _hoja_de(almacen, nombre).get_world_3d().direct_space_state
	var golpe := espacio.intersect_ray(consulta)
	return origen.distance_to(golpe["position"]) if not golpe.is_empty() else ALCANCE_DE_LA_PARED


## La hoja cerrada en el plano, medida desde su bisagra: el brazo hacia su centro, el canto que
## lo cruza y la altura del piso.
func _geometria(almacen: Node3D, nombre: String) -> Dictionary:
	var hoja := _hoja_de(almacen, nombre)
	var cuerpo := _cuerpo_de(almacen, nombre)
	var padre: Transform3D = hoja.global_transform * hoja.transform.affine_inverse()
	var cerrada: Transform3D = cuerpo.get("_cerrada")
	var bisagra: Vector3 = padre * cuerpo.get("_bisagra")
	var centro: Vector3 = padre * cerrada * hoja.get_aabb().get_center() - bisagra
	centro.y = 0.0
	var brazo := centro.normalized()
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	return {
		"bisagra": bisagra,
		"brazo": brazo,
		"canto": Vector3.UP.cross(brazo),
		"piso": suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0,
	}


## El menor número entero de grados al que cruza, buscado por bisección. Parte de que cruza con
## la hoja abierta del todo.
func _grados_de_paso(almacen: Node3D, nombre: String) -> int:
	var sin_paso := 0
	var con_paso := 90
	while con_paso - sin_paso > 1:
		var medio := (sin_paso + con_paso) / 2
		if await _cruza(almacen, nombre, deg_to_rad(medio)):
			con_paso = medio
		else:
			sin_paso = medio
	return con_paso


## Lo medido en una hoja: el ángulo adoptado, si cruza con la hoja abierta y desde qué grado cruza.
func _medir(nombre: String) -> Dictionary:
	var almacen: Node3D = await _almacen()
	var adoptado := roundi(rad_to_deg(_cuerpo_de(almacen, nombre).call("angulo_de_paso")))
	return {
		"adoptado": adoptado,
		"abierta": await _cruza(almacen, nombre, Puerta.ANGULO_ABIERTA),
		"desde": await _grados_de_paso(almacen, nombre),
	}


func _mensaje(nombre: String, medida: Dictionary) -> String:
	return "%s cruza desde %d° y se adoptó %d°" % [nombre, medida["desde"], medida["adoptado"]]


func test_el_angulo_de_paso_del_deposito_es_el_que_cruza_la_capsula() -> void:  # AC-PLY-147
	var medida := await _medir("puerta")
	assert_bool(medida["abierta"]).is_true()
	assert_int(medida["desde"]).override_failure_message(_mensaje("puerta", medida)).is_between(
		medida["adoptado"] - GRADOS_DE_REDONDEO_DEL_MOTOR, medida["adoptado"]
	)


func test_el_angulo_de_paso_de_la_segunda_hoja_es_el_que_cruza_la_capsula() -> void:  # AC-PLY-147
	var medida := await _medir("puerta2")
	assert_bool(medida["abierta"]).is_true()
	assert_int(medida["desde"]).override_failure_message(_mensaje("puerta2", medida)).is_between(
		medida["adoptado"] - GRADOS_DE_REDONDEO_DEL_MOTOR, medida["adoptado"]
	)


func test_el_angulo_de_paso_de_la_primera_cabina_es_el_que_cruza_la_capsula() -> void:  # AC-PLY-147
	var medida := await _medir("bano_puerta_1")
	assert_bool(medida["abierta"]).is_true()
	(
		assert_int(medida["desde"])
		. override_failure_message(_mensaje("bano_puerta_1", medida))
		. is_between(medida["adoptado"] - GRADOS_DE_REDONDEO_DEL_MOTOR, medida["adoptado"])
	)


func test_el_angulo_de_paso_de_la_segunda_cabina_es_el_que_cruza_la_capsula() -> void:  # AC-PLY-147
	var medida := await _medir("bano_puerta_2")
	assert_bool(medida["abierta"]).is_true()
	(
		assert_int(medida["desde"])
		. override_failure_message(_mensaje("bano_puerta_2", medida))
		. is_between(medida["adoptado"] - GRADOS_DE_REDONDEO_DEL_MOTOR, medida["adoptado"])
	)
