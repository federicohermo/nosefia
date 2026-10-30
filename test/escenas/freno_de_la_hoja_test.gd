## Lo pesado frena la hoja de una puerta, y lo liviano no.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

## La hoja que se mide: la del paso al fondo, que abre hacia el cuarto de atrás.
const HOJA := "Estructura/puerta"

## A qué distancia de la bisagra va lo que se pone en el recorrido.
const RADIO_EN_EL_RECORRIDO := 1.5

## Cuántos cuadros se deja girar la hoja como mucho, y cuántos para que un cuerpo se duerma.
const CUADROS_MAXIMOS := 600
const CUADROS_PARA_DORMIRSE := 120
const CUADROS_DETENIDA := 60

## Cuántos cuadros de más se toleran sobre el giro sin freno.
const CUADROS_DE_MARGEN := 2

const PRODUCTO := Producto.Id.MALBARDO
const PRODUCTO_DE_LA_CAJA := Producto.Id.CHISITOS

## Cuánto sobre el ángulo de paso va la caja. La hoja la toca antes de llegar a su centro, por el
## ancho de la caja y el de la hoja, y tiene que tocarla ya pasado el ángulo de paso. Y cuánto se
## separa del ángulo de paso la que la hoja atraviesa.
const CONTACTO_AL_ABRIR := deg_to_rad(30.0)
const CONTACTO_AL_CERRAR := deg_to_rad(5.0)
const BAJO_EL_PASO := deg_to_rad(25.0)

## Metros. Lo menos que se corre una caja a la que la hoja le deja lugar.
const CORRIDA_MINIMA := 0.02

## Metros. Lo que mide de grueso el muro contra el que se apoya una caja.
const ESPESOR_DEL_MURO := 0.2


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	# La primera noche traba esta puerta y estos casos miden la hoja, no la traba.
	almacen.get_node(HOJA + "/CuerpoDeLaHoja").set("traba", 0)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	return almacen


func _cuerpo_de(hoja: Node3D) -> PhysicsBody3D:
	for hijo in hoja.get_children():
		if hijo.has_method("puerta"):
			return hijo
	return null


## Dónde está la hoja cerrada, en el mundo, aunque ya haya girado.
func _cerrada(hoja: MeshInstance3D) -> Transform3D:
	var padre: Transform3D = hoja.global_transform * hoja.transform.affine_inverse()
	return padre * _cuerpo_de(hoja).get("_cerrada")


func _bisagra(hoja: MeshInstance3D) -> Vector3:
	var padre: Transform3D = hoja.global_transform * hoja.transform.affine_inverse()
	return padre * _cuerpo_de(hoja).get("_bisagra")


## Un punto del piso en el recorrido de la hoja, a `angulo` radianes de la hoja cerrada.
func _en_el_recorrido(almacen: Node3D, hoja: MeshInstance3D, angulo: float) -> Vector3:
	var bisagra := _bisagra(hoja)
	var brazo := (_cerrada(hoja).basis.x * Vector3(1.0, 0.0, 1.0)).normalized()
	var punto := bisagra + Basis(Vector3.UP, angulo) * brazo * RADIO_EN_EL_RECORRIDO
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	punto.y = suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0
	return punto


## Hacia dónde empuja la hoja en ese punto cuando abre.
func _sentido_del_giro(hoja: MeshInstance3D, punto: Vector3) -> Vector3:
	var radio := punto - _bisagra(hoja)
	radio.y = 0.0
	return Vector3.UP.cross(radio).normalized()


func _angulo_de(cuerpo: PhysicsBody3D) -> float:
	return cuerpo.call("puerta").angulo()


func _angulo_de_paso(cuerpo: PhysicsBody3D) -> float:
	return cuerpo.call("angulo_de_paso")


## Los cuadros que tarda en hacer el giro entero una hoja sin nada adelante.
func _cuadros_sin_freno() -> int:
	return ceili(
		Puerta.ANGULO_ABIERTA / (Puerta.VELOCIDAD_DEL_GIRO / Engine.physics_ticks_per_second)
	)


## Alterna la hoja y cuenta los cuadros hasta que llega a su tope.
func _cuadros_hasta_el_tope(cuerpo: PhysicsBody3D, tope: float) -> int:
	cuerpo.call("alternar")
	var cuadros := 0
	while not is_equal_approx(_angulo_de(cuerpo), tope) and cuadros < CUADROS_MAXIMOS:
		await get_tree().physics_frame
		cuadros += 1
	return cuadros


