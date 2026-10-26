extends GdUnitTestSuite

const OBJETO := "res://src/escenas/objetos/objeto_agarrable.tscn"
const CIERRE := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const Habitaciones := preload("res://src/escenas/puestos/habitaciones_del_almacen.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
var _almacenes: Array[Node3D] = []


class PuestoSinImagen:
	extends "res://src/escenas/puestos/ventanilla.gd"

	# Sólo aísla la presentación que llega en437. Recepción, inventario y cuerpos son reales.
	func _mostrar_personaje(_atendida: Atencion) -> void:
		comprador_visible.hide()
		comprador_visible.stop()


func after_test() -> void:
	get_tree().paused = false
	for almacen in _almacenes:
		almacen.get_node("Servicios/AudioDelAlmacen/Reproductor").silenciar()
		almacen.queue_free()
	_almacenes.clear()
	for _cuadro in 4:
		await get_tree().process_frame


func _abrir() -> Node3D:
	var almacen: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
	var partida: GDScript = load("res://src/dominio/empleo/partida.gd")
	almacen.set("_partida", partida.call("desde", {"jornada": Compradores.JORNADA_DE_FEDE_Y_MIA}))
	var compradores := Compradores.segunda_jornada_definida()
	var textos := DialogosDeCompradores.new()
	textos.fede = PackedStringArray(["Inicial Fede fixture"])
	textos.mia = PackedStringArray(["Inicial Mía fixture"])
	textos.despedida_fede = PackedStringArray(["Despedida Fede fixture"])
	textos.despedida_mia = PackedStringArray(["Despedida Mía fixture"])
	for comprador in compradores:
		comprador.dialogos = textos
	almacen.set(
		"compradores_de_la_apertura", func(_jornada: int) -> Array[Comprador]: return compradores
	)
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	var exportados: Dictionary[String, Variant] = {}
	for nombre: String in [
		"jugador",
		"reloj",
		"atenciones",
		"panel",
		"borde_superior",
		"antepecho",
		"comprador_visible",
		"piso_de_entregas",
		"objetivo",
		"acceso_al_cobro"
	]:
		exportados[nombre] = puesto.get(nombre)
	puesto.set_script(PuestoSinImagen)
	for nombre in exportados:
		puesto.set(nombre, exportados[nombre])
	_almacenes.append(almacen)
	add_child(almacen)
	almacen.get("_reloj").set_process(false)
	almacen.get_node("Jugador").set_physics_process(false)
	for _cuadro in 4:
		await get_tree().physics_frame
	return almacen


func _pulsar(almacen: Node3D) -> void:
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	if puesto.get("_abierta"):
		var evento := InputEventAction.new()
		evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
		evento.pressed = true
		puesto.call("_input", evento)
	else:
		puesto.call("_al_pulsar")


func _presentar(almacen: Node3D, hora: Vector2i) -> Atencion:
	RelojDePrueba.avanzar_hasta(almacen.get("_reloj"), hora)
	_pulsar(almacen)
	_pulsar(almacen)
	return almacen.get("_atenciones").call("atencion")


func _ticket(almacen: Node3D, productos: Array[Producto]) -> Node3D:
	var papel: Node3D = load(OBJETO).instantiate()
	papel.set("datos", Ticket.new(productos))
	almacen.add_child(papel)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(papel.get("datos"), papel)).is_true()
	_pulsar(almacen)
	return papel


