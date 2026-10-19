## El cableado de los gestos que piensan: cada aviso llega a la línea de subtítulo del HUD. Qué
## texto toca lo prueba el dominio; acá, que el almacén lo pase.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const S := SubtitulosDeLosGestos.Id


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	add_child(almacen)
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func _linea(almacen: Node3D) -> String:
	return (almacen.get("_hud").get("_subtitulo") as Label).text


func test_tirar_una_unidad_al_contenedor_piensa_la_mala_idea() -> void:  # AC-SUB-016, AC-SUB-020
	var almacen := await _almacen()
	var agarre: Agarre = almacen.get("_agarre")
	var datos := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	var cuerpo: Node3D = auto_free(Node3D.new())
	assert_bool(agarre.pedir_agarrar(datos, cuerpo)).is_true()
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	recolector.pedir_tirar(true)
	assert_str(_linea(almacen)).is_equal(SubtitulosDeLosGestos.texto(S.MALA_IDEA))
	var jugador: Node3D = almacen.get("_jugador")
	var hud: Hud = almacen.get("_hud")
	jugador.global_position += Vector3.RIGHT * 5.0
	almacen.call("_process", 0.0)
	hud.call("_process", 1.0)
	assert_float((hud.get("_subtitulo") as Label).modulate.a).is_equal(1.0)


func test_la_mopa_seca_y_la_que_se_seca_piensan() -> void:  # AC-SUB-018, AC-SUB-019
	var almacen := await _almacen()
	var limpiador: Limpiador = almacen.get("_limpiador")
	var lugar: PisoDelLocal.Lugar = limpiador.piso().lugares()[0]
	limpiador.pasar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, lugar)
	assert_str(_linea(almacen)).is_equal(SubtitulosDeLosGestos.texto(S.MOPA_SIN_MOJAR))
	var partida: Partida = almacen.get("_partida")
	assert_bool(partida.mopa_secada()).is_false()
	limpiador.mopa_secada.emit()
	assert_str(_linea(almacen)).is_equal(SubtitulosDeLosGestos.texto(S.MOPA_BERRETA))
	assert_bool(partida.mopa_secada()).is_true()
	# Se seca caminando: alejarse no la apura.
	var jugador: Node3D = almacen.get("_jugador")
	var hud: Hud = almacen.get("_hud")
	jugador.global_position += Vector3.RIGHT * 5.0
	almacen.call("_process", 0.0)
	hud.call("_process", 1.0)
	assert_float((hud.get("_subtitulo") as Label).modulate.a).is_equal(1.0)


func test_alejarse_del_objeto_desvanece_su_subtitulo() -> void:  # AC-SUB-020
	var almacen := await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	var hud: Hud = almacen.get("_hud")
	var subtitulo: Label = hud.get("_subtitulo")
	var objeto: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ACTRONCITO]
	jugador.global_position = objeto.global_position + Vector3.BACK
	jugador.set("_enfocado", objeto)
	(
		assert_bool(jugador.examen.iniciar(objeto.datos, jugador.texto_al_examinar_de(objeto)))
		. is_false()
	)
	assert_str(subtitulo.text).is_not_empty()
	almacen.call("_process", 0.0)
	hud.call("_process", 0.25)
	assert_float(subtitulo.modulate.a).is_equal(1.0)
	jugador.global_position += Vector3.BACK * 2.0
	almacen.call("_process", 0.0)
	hud.call("_process", 0.25)
	assert_float(subtitulo.modulate.a).is_less(1.0)
	hud.call("_process", 0.25)
	assert_str(subtitulo.text).is_empty()


func test_la_mopa_ya_seca_no_acorta_el_aviso_al_caminar() -> void:  # AC-SUB-018, AC-SUB-020
	var almacen := await _almacen()
	var limpiador: Limpiador = almacen.get("_limpiador")
	var mopa := limpiador.piso().mopa()
	mopa.enjuagar()
	assert_bool(mopa.desgastar(100.0, 0.0)).is_true()
	var lugar: PisoDelLocal.Lugar = limpiador.piso().lugares()[0]
	assert_int(limpiador.pasar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, lugar)).is_equal(
		ReglasDeLaLimpieza.Resultado.MOPA_SECA
	)
	assert_str(_linea(almacen)).is_equal(SubtitulosDeLosGestos.texto(S.MOPA_YA_SECA))
	var jugador: Node3D = almacen.get("_jugador")
	var hud: Hud = almacen.get("_hud")
	jugador.global_position += Vector3.RIGHT * 5.0
	almacen.call("_process", 0.0)
	hud.call("_process", 1.0)
	assert_float((hud.get("_subtitulo") as Label).modulate.a).is_equal(1.0)


func _examen_con_aviso_esperando() -> Node3D:
	var almacen := await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ACTRONCITO]
	var afuera: RigidBody3D = almacen.get("_cajas_de_productos")[Producto.Id.MARRANOS]
	afuera.global_position = Vector3.ONE * 100.0
	afuera.freeze = true
	assert_int(almacen.get("_habitaciones").de(afuera.global_position)).is_equal(
		ReglasDelCierre.Habitacion.AFUERA
	)
	almacen.call("_vigilar_si_queda_afuera", afuera)
	jugador.set("_enfocado", caja)
	var usar := InputEventAction.new()
	usar.action = ReglasDelJugador.ACCION_USAR
	usar.pressed = true
	jugador.call("_unhandled_input", usar)
	var examinar := InputEventAction.new()
	examinar.action = ReglasDeLosObjetos.ACCION_EXAMINAR
	examinar.pressed = true
	jugador.call("_unhandled_input", examinar)
	assert_bool(jugador.get("examen").esta_examinando()).is_true()
	assert_str(_linea(almacen)).is_equal(SubtitulosAlExaminar.de_producto(Producto.Id.ACTRONCITO))
	return almacen


func test_lo_caido_afuera_espera_al_examen_sin_reemplazarlo() -> void:  # AC-SUB-007, AC-SUB-017
	var almacen := await _examen_con_aviso_esperando()
	var jugador: Node3D = almacen.get("_jugador")
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_str(_linea(almacen)).is_equal(SubtitulosAlExaminar.de_producto(Producto.Id.ACTRONCITO))
	jugador.get("examen").terminar()
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_str(_linea(almacen)).is_equal(SubtitulosDeLosGestos.texto(S.POR_LA_VENTANA))


func test_el_cierre_descarta_el_aviso_que_esperaba_al_examen() -> void:  # AC-SUB-009
	var almacen := await _examen_con_aviso_esperando()
	await get_tree().physics_frame
	await get_tree().process_frame
	almacen.get("_reloj").avanzar(10000.0)
	assert_bool(almacen.get("_reloj").corriendo()).is_false()
	almacen.get("_jugador").get("examen").terminar()
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_str(_linea(almacen)).is_empty()


func test_el_aviso_espera_tambien_a_que_termine_la_pausa() -> void:  # AC-SUB-007
	var almacen := await _examen_con_aviso_esperando()
	await get_tree().physics_frame
	get_tree().paused = true
	almacen.get("_jugador").get("examen").terminar()
	await get_tree().physics_frame
	await get_tree().process_frame
	var linea_pausada := _linea(almacen)
	get_tree().paused = false
	assert_str(linea_pausada).is_empty()
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_str(_linea(almacen)).is_equal(SubtitulosDeLosGestos.texto(S.POR_LA_VENTANA))