func _esperar(cuadros: int) -> void:
	for cuadro in cuadros:
		await get_tree().physics_frame


## Deja la hoja abierta del todo, sin nada que la moleste.
func _abrir(cuerpo: PhysicsBody3D) -> void:
	await _cuadros_hasta_el_tope(cuerpo, Puerta.ANGULO_ABIERTA)
	await _esperar(CUADROS_PARA_DORMIRSE)


## Una unidad de producto dormida, apoyada en el piso en `punto`.
func _unidad_dormida(almacen: Node3D, punto: Vector3) -> RigidBody3D:
	var agarre: Agarre = almacen.get("_agarre")
	almacen.get("_reposicion_manual").call("retirar", PRODUCTO)
	var unidad: RigidBody3D = agarre.soltar(true)
	unidad.global_basis = Basis.IDENTITY
	unidad.global_position = punto + Vector3.UP * 0.15
	unidad.linear_velocity = Vector3.ZERO
	await _esperar(CUADROS_PARA_DORMIRSE)
	return unidad


## La caja de la noche en `punto`: congelada en su apoyo, o despierta.
func _caja_en(almacen: Node3D, punto: Vector3, congelada: bool = true) -> RigidBody3D:
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[PRODUCTO_DE_LA_CAJA]
	caja.global_basis = Basis.IDENTITY
	caja.global_position = punto + Vector3.UP * (caja.media() + 0.01)
	caja.call("quedarse_quieta")
	if not congelada:
		caja.freeze = false
		caja.can_sleep = false
		caja.sleeping = false
	return caja


## Pone un muro del lado al que empuja la hoja, a `holgura` metros de la caja. `empuje` es un
## versor.
func _contra_un_muro(caja: RigidBody3D, empuje: Vector3, holgura: float = 0.0) -> void:
	var muro: StaticBody3D = auto_free(StaticBody3D.new())
	muro.collision_layer = caja.collision_mask
	var forma := CollisionShape3D.new()
	var volumen := BoxShape3D.new()
	volumen.size = Vector3(2.0, 3.0, ESPESOR_DEL_MURO)
	forma.shape = volumen
	muro.add_child(forma)
	add_child(muro)
	muro.global_transform = Transform3D(
		Basis.looking_at(empuje, Vector3.UP),
		(
			caja.global_position
			+ empuje * (_mitad_de_la_caja_hacia(caja, empuje) + holgura + ESPESOR_DEL_MURO / 2.0)
		)
	)
	await get_tree().physics_frame


## Cuánto se extiende la caja desde su centro hacia `direccion`.
func _mitad_de_la_caja_hacia(caja: RigidBody3D, direccion: Vector3) -> float:
	var forma: CollisionShape3D = caja.find_children("*", "CollisionShape3D", false, false)[0]
	var tamano := (forma.shape as BoxShape3D).size
	var base := forma.global_transform.basis
	return (
		(
			absf(direccion.dot(base.x)) * tamano.x
			+ absf(direccion.dot(base.y)) * tamano.y
			+ absf(direccion.dot(base.z)) * tamano.z
		)
		/ 2.0
	)


## Una caja contra un muro en el recorrido, a `angulo` de la hoja cerrada.
func _caja_inmovil(almacen: Node3D, angulo: float, abriendo: bool) -> RigidBody3D:
	var hoja: MeshInstance3D = almacen.get_node(HOJA)
	var caja := _caja_en(almacen, _en_el_recorrido(almacen, hoja, angulo))
	var empuje := _sentido_del_giro(hoja, caja.global_position) * (1.0 if abriendo else -1.0)
	await _contra_un_muro(caja, empuje)
	return caja


## Si el cuerpo se superpone con la hoja.
func _adentro_de_la_hoja(cuerpo: PhysicsBody3D, hoja: PhysicsBody3D) -> bool:
	var espacio := cuerpo.get_world_3d().direct_space_state
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.margin = -ReglasDeLosObjetos.ROCE
		for golpe in espacio.intersect_shape(consulta, 32):
			if golpe["collider"] == hoja:
				return true
	return false


func test_sin_nada_adelante_la_hoja_llega_al_tope_a_la_velocidad_de_siempre() -> void:  # AC-PLY-140
	var almacen: Node3D = await _almacen()
	var cuerpo := _cuerpo_de(almacen.get_node(HOJA))
	var al_abrir := await _cuadros_hasta_el_tope(cuerpo, Puerta.ANGULO_ABIERTA)
	assert_int(al_abrir).is_less_equal(_cuadros_sin_freno() + CUADROS_DE_MARGEN)
	var al_cerrar := await _cuadros_hasta_el_tope(cuerpo, 0.0)
	assert_int(al_cerrar).is_less_equal(_cuadros_sin_freno() + CUADROS_DE_MARGEN)