func _vender(
	almacen: Node3D, atendida: Atencion, ticket_primero: bool, desde_gondola: bool
) -> void:
	var manual: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	var estante: Estante = almacen.get("_repositor").call("estante")
	var inventario: Inventario = atendida.get("_inventario")
	assert_object(estante.get("_inventario")).is_same(inventario)
	var original := atendida.comprador().pedido()
	var productos := original.productos()
	if ticket_primero:
		_ticket(almacen, productos)
		assert_object(agarre.cuerpo_sostenido()).is_null()
	for producto in productos:
		var antes := inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)
		var ocupados := estante.casilleros_ocupados(producto)
		var indice := -1
		if desde_gondola:
			assert_array(ocupados).is_not_empty()
			indice = ocupados[0]
			manual.call("agarrar_de_la_gondola", producto.id, indice)
		else:
			manual.call("retirar", producto.id)
		var cuerpo := agarre.cuerpo_sostenido()
		assert_object(cuerpo).is_not_null()
		_pulsar(almacen)
		assert_object(agarre.cuerpo_sostenido()).is_null()
		assert_bool(cuerpo.visible).is_false()
		assert_object(atendida.comprador().pedido()).is_same(original)
		if desde_gondola:
			assert_array(estante.casilleros_vacios(producto)).contains(indice)
		if not atendida.vendida():
			assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(
				antes + (1 if desde_gondola else 0)
			)
	if not ticket_primero:
		_ticket(almacen, productos)
	assert_bool(atendida.vendida()).is_true()
	assert_bool(atendida.despachada()).is_false()
	_pulsar(almacen)
	assert_bool(atendida.despachada()).is_true()
	var esperado := ReglasDelEstante.UNIDADES_POR_CAJA - (0 if desde_gondola else 1)
	for producto in productos:
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(esperado)
	_pulsar(almacen)
	for producto in productos:
		assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(esperado)


# AC-CTR-055, AC-STK-083, AC-STK-084
func test_ambos_ordenes_con_recepcion_real_y_registro_de_ambas_compras() -> void:
	for ticket_primero: bool in [true, false]:
		var almacen := await _abrir()
		var atender: TareaDeAtender = almacen.get("_atenciones").call("tarea")
		var registro: RegistroDeVentas = almacen.get("_computadora").call("registro")
		var compras: Array[bool] = []
		almacen.get("_atenciones").compra_realizada.connect(func() -> void: compras.append(true))
		var fede := _presentar(almacen, Vector2i(21, 15))
		var duronga := Catalogo.de(Producto.Id.DURONGA)
		var manual: Node3D = almacen.get("_reposicion_manual")
		var inventario: Inventario = fede.get("_inventario")
		assert_int(inventario.casilleros(duronga)).is_equal(manual.call("casilleros")[duronga.id])
		assert_int(inventario.casilleros(duronga)).is_greater(0)
		_vender(almacen, fede, ticket_primero, true)
		for producto in fede.comprador().pedido().productos():
			registro.sumar(producto)
		assert_bool(registro.completada()).is_false()
		assert_bool(atender.completada()).is_false()
		var mia := _presentar(almacen, Vector2i(1, 0))
		assert_bool(registro.completada()).is_false()
		_vender(almacen, mia, ticket_primero, false)
		assert_bool(atender.completada()).is_true()
		assert_array(compras).has_size(2)
		for producto in mia.comprador().pedido().productos():
			registro.sumar(producto)
		assert_bool(registro.completada()).is_true()
		registro.restar(duronga)
		assert_bool(registro.completada()).is_false()
		registro.sumar(duronga)
		assert_bool(registro.completada()).is_true()
		await after_test()


func test_rechazo_conserva_cuerpo_y_pedido_en_la_mano() -> void:  # AC-CTR-055, AC-STK-084
	var almacen := await _abrir()
	var atendida := _presentar(almacen, Vector2i(21, 15))
	var pedido := atendida.comprador().pedido()
	var agarre: Agarre = almacen.get("_agarre")
	var papel := _ticket(almacen, [])
	assert_object(agarre.cuerpo_sostenido()).is_same(papel)
	assert_str(atendida.dialogo().entrada_actual()).starts_with(DialogosDeCompradores.RECHAZO)
	_pulsar(almacen)
	assert_object(agarre.cuerpo_sostenido()).is_same(papel)
	assert_object(atendida.comprador().pedido()).is_same(pedido)
	assert_bool(atendida.vendida()).is_false()


