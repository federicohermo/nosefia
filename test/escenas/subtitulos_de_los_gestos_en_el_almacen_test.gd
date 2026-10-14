## El cableado de los gestos que piensan: cada aviso llega a la línea de subtítulo del HUD. Qué
## texto toca lo prueba el dominio; acá, que el almacén lo pase.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func _linea(almacen: Node3D) -> String:
	return (almacen.get("_hud").get("_subtitulo") as Label).text


func test_tirar_una_unidad_al_contenedor_piensa_la_mala_idea() -> void:  # AC-SUB-016
	var almacen := await _almacen()
	var agarre: Agarre = almacen.get("_agarre")
	var datos := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	var cuerpo: Node3D = auto_free(Node3D.new())
	assert_bool(agarre.pedir_agarrar(datos, cuerpo)).is_true()
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	recolector.pedir_tirar(true)
	assert_str(_linea(almacen)).is_equal(SubtitulosDeLosGestos.MALA_IDEA)


func test_la_mopa_seca_y_la_que_se_seca_piensan() -> void:  # AC-SUB-018, AC-SUB-019
	var almacen := await _almacen()
	var limpiador: Limpiador = almacen.get("_limpiador")
	var lugar: PisoDelLocal.Lugar = limpiador.piso().lugares()[0]
	limpiador.pasar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, lugar)
	assert_str(_linea(almacen)).is_equal(SubtitulosDeLosGestos.MOPA_SIN_MOJAR)
	var partida: Partida = almacen.get("_partida")
	assert_bool(partida.mopa_secada()).is_false()
	limpiador.mopa_secada.emit()
	assert_str(_linea(almacen)).is_equal(SubtitulosDeLosGestos.MOPA_BERRETA)
	assert_bool(partida.mopa_secada()).is_true()
	# Se seca caminando: alejarse no la apura.
	var jugador: Node3D = almacen.get("_jugador")
	var hud: Hud = almacen.get("_hud")
	jugador.global_position += Vector3.RIGHT * 5.0
	almacen.call("_process", 0.0)
	hud.call("_process", 1.0)
	assert_float((hud.get("_subtitulo") as Label).modulate.a).is_equal(1.0)


func test_alejarse_del_pensamiento_lo_desvanece_antes() -> void:  # AC-SUB-020
	var almacen := await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	var hud: Hud = almacen.get("_hud")
	var subtitulo: Label = hud.get("_subtitulo")
	almacen.call("_pensar", SubtitulosDeLosGestos.MALA_IDEA)
	almacen.call("_process", 0.0)
	hud.call("_process", 0.25)
	assert_float(subtitulo.modulate.a).is_equal(1.0)
	jugador.global_position += Vector3.RIGHT * 2.0
	almacen.call("_process", 0.0)
	hud.call("_process", 0.25)
	assert_float(subtitulo.modulate.a).is_less(1.0)
	hud.call("_process", 0.25)
	assert_str(subtitulo.text).is_empty()