func test_una_unidad_de_producto_no_frena_la_hoja() -> void:  # AC-PLY-141
	var almacen: Node3D = await _almacen()
	var hoja: MeshInstance3D = almacen.get_node(HOJA)
	var cuerpo := _cuerpo_de(hoja)
	var punto := _en_el_recorrido(almacen, hoja, Puerta.ANGULO_ABIERTA / 2.0)
	var unidad := await _unidad_dormida(almacen, punto)
	var partida := unidad.global_position
	var al_abrir := await _cuadros_hasta_el_tope(cuerpo, Puerta.ANGULO_ABIERTA)
	assert_int(al_abrir).is_less_equal(_cuadros_sin_freno() + CUADROS_DE_MARGEN)
	await _esperar(CUADROS_PARA_DORMIRSE)
	assert_bool(_adentro_de_la_hoja(unidad, cuerpo)).is_false()
	var corrida := (unidad.global_position - partida).dot(_sentido_del_giro(hoja, partida))
	assert_float(corrida).is_greater(0.0)
	var al_cerrar := await _cuadros_hasta_el_tope(cuerpo, 0.0)
	assert_int(al_cerrar).is_less_equal(_cuadros_sin_freno() + CUADROS_DE_MARGEN)
	assert_bool(_adentro_de_la_hoja(unidad, cuerpo)).is_false()


func test_una_caja_que_se_puede_correr_frena_la_hoja_al_abrir() -> void:  # AC-PLY-142
	var barrido := await _barrido_con_una_caja_corrible(true, false)
	assert_int(barrido["cuadros"]).override_failure_message("la caja no frenó la hoja").is_greater(
		_cuadros_sin_freno() + CUADROS_DE_MARGEN
	)
	assert_int(barrido["cuadros"]).is_less(CUADROS_MAXIMOS)
	assert_float(barrido["corrida"]).override_failure_message("la caja no se corrió").is_greater(
		0.05
	)
	assert_bool(barrido["adentro"]).override_failure_message("la caja quedó adentro").is_false()


func test_una_caja_despierta_frena_igual_que_una_congelada() -> void:  # AC-PLY-142
	var barrido := await _barrido_con_una_caja_corrible(false, false)
	assert_int(barrido["cuadros"]).override_failure_message("la caja no frenó la hoja").is_greater(
		_cuadros_sin_freno() + CUADROS_DE_MARGEN
	)
	assert_int(barrido["cuadros"]).is_less(CUADROS_MAXIMOS)
	assert_float(barrido["corrida"]).override_failure_message("la caja no se corrió").is_greater(
		0.05
	)
	assert_bool(barrido["adentro"]).override_failure_message("la caja quedó adentro").is_false()


func test_una_caja_que_se_puede_correr_frena_la_hoja_al_cerrar() -> void:  # AC-PLY-142
	var barrido := await _barrido_con_una_caja_corrible(true, true)
	assert_int(barrido["cuadros"]).override_failure_message("la caja no frenó la hoja").is_greater(
		_cuadros_sin_freno() + CUADROS_DE_MARGEN
	)
	assert_int(barrido["cuadros"]).is_less(CUADROS_MAXIMOS)
	assert_float(barrido["corrida"]).override_failure_message("la caja no se corrió").is_greater(
		0.05
	)
	assert_bool(barrido["adentro"]).override_failure_message("la caja quedó adentro").is_false()
	(
		assert_int(barrido["rescates"])
		. override_failure_message("la red devolvió la caja %d veces" % barrido["rescates"])
		. is_equal(1)
	)


