## El cableado de los gestos que piensan: cada aviso llega a la línea de subtítulo del HUD. Qué
## texto toca lo prueba el dominio; acá, que el almacén lo pase.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const S := SubtitulosDeLosGestos.Id
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")


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


## El comprador dice una entrega con el jugador a `metros` de su figura. Devuelve la dirección
## que lo aleja de ella, para medir el camino sobre la misma recta.
func _decir_entrega_a(almacen: Node3D, metros: float) -> Vector3:
	var figura: Node3D = almacen.get_node("Estructura/Ventanilla").comprador_visible
	var jugador: Node3D = almacen.get("_jugador")
	jugador.global_position = figura.global_position + Vector3.BACK * metros
	var alejando := (jugador.global_position - figura.global_position).normalized()
	almacen.get("_atenciones").entrega_dicha.emit("Gracias, me llevo la caja.")
	return alejando


func _alejar(almacen: Node3D, desde: Vector3, metros: float) -> void:
	var figura: Node3D = almacen.get_node("Estructura/Ventanilla").comprador_visible
	var jugador: Node3D = almacen.get("_jugador")
	jugador.global_position = figura.global_position + desde * metros
	almacen.call("_process", 0.0)


func test_irse_de_la_ventanilla_desvanece_la_entrega() -> void:  # AC-SUB-026
	var almacen := await _almacen()
	var hud: Hud = almacen.get("_hud")
	var subtitulo: Label = hud.get("_subtitulo")
	var alejando := _decir_entrega_a(almacen, 1.0)
	var figura: Node3D = almacen.get_node("Estructura/Ventanilla").comprador_visible
	var base := (almacen.get("_jugador") as Node3D).global_position.distance_to(
		figura.global_position
	)
	assert_float(base).is_equal_approx(1.0, 0.001)
	assert_float(hud.get("_comprador").modulate.a).is_equal(1.0)
	_alejar(almacen, alejando, base + 0.7)
	hud.call("_process", 0.25)
	assert_float(hud.get("_comprador").modulate.a).is_equal(1.0)
	_alejar(almacen, alejando, base + 0.8)
	hud.call("_process", 0.25)
	assert_float(hud.get("_comprador").modulate.a).is_between(0.01, 0.99)
	assert_bool(hud.get("_comprador").visible).is_true()
	_alejar(almacen, alejando, base)
	hud.call("_process", 0.0)
	assert_float(hud.get("_comprador").modulate.a).is_less(1.0)
	var opacidad: float = hud.get("_comprador").modulate.a
	hud.call("_process", 0.0)
	assert_float(hud.get("_comprador").modulate.a).is_less_equal(opacidad)
	hud.call("_process", 0.25)
	assert_bool(hud.get("_comprador").visible).is_false()
	assert_str(subtitulo.text).is_empty()


func test_la_entrega_dicha_desde_lejos_se_mide_desde_esa_distancia() -> void:  # AC-SUB-026
	var almacen := await _almacen()
	var hud: Hud = almacen.get("_hud")
	var alejando := _decir_entrega_a(almacen, 6.0)
	_alejar(almacen, alejando, 6.7)
	hud.call("_process", 0.25)
	assert_float(hud.get("_comprador").modulate.a).is_equal(1.0)
	_alejar(almacen, alejando, 6.8)
	hud.call("_process", 0.25)
	assert_float(hud.get("_comprador").modulate.a).is_less(1.0)


func test_la_entrega_conserva_su_lugar_si_el_comprador_se_va() -> void:  # AC-SUB-026
	var almacen := await _almacen()
	var hud: Hud = almacen.get("_hud")
	var figura: Node3D = almacen.get_node("Estructura/Ventanilla").comprador_visible
	var alejando := _decir_entrega_a(almacen, 1.0)
	var lugar := figura.global_position
	figura.global_position += Vector3.UP * 5.0
	(almacen.get("_jugador") as Node3D).global_position = lugar + alejando * 1.8
	almacen.call("_process", 0.0)
	hud.call("_process", 0.25)
	assert_float(hud.get("_comprador").modulate.a).is_less(1.0)


func test_el_aviso_reemplaza_la_entrega_sin_heredar_su_lugar() -> void:  # AC-SUB-026, AC-SUB-018
	var almacen := await _almacen()
	var hud: Hud = almacen.get("_hud")
	_decir_entrega_a(almacen, 1.0)
	almacen.call("_pensar_gesto", S.MOPA_YA_SECA)
	(almacen.get("_jugador") as Node3D).global_position += Vector3.RIGHT * 5.0
	almacen.call("_process", 0.0)
	hud.call("_process", 1.0)
	assert_float((hud.get("_subtitulo") as Label).modulate.a).is_equal(1.0)
	assert_str((hud.get("_subtitulo") as Label).text).is_not_empty()


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
	RelojDePrueba.avanzar_turno(almacen.get("_reloj"), Reglas.DURACION_DEL_TURNO)
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
