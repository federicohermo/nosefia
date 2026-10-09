extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

var _almacen: Node3D
var _camara: Camera3D


func after_test() -> void:
	get_tree().paused = false
	_almacen.get_node("Servicios/AudioDelAlmacen/Reproductor").silenciar()
	_almacen.queue_free()
	_camara.queue_free()
	for _cuadro in 4:
		await get_tree().process_frame


func _abrir(recibir: bool = true) -> Node3D:
	_almacen = ALMACEN.instantiate()
	_almacen.set("_partida", Partida.nueva())
	add_child(_almacen)
	_almacen.get_node("Jugador").set_physics_process(false)
	_almacen.get("_reloj").set_process(false)
	var puesto: Node3D = _almacen.get_node("Estructura/Ventanilla")
	_camara = Camera3D.new()
	add_child(_camara)
	_camara.global_position = puesto.global_position + Vector3(0.0, 0.7, -2.0)
	_camara.look_at(puesto.get_node("Comprador").global_position)
	_camara.make_current()
	if recibir:
		_almacen.get("_reloj").avanzar(120.0)
		assert_array(_visibles(puesto)).has_size(1)
	return puesto


func _visibles(puesto: Node3D) -> Array[AnimatedSprite3D]:
	var visibles: Array[AnimatedSprite3D] = []
	for nodo: Node in puesto.get_children():
		if nodo is AnimatedSprite3D and nodo.visible:
			visibles.append(nodo)
	return visibles


func _vender(puesto: Node3D) -> Atencion:
	var posicion: Transform3D = puesto.get_node("Comprador").global_transform
	var atenciones: Ventanilla = _almacen.get("_atenciones")
	var atendida := atenciones.atencion()
	puesto.call("_al_pulsar")
	while not atenciones.puede_abandonar():
		puesto.call("_al_pulsar")
	var pedido := atendida.comprador().pedido()
	var productos: Array[Producto] = []
	for producto in pedido.productos():
		for _unidad in pedido.unidades_de(producto):
			_almacen.get("_reposicion_manual").retirar(producto.id)
			puesto.call("_al_pulsar")
			productos.append(producto)
	var caja: CajaRegistradora = _almacen.get("_caja")
	for producto in productos:
		caja.pedir_anotar(UnidadDeProducto.new(producto))
	caja.pedir_imprimir()
	var papeles: Array[Node3D] = _almacen.get("_puesto_de_la_caja").tickets_en_el_mundo()
	var ticket := papeles.back() as ObjetoAgarrable
	assert_bool((_almacen.get("_agarre") as Agarre).pedir_agarrar(ticket.datos, ticket)).is_true()
	puesto.call("_al_pulsar")
	assert_bool(atendida.vendida()).is_true()
	assert_bool(atendida.despachada()).is_false()
	assert_that(puesto.get_node("Comprador").global_transform).is_equal(posicion)
	while not atenciones.puede_abandonar():
		puesto.call("_al_pulsar")
	assert_bool(atendida.despachada()).is_true()
	return atendida


