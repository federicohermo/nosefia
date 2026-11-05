## Las dos cajas que el proveedor deja junto al portón: cuándo están, qué se les puede hacer y
## qué dicen. Que la regla valga sólo en la jornada 7 lo prueba el dominio; acá, que el local la
## traduzca. Dónde queda cada una se mira jugando.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const CajaDeProductosDelDeposito := preload("res://src/escenas/objetos/caja_de_productos.gd")
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")

const CAJAS: Array[StringName] = [
	SubtitulosAlExaminar.CAJA_DEL_PROVEEDOR, SubtitulosAlExaminar.CAJA_DE_MADERA
]
## Lo que se deja caer encima: lo de un lado, para que quepa en cualquier hueco.
const LADO_DEL_OBJETO := 0.1
const CUADROS_DE_CAIDA := 90


func _ultima() -> int:
	return ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1


func _almacen(jornada: int) -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": jornada}))
	add_child(almacen)
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	return almacen


## Las cajas del proveedor que hay en el local, por su identidad.
func _cajas(almacen: Node3D) -> Dictionary[StringName, StaticBody3D]:
	var cajas: Dictionary[StringName, StaticBody3D] = {}
	for cuerpo: StaticBody3D in almacen.find_children("*", "StaticBody3D", true, false):
		if &"identidad" in cuerpo and cuerpo.get("identidad") in CAJAS:
			cajas[cuerpo.get("identidad")] = cuerpo
	return cajas


func _examinar(jugador: Node3D, objetivo: Node3D) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_EXAMINAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _linea(almacen: Node3D) -> Label:
	return almacen.get("_hud").get("_subtitulo")


func test_las_cajas_estan_en_la_ultima_jornada_y_no_en_las_anteriores() -> void:  # AC-SHF-100
	var almacen := await _almacen(ReglasDeLaPartida.PRIMERA_JORNADA)
	for jornada in range(ReglasDeLaPartida.PRIMERA_JORNADA, _ultima() + 1):
		almacen.call("_al_abrir_la_jornada", jornada)
		var identidades := _cajas(almacen).keys()
		if jornada == _ultima():
			assert_array(identidades).contains_exactly_in_any_order(CAJAS)
		else:
			assert_array(identidades).override_failure_message("jornada %d" % jornada).is_empty()


func test_una_partida_que_arranca_en_la_ultima_jornada_ya_las_tiene() -> void:  # AC-SHF-100
	var almacen := await _almacen(_ultima())
	assert_array(_cajas(almacen).keys()).contains_exactly_in_any_order(CAJAS)


func test_no_se_levantan_ni_se_empujan() -> void:  # AC-SHF-101
	var almacen := await _almacen(_ultima())
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	for identidad: StringName in _cajas(almacen):
		var caja := _cajas(almacen)[identidad]
		var lugar := caja.global_transform
		jugador.set("_enfocado", caja)
		jugador.call("_interactuar")
		assert_object(agarre.manos().sostenido()).override_failure_message(identidad).is_null()
		assert_bool(ReglasDeLosObjetos.PROPIEDAD_DATOS in caja).is_false()
		assert_bool(caja.has_method(ReglasDeLosObjetos.METODO_EMPUJAR)).is_false()
		await get_tree().physics_frame
		assert_bool(caja.global_transform.is_equal_approx(lugar)).is_true()


func test_lo_levantable_se_apoya_encima() -> void:  # AC-SHF-101
	var almacen := await _almacen(_ultima())
	for identidad: StringName in _cajas(almacen):
		var forma: CollisionShape3D = _cajas(almacen)[identidad].get_node("Forma")
		var limites := forma.global_transform * LimitesDeForma.de(forma.shape)
		var objeto := RigidBody3D.new()
		var cuerpo := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3.ONE * LADO_DEL_OBJETO
		cuerpo.shape = caja
		objeto.add_child(cuerpo)
		objeto.collision_mask = ReglasDeLosObjetos.MASCARA_DEL_PRODUCTO
		almacen.add_child(objeto)
		var centro := limites.get_center()
		objeto.global_position = Vector3(centro.x, limites.end.y + 0.3, centro.z)
		for _cuadro in CUADROS_DE_CAIDA:
			await get_tree().physics_frame
		assert_float(objeto.global_position.y).override_failure_message(identidad).is_greater(
			limites.end.y
		)
		assert_float(objeto.linear_velocity.length()).is_less(0.1)
		objeto.queue_free()


func test_ninguna_suena() -> void:  # AC-SHF-101
	var almacen := await _almacen(_ultima())
	for identidad: StringName in _cajas(almacen):
		var caja := _cajas(almacen)[identidad]
		assert_array(caja.find_children("*", "AudioStreamPlayer*", true, false)).is_empty()


func test_no_son_cajas_del_deposito() -> void:  # AC-SHF-101
	var almacen := await _almacen(_ultima())
	var de_productos: Array = almacen.get("_cajas_de_productos")
	assert_array(de_productos).is_not_empty()
	for caja: Node3D in _cajas(almacen).values():
		assert_bool(caja is CajaDeProductosDelDeposito).is_false()
		assert_bool(caja in de_productos).is_false()
	var cajas_del_cierre := 0
	for estado: ReglasDelCierre.Estado in almacen.call("_estados_del_cierre"):
		if estado.clase == ReglasDelCierre.Clase.CAJA:
			cajas_del_cierre += 1
	assert_int(cajas_del_cierre).is_equal(almacen.call("_todas_las_cajas").size())


func test_examinarlas_piensa_su_texto_con_las_manos_vacias() -> void:  # AC-SUB-050
	var almacen := await _almacen(_ultima())
	var jugador: Node3D = almacen.get("_jugador")
	for identidad: StringName in _cajas(almacen):
		_examinar(jugador, _cajas(almacen)[identidad])
		assert_str(_linea(almacen).text).override_failure_message(identidad).is_equal(
			SubtitulosAlExaminar.de_lo_fijo(identidad)
		)
		assert_str(_linea(almacen).text).is_not_empty()
		assert_float(_linea(almacen).modulate.a).is_equal(1.0)
		assert_bool(jugador.get("examen").esta_examinando()).is_false()
		assert_object((almacen.get("_agarre") as Agarre).manos().sostenido()).is_null()
	assert_int(jugador.get("examen").hallazgos().cantidad()).is_zero()