func test_registrar_espera_mia_y_cero_solo_cuenta_al_cierre() -> void:  # AC-STK-083
	var almacen := await _abrir()
	var atender: TareaDeAtender = almacen.get("_atenciones").call("tarea")
	var registro: RegistroDeVentas = almacen.get("_computadora").call("registro")
	assert_bool(registro.completada()).is_false()
	RelojDePrueba.avanzar_hasta(almacen.get("_reloj"), Vector2i(1, 0))
	assert_bool(registro.completada()).is_false()
	registro.sumar(Catalogo.de(Producto.Id.POETICO))
	assert_bool(registro.completada()).is_false()
	registro.restar(Catalogo.de(Producto.Id.POETICO))
	RelojDePrueba.avanzar_hasta(almacen.get("_reloj"), Vector2i(3, 30))
	assert_bool(atender.compras_cerradas()).is_true()
	assert_bool(atender.completada()).is_false()
	assert_bool(registro.completada()).is_false()
	assert_bool(registro.completada(true)).is_true()
	var registrar: Tarea = almacen.get("_reloj").call("obligatoria", Tarea.Tipo.REGISTRAR)
	assert_bool(registrar.completada()).is_false()
	RelojDePrueba.avanzar_turno(almacen.get("_reloj"), Reglas.DURACION_DEL_TURNO)
	assert_bool(registrar.completada()).is_true()


# AC-STK-083
func test_fede_vendido_y_mia_abierta_o_vencida_exigen_solo_sus_ventas_cerradas() -> void:
	var almacen := await _abrir()
	var fede := _presentar(almacen, Vector2i(21, 15))
	_vender(almacen, fede, false, false)
	var registro: RegistroDeVentas = almacen.get("_computadora").call("registro")
	for producto in fede.comprador().pedido().productos():
		registro.sumar(producto)
	assert_bool(registro.coincide()).is_true()
	assert_bool(registro.completada()).is_false()
	var tarea: TareaDeAtender = almacen.get("_atenciones").call("tarea")
	var futura: Comprador = tarea.get("_compradores")[1]
	for producto in futura.pedido().productos():
		registro.sumar(producto)
	assert_bool(registro.completada()).is_false()
	for producto in futura.pedido().productos():
		registro.restar(producto)
	var mia := _presentar(almacen, Vector2i(1, 0))
	assert_bool(registro.completada()).is_false()
	for producto in mia.comprador().pedido().productos():
		registro.sumar(producto)
	assert_bool(registro.completada()).is_false()
	RelojDePrueba.avanzar_hasta(almacen.get("_reloj"), Vector2i(3, 30))
	assert_bool(registro.completada(true)).is_false()
	for producto in mia.comprador().pedido().productos():
		registro.restar(producto)
	assert_bool(registro.completada(true)).is_true()
	assert_bool(registro.completada()).is_true()


func test_compra_a_032959_conserva_venta_y_despedida_al_vencer_el_limite() -> void:  # AC-CTR-062
	var almacen := await _abrir()
	var mia := _presentar(almacen, Vector2i(1, 0))
	RelojDePrueba.avanzar_hasta(almacen.get("_reloj"), Vector2i(3, 29))
	RelojDePrueba.avanzar_turno(almacen.get("_reloj"), 59.0)
	var agarre: Agarre = almacen.get("_agarre")
	var productos := mia.comprador().pedido().productos()
	for producto in productos:
		almacen.get("_reposicion_manual").call("retirar", producto.id)
		_pulsar(almacen)
	_ticket(almacen, productos)
	assert_bool(mia.vendida()).is_true()
	assert_bool(mia.despachada()).is_false()
	var despedida := mia.dialogo()
	RelojDePrueba.avanzar_turno(almacen.get("_reloj"), 1.0)
	assert_bool(mia.vendida()).is_true()
	assert_object(mia.dialogo()).is_same(despedida)
	assert_object(agarre.cuerpo_sostenido()).is_null()
	assert_bool(mia.despachada()).is_false()


