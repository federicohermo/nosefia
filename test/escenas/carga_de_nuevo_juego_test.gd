extends GdUnitTestSuite

const RUTA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"


func _abrir_la_primera_jornada() -> Node3D:
	var almacen: Node3D = auto_free(load(RUTA_DEL_ALMACEN).instantiate())
	almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA}))
	add_child(almacen)
	await get_tree().process_frame
	return almacen


func test_las_cajas_y_las_muestras_entran_al_calentamiento_de_nuevo_juego() -> void:
	var almacen := await _abrir_la_primera_jornada()
	var sin_copias: Array[Node3D] = almacen.call("cuerpos_sin_copias")
	# El depósito está abierto desde la primera noche: lo que se compila después se compila en vivo.
	assert_array(sin_copias).is_not_empty()
	for caja: Node3D in almacen.get("_cajas_de_productos"):
		assert_bool(sin_copias.has(caja)).is_false()
	for muestra: Node3D in almacen.get("_reposicion_manual").unidades_de_muestra():
		assert_bool(sin_copias.has(muestra)).is_false()