# AC-CTR-043
func test_la_venta_sale_animada_a_la_derecha_tras_la_despedida_y_no_reaparece() -> void:
	var puesto := _abrir()
	var atendida := _vender(puesto)
	assert_array(_visibles(puesto)).has_size(1)
	if _visibles(puesto).is_empty():
		return
	var sprite := _visibles(puesto)[0]
	var posicion := sprite.global_transform
	sprite.call("_process", 0.1)
	assert_float((sprite.global_position - posicion.origin).dot(_camara.global_basis.x)).is_greater(
		0.0
	)
	assert_float(sprite.global_position.y).is_equal(posicion.origin.y)
	assert_float(sprite.global_position.z).is_equal(posicion.origin.z)
	assert_that(sprite.global_basis).is_equal(posicion.basis)
	assert_bool(sprite.visible).is_true()
	if not sprite.visible:
		return
	sprite.set_frame_and_progress(0, 0.99)
	await get_tree().create_timer(0.1).timeout
	assert_int(sprite.frame).is_not_equal(0)
	get_tree().paused = true
	var detenido := sprite.global_transform
	var cuadro := sprite.frame
	await get_tree().create_timer(0.1, true).timeout
	assert_that(sprite.global_transform).is_equal(detenido)
	assert_int(sprite.frame).is_equal(cuadro)
	get_tree().paused = false
	puesto.call("cerrar")
	assert_bool(sprite.visible).is_true()
	puesto.call("_al_pulsar")
	assert_bool(atendida.vendida()).is_true()
	assert_object((_almacen.get("_atenciones") as Ventanilla).tarea().en_ventanilla()).is_null()
	sprite.call("_process", 10.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(_visibles(puesto)).is_empty()
	_almacen.get("_atenciones").presentacion_cambiada.emit()
	await get_tree().process_frame
	assert_array(_visibles(puesto)).is_empty()


func test_el_cansancio_desliza_a_la_derecha_y_la_pausa_lo_detiene() -> void:  # AC-CTR-044
	var puesto := _abrir()
	var original: AnimatedSprite3D = puesto.get_node("Comprador")
	var posicion := original.global_position
	var orientacion := original.global_basis
	_almacen.get("_reloj").avanzar(120.0)
	assert_array(_visibles(puesto)).has_size(1)
	if _visibles(puesto).is_empty():
		return
	var sprite := _visibles(puesto)[0]
	sprite.call("_process", 0.1)
	var desplazamiento := sprite.global_position - posicion
	assert_float(desplazamiento.dot(_camara.global_basis.x)).is_greater(0.0)
	assert_float(sprite.global_position.y).is_equal(posicion.y)
	assert_float(sprite.global_position.z).is_equal(posicion.z)
	assert_that(sprite.global_basis).is_equal(orientacion)
	get_tree().paused = true
	var detenido := sprite.global_transform
	var cuadro := sprite.frame
	await get_tree().create_timer(0.1, true).timeout
	assert_that(sprite.global_transform).is_equal(detenido)
	assert_int(sprite.frame).is_equal(cuadro)
	get_tree().paused = false
	sprite.call("_process", 10.0)
	await get_tree().process_frame
	assert_array(_visibles(puesto)).is_empty()
	(
		assert_int(
			(_almacen.get("_atenciones") as Ventanilla).tarea().vendidas_de(
				Catalogo.de(Producto.Id.MAROLINI)
			)
		)
		. is_zero()
	)


func test_reiniciar_retira_las_imagenes_de_ventas_y_de_cansancio() -> void:  # AC-CTR-044
	var puesto := _abrir()
	_vender(puesto)
	assert_array(_visibles(puesto)).has_size(1)
	_almacen.call("_al_abrir_la_jornada", 1)
	assert_array(_visibles(puesto)).is_empty()

	var obligatorias: Array[Tarea] = (_almacen.get("_partida") as Partida).obligatorias()
	(_almacen.get("_reloj") as RelojDelTurno).arrancar(
		Apertura.turno_de_la_jornada(obligatorias), obligatorias
	)
	_almacen.get("_reloj").avanzar(120.0)
	_almacen.get("_reloj").avanzar(120.0)
	assert_array(_visibles(puesto)).has_size(1)
	(_almacen.get("_reloj") as RelojDelTurno).turno_cerrado.emit(0)
	assert_array(_visibles(puesto)).is_empty()


func test_ambos_entran_por_la_izquierda_y_la_pausa_conserva_su_entrada() -> void:  # AC-CTR-045
	var puesto := _abrir(false)
	var sprite: AnimatedSprite3D = puesto.get_node("Comprador")
	var espera := sprite.global_transform
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	for intervalo: float in [120.0, 240.0]:
		reloj.avanzar(intervalo)
		assert_bool(sprite.visible).is_true()
		var comienzo := sprite.global_position
		assert_float((comienzo - espera.origin).dot(_camara.global_basis.x)).is_less(0.0)
		await get_tree().create_timer(0.1).timeout
		assert_float((sprite.global_position - comienzo).dot(_camara.global_basis.x)).is_greater(
			0.0
		)
		assert_float(sprite.global_position.y).is_equal(espera.origin.y)
		assert_float(sprite.global_position.z).is_equal_approx(espera.origin.z, 0.00001)
		assert_that(sprite.global_basis).is_equal(espera.basis)
		var antes := sprite.global_transform
		puesto.call("abrir")
		puesto.call("cerrar")
		_almacen.get("_atenciones").presentacion_cambiada.emit()
		assert_that(sprite.global_transform).is_equal(antes)
		get_tree().paused = true
		var cuadro := sprite.frame
		await get_tree().create_timer(0.1, true).timeout
		assert_that(sprite.global_transform).is_equal(antes)
		assert_int(sprite.frame).is_equal(cuadro)
		get_tree().paused = false
		await get_tree().create_timer(1.5).timeout
		assert_bool(sprite.global_position.is_equal_approx(espera.origin)).is_true()
		reloj.avanzar(120.0)
	for cerrar_turno: bool in [false, true]:
		assert_bool((_almacen.get("_ciclo") as CicloDeJornadas).abrir_la_jornada()).is_true()
		reloj.avanzar(120.0)
		assert_bool(sprite.visible).is_true()
		if cerrar_turno:
			reloj.turno_cerrado.emit(0)
		else:
			_almacen.call("_al_abrir_la_jornada", 1)
		await get_tree().create_timer(0.1).timeout
		assert_array(_visibles(puesto)).is_empty()
		assert_bool(sprite.global_position.is_equal_approx(espera.origin)).is_true()