func test_la_compra_parcial_vencida_conserva_unidades_reales_y_sus_destinos() -> void:  # AC-STK-082
	var almacen := await _abrir()
	var atendida := _presentar(almacen, Vector2i(21, 15))
	var inventario: Inventario = atendida.get("_inventario")
	var agarre: Agarre = almacen.get("_agarre")
	var manual: Node3D = almacen.get("_reposicion_manual")
	var estante: Estante = almacen.get("_repositor").call("estante")
	var ticket := _ticket(almacen, atendida.comprador().pedido().productos())
	var cuerpos: Array[Node3D] = []
	var unidades: Array[UnidadDeProducto] = []
	var cantidades: Array[int] = []
	for producto: Producto in atendida.comprador().pedido().productos().slice(0, 2):
		manual.call("retirar", producto.id)
		var cuerpo := agarre.cuerpo_sostenido()
		cuerpos.append(cuerpo)
		unidades.append(cuerpo.get("datos"))
		cantidades.append(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO))
		_pulsar(almacen)
		assert_bool(cuerpo.visible).is_false()
	RelojDePrueba.avanzar_hasta(almacen.get("_reloj"), Vector2i(23, 45))
	for _cuadro in 90:
		await get_tree().physics_frame
	assert_bool(is_instance_valid(ticket)).is_false()
	assert_array(manual.call("unidades_sueltas")).contains_exactly_in_any_order(cuerpos)
	var jornada: int = almacen.get("_partida").jornada()
	assert_bool(CIERRE.hay_desorden(almacen.call("_estados_del_cierre"), jornada)).is_true()
	RelojDePrueba.avanzar_turno(almacen.get("_reloj"), 0.0)
	assert_array(manual.call("unidades_sueltas")).contains_exactly_in_any_order(cuerpos)
	var suelo: StaticBody3D = manual.get("suelo")
	var habitaciones: Habitaciones = almacen.get("_habitaciones")
	for indice in cuerpos.size():
		var cuerpo := cuerpos[indice]
		assert_object(cuerpo.get("datos")).is_same(unidades[indice])
		assert_bool(cuerpo.visible).is_true()
		assert_int(habitaciones.de(cuerpo.global_position)).is_equal(CIERRE.Habitacion.LOCAL)
		assert_bool(cuerpo.has_meta(&"recibido_por_comprador")).is_false()
		assert_bool(inventario.esta_afuera(unidades[indice])).is_true()
		(
			assert_int(
				inventario.unidades(unidades[indice].producto, Inventario.Ubicacion.DEPOSITO)
			)
			. is_equal(cantidades[indice])
		)
		var forma: CollisionShape3D = cuerpo.get_node("Forma")
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.margin = 0.0
		consulta.collision_mask = cuerpo.collision_mask
		consulta.exclude = [cuerpo.get_rid(), suelo.get_rid()]
		assert_array(manual.get_world_3d().direct_space_state.intersect_shape(consulta)).is_empty()
	assert_bool(agarre.pedir_agarrar(unidades[0], cuerpos[0])).is_true()
	manual.call("devolver", unidades[0].producto.id)
	assert_bool(inventario.esta_afuera(unidades[0])).is_false()
	var producto := unidades[1].producto
	if estante.casilleros_vacios(producto).is_empty():
		manual.call("agarrar_de_la_gondola", producto.id, estante.casilleros_ocupados(producto)[0])
		manual.call("devolver", producto.id)
	assert_bool(agarre.pedir_agarrar(unidades[1], cuerpos[1])).is_true()
	manual.call("pedir_colocar", producto.id)
	assert_object(agarre.cuerpo_sostenido()).is_null()
	assert_bool(inventario.esta_afuera(unidades[1])).is_false()
	almacen.call("_al_abrir_la_jornada", Compradores.JORNADA_DE_FEDE_Y_MIA + 1)
	await get_tree().process_frame
	assert_array(manual.call("unidades_sueltas")).is_empty()