## Barre la hoja con una caja en el recorrido, a mitad del giro, y devuelve cuántos cuadros tardó
## la hoja en llegar a su tope, lo más que se corrió la caja en el sentido del giro y si quedó
## adentro de la hoja. Al cerrar, la caja queda apretada contra la pared y la red de seguridad la
## devuelve a su lugar: por eso se mide lo que se corrió y no dónde terminó.
func _barrido_con_una_caja_corrible(congelada: bool, cerrando: bool) -> Dictionary:
	var almacen: Node3D = await _almacen()
	var hoja: MeshInstance3D = almacen.get_node(HOJA)
	var cuerpo := _cuerpo_de(hoja)
	if cerrando:
		await _abrir(cuerpo)
	var punto := _en_el_recorrido(almacen, hoja, Puerta.ANGULO_ABIERTA / 2.0)
	var caja := _caja_en(almacen, punto, congelada)
	var partida := caja.global_position
	var sentido := _sentido_del_giro(hoja, partida) * (-1.0 if cerrando else 1.0)
	var tope := 0.0 if cerrando else Puerta.ANGULO_ABIERTA
	var corrida := 0.0
	var cuadros := 0
	cuerpo.call("alternar")
	while not is_equal_approx(_angulo_de(cuerpo), tope) and cuadros < CUADROS_MAXIMOS:
		await get_tree().physics_frame
		cuadros += 1
		corrida = maxf(corrida, (caja.global_position - partida).dot(sentido))
	await _esperar(CUADROS_PARA_DORMIRSE)
	return {
		"cuadros": cuadros,
		"corrida": corrida,
		"adentro": _adentro_de_la_hoja(caja, cuerpo),
		"rescates":
		(almacen.get_node("Servicios/RedDeSeguridad") as RedDeSeguridad).rescates.size(),
	}


## Lo que avanza a lo largo del arco, a `RADIO_EN_EL_RECORRIDO`, un cuadro de la hoja con `factor`.
func _avance_de_un_cuadro(factor: float) -> float:
	return (
		Puerta.VELOCIDAD_DEL_GIRO / Engine.physics_ticks_per_second * factor * RADIO_EN_EL_RECORRIDO
	)


## Una caja con lugar para el paso frenado pero no para el entero se corre: la hoja no se detiene
## con aire de por medio.
func test_una_caja_con_poco_lugar_se_corre_en_vez_de_detener_la_hoja() -> void:  # AC-PLY-142
	var almacen: Node3D = await _almacen()
	var hoja: MeshInstance3D = almacen.get_node(HOJA)
	var cuerpo := _cuerpo_de(hoja)
	var caja := _caja_en(
		almacen, _en_el_recorrido(almacen, hoja, _angulo_de_paso(cuerpo) + CONTACTO_AL_ABRIR)
	)
	var holgura := (
		(_avance_de_un_cuadro(1.0) + _avance_de_un_cuadro(FrenoDeLaPuerta.FACTOR_DE_LO_PESADO))
		/ 2.0
	)
	var empuje := _sentido_del_giro(hoja, caja.global_position)
	await _contra_un_muro(caja, empuje, holgura)
	var partida := caja.global_position
	cuerpo.call("alternar")
	await _esperar(CUADROS_DETENIDA * 2)
	(
		assert_float((caja.global_position - partida).dot(empuje))
		. override_failure_message("la hoja se detuvo con lugar para correr la caja")
		. is_greater(CORRIDA_MINIMA)
	)


func test_una_caja_inmovil_detiene_la_hoja_al_abrir_si_conserva_el_paso() -> void:  # AC-PLY-143
	var almacen: Node3D = await _almacen()
	var cuerpo := _cuerpo_de(almacen.get_node(HOJA))
	var paso := _angulo_de_paso(cuerpo)
	var caja := await _caja_inmovil(almacen, paso + CONTACTO_AL_ABRIR, true)
	var partida := caja.global_position
	var avisos := [0]
	cuerpo.connect("hoja_quieta", func(_hoja: PhysicsBody3D) -> void: avisos[0] += 1)
	cuerpo.call("alternar")
	await _esperar(CUADROS_DETENIDA * 2)
	assert_float(_angulo_de(cuerpo)).is_greater_equal(paso)
	assert_float(_angulo_de(cuerpo)).is_less(Puerta.ANGULO_ABIERTA)
	assert_bool(cuerpo.call("puerta").quieta()).is_true()
	assert_int(avisos[0]).override_failure_message("avisó %d veces" % avisos[0]).is_equal(1)
	assert_float(caja.global_position.distance_to(partida)).is_less(0.02)


func test_una_caja_inmovil_detiene_la_hoja_al_cerrar_si_conserva_el_paso() -> void:  # AC-PLY-143
	var almacen: Node3D = await _almacen()
	var cuerpo := _cuerpo_de(almacen.get_node(HOJA))
	await _abrir(cuerpo)
	var paso := _angulo_de_paso(cuerpo)
	var caja := await _caja_inmovil(almacen, paso + CONTACTO_AL_CERRAR, false)
	var partida := caja.global_position
	cuerpo.call("alternar")
	await _esperar(CUADROS_DETENIDA * 2)
	assert_float(_angulo_de(cuerpo)).is_greater_equal(paso)
	assert_float(_angulo_de(cuerpo)).is_greater(0.0)
	assert_bool(cuerpo.call("puerta").quieta()).is_true()
	assert_float(caja.global_position.distance_to(partida)).is_less(0.02)


