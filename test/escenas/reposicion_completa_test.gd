extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_reponer_todos_los_huecos_de_la_apertura_cumple_la_tarea() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var repositor: Repositor = almacen.get("_repositor")
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.set_process(false)
	var tarea := reloj.obligatoria(Tarea.Tipo.REPONER)
	assert_object(tarea).is_not_null()
	assert_bool(tarea.completada()).is_false()
	var colocadas := 0
	for producto in Catalogo.todos():
		var vacios := repositor.estante().casilleros_vacios(producto)
		for indice in vacios:
			var casillero: Node3D = puesto.call("casillero", producto.id, indice)
			puesto.call("retirar", producto.id)
			assert_object(repositor.agarre.manos().sostenido() as UnidadDeProducto).is_not_null()
			assert_int(casillero.get("papel")).is_equal(1)
			puesto.call("pedir_colocar", producto.id, indice)
			assert_object(repositor.agarre.manos().sostenido()).is_null()
			colocadas += 1
	assert_int(colocadas).is_greater(0)
	assert_bool(repositor.estante().completada()).is_true()
	assert_bool(tarea.completada()).is_true()


func test_despues_de_cada_bolsa_se_puede_agarrar_y_reponer_actroncito() -> void:
	var almacen := _abrir()
	var agarre: Agarre = almacen.get("_agarre")
	var jugador: Node3D = almacen.get("_jugador")
	var contenedor: Node3D = almacen.get("_contenedor")
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	var depositadas := 0
	for bolsa: ObjetoAgarrable in almacen.get("_bolsas"):
		assert_bool(agarre.pedir_agarrar(bolsa.datos, bolsa)).is_true()
		jugador.set("_enfocado", contenedor)
		_clic()
		depositadas += 1
		assert_int(recolector.tarea().depositadas()).is_equal(depositadas)
		assert_object(agarre.manos().sostenido()).is_null()
		await _agarrar_y_reponer_con_clic(almacen)
	assert_bool(recolector.tarea().completada()).is_true()


func test_tirar_un_producto_tambien_permite_volver_a_agarrar_de_la_gondola() -> void:
	var almacen := _abrir()
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	puesto.call("retirar", Producto.Id.DUREXTRA)
	assert_object(agarre.manos().sostenido()).is_instanceof(UnidadDeProducto)
	almacen.get("_jugador").set("_enfocado", almacen.get("_contenedor"))
	_clic()
	assert_object(agarre.manos().sostenido()).is_null()
	await _agarrar_y_reponer_con_clic(almacen)


func _abrir() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	almacen.get("_reloj").set_process(false)
	return almacen


func _agarrar_y_reponer_con_clic(almacen: Node3D) -> void:
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var estante: Estante = almacen.get("_repositor").estante()
	var ocupados := estante.casilleros_ocupados(producto)
	assert_array(ocupados).is_not_empty()
	var indice: int = ocupados.back()
	var zona: Node3D = puesto.call("casillero", producto.id, indice)
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var frente := DisposicionDeLaGondola.frente(
		disposicion.principales[producto.id], disposicion.filas_de_adelante[producto.id]
	)
	jugador.global_position = zona.global_position + frente * 0.9
	jugador.global_position.y = 0.0
	jugador.get_node("Giro/Camara").look_at(zona.global_position)
	for cuadro: int in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
	assert_object(jugador.get("_enfocado")).is_same(zona)
	_clic()
	var unidad := agarre.manos().sostenido() as UnidadDeProducto
	assert_object(unidad).is_not_null()
	if unidad == null:
		return
	assert_int(unidad.producto.id).is_equal(producto.id)
	assert_array(estante.casilleros_ocupados(producto)).not_contains([indice])
	for cuadro: int in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
	_clic()
	assert_object(agarre.manos().sostenido()).is_null()
	assert_array(estante.casilleros_ocupados(producto)).contains([indice])


func _clic() -> void:
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	get_viewport().push_input(evento)
	evento = evento.duplicate()
	evento.pressed = false
	get_viewport().push_input(evento)