func test_bajo_el_angulo_de_paso_la_hoja_atraviesa_la_caja_al_abrir() -> void:  # AC-PLY-143
	var almacen: Node3D = await _almacen()
	var cuerpo := _cuerpo_de(almacen.get_node(HOJA))
	var caja := await _caja_inmovil(almacen, _angulo_de_paso(cuerpo) - BAJO_EL_PASO, true)
	var cuadros := await _cuadros_hasta_el_tope(cuerpo, Puerta.ANGULO_ABIERTA)
	assert_int(cuadros).override_failure_message("la hoja quedó detenida").is_less(CUADROS_MAXIMOS)
	await _esperar(CUADROS_PARA_DORMIRSE)
	assert_bool(_adentro_de_la_hoja(caja, cuerpo)).is_false()


func test_bajo_el_angulo_de_paso_la_hoja_atraviesa_la_caja_al_cerrar() -> void:  # AC-PLY-143
	var almacen: Node3D = await _almacen()
	var cuerpo := _cuerpo_de(almacen.get_node(HOJA))
	await _abrir(cuerpo)
	var caja := await _caja_inmovil(almacen, _angulo_de_paso(cuerpo) - BAJO_EL_PASO, false)
	var cuadros := await _cuadros_hasta_el_tope(cuerpo, 0.0)
	assert_int(cuadros).override_failure_message("la hoja quedó detenida").is_less(CUADROS_MAXIMOS)
	await _esperar(CUADROS_PARA_DORMIRSE)
	assert_bool(_adentro_de_la_hoja(caja, cuerpo)).is_false()


func test_al_retirar_la_caja_la_hoja_reanuda_al_abrir() -> void:  # AC-PLY-144
	var almacen: Node3D = await _almacen()
	var cuerpo := _cuerpo_de(almacen.get_node(HOJA))
	var caja := await _caja_inmovil(almacen, _angulo_de_paso(cuerpo) + CONTACTO_AL_ABRIR, true)
	var retiro := await _retirar_la_caja(cuerpo, caja)
	assert_bool(is_equal_approx(retiro["detenida"]["angulo"], Puerta.ANGULO_ABIERTA)).is_false()
	assert_int(retiro["detenida"]["avisos"]).is_equal(1)
	assert_float(retiro["angulo"]).is_equal(Puerta.ANGULO_ABIERTA)
	assert_int(retiro["avisos"]).is_equal(2)


func test_al_retirar_la_caja_la_hoja_reanuda_al_cerrar() -> void:  # AC-PLY-144
	var almacen: Node3D = await _almacen()
	var cuerpo := _cuerpo_de(almacen.get_node(HOJA))
	await _abrir(cuerpo)
	var caja := await _caja_inmovil(almacen, _angulo_de_paso(cuerpo) + CONTACTO_AL_CERRAR, false)
	var retiro := await _retirar_la_caja(cuerpo, caja)
	assert_bool(is_equal_approx(retiro["detenida"]["angulo"], 0.0)).is_false()
	assert_int(retiro["detenida"]["avisos"]).is_equal(1)
	assert_float(retiro["angulo"]).is_equal(0.0)
	assert_int(retiro["avisos"]).is_equal(2)


## La hoja se detiene contra la caja; al sacarla sigue sola. Devuelve dónde quedó y cuántos
## avisos de quieta dio, contra la caja y al final.
func _retirar_la_caja(cuerpo: PhysicsBody3D, caja: RigidBody3D) -> Dictionary:
	var avisos := [0]
	cuerpo.connect("hoja_quieta", func(_hoja: PhysicsBody3D) -> void: avisos[0] += 1)
	cuerpo.call("alternar")
	await _esperar(CUADROS_DETENIDA)
	var detenida := {"angulo": _angulo_de(cuerpo), "avisos": avisos[0]}
	caja.freeze = true
	caja.global_position = Vector3(0.0, 100.0, 0.0)
	await _esperar(CUADROS_DETENIDA * 2)
	return {"detenida": detenida, "angulo": _angulo_de(cuerpo), "avisos": avisos[0]}
