extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Puesto := preload("res://src/escenas/puestos/ventanilla.gd")

var _almacenes: Array[Node3D] = []


func after_test() -> void:
	get_tree().paused = false
	for almacen in _almacenes:
		almacen.get_node("Servicios/AudioDelAlmacen/Reproductor").silenciar()
		almacen.queue_free()
	_almacenes.clear()
	for _cuadro in 4:
		await get_tree().process_frame


func _abrir() -> Node3D:
	var almacen: Node3D = ALMACEN.instantiate()
	almacen.set("_partida", Partida.nueva())
	_almacenes.append(almacen)
	add_child(almacen)
	almacen.get_node("Jugador").set_physics_process(false)
	almacen.get_node("Servicios/RelojDelTurno").set_process(false)
	for _cuadro in 3:
		await get_tree().physics_frame
	return almacen


func _panel(almacen: Node3D) -> PanelDeLaVentanilla:
	return (almacen.get_node("Estructura/Ventanilla") as Puesto).panel


func _pulsar(almacen: Node3D) -> void:
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	_panel(almacen).get_node("Fisico/Blanco").gui_input.emit(clic)


func _conversar(almacen: Node3D) -> void:
	var atenciones: Ventanilla = almacen.get("_atenciones")
	_pulsar(almacen)
	for _entrada in 8:
		if atenciones.puede_abandonar():
			break
		_pulsar(almacen)
	assert_bool(atenciones.puede_abandonar()).is_true()


func _ticket(almacen: Node3D, pedido: Venta) -> ObjetoAgarrable:
	var caja: CajaRegistradora = almacen.get("_caja")
	caja.pedir_borrar()
	for producto in pedido.productos():
		for _unidad in pedido.unidades_de(producto):
			caja.pedir_anotar(UnidadDeProducto.new(producto))
	caja.pedir_imprimir()
	var destino: Node3D = almacen.get("_puesto_de_la_caja").get("destino_de_los_tickets")
	for nodo in destino.get_children():
		var papel := nodo as ObjetoAgarrable
		if papel != null and papel.datos is Ticket and papel.visible:
			return papel
	(
		assert_bool(false)
		. override_failure_message("La impresora no produjo un ticket fisico")
		. is_true()
	)
	return null


# AC-CTR-039, AC-CTR-041, AC-STK-054
func test_las_dos_compras_fisicas_registran_una_vez_y_se_van_tras_despedirse() -> void:
	var almacen := await _abrir()
	var puesto: Puesto = almacen.get_node("Estructura/Ventanilla")
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var atenciones: Ventanilla = almacen.get("_atenciones")
	var agarre: Agarre = almacen.get("_agarre")
	var compras: Array[bool] = []
	atenciones.compra_realizada.connect(func() -> void: compras.append(true))
	puesto.abrir()
	assert_object(atenciones.atencion()).is_null()
	puesto.cerrar()
	for intervalo: float in [120.0, 360.0]:
		reloj.avanzar(intervalo)
		assert_bool(_panel(almacen).visible).is_false()
		puesto.abrir()
		var atendida := atenciones.atencion()
		assert_object(atendida).is_not_null()
		var sprite := puesto.get_node("Comprador") as AnimatedSprite3D
		assert_bool(sprite.is_visible_in_tree()).is_true()
		var avisos: PilaDeNotificaciones = almacen.get_node("Interfaz/PilaDeNotificaciones")
		avisos._process(20.0)
		assert_array((avisos.get("_estado") as Notificaciones).visibles()).contains(
			Notificaciones.Tipo.CLIENTE
		)
		_conversar(almacen)
		assert_array((avisos.get("_estado") as Notificaciones).visibles()).not_contains(
			Notificaciones.Tipo.CLIENTE
		)
		puesto.cerrar()
		puesto.abrir()
		assert_object(atenciones.atencion()).is_same(atendida)
		var pedido := atendida.comprador().pedido()
		for producto in pedido.productos():
			for _unidad in pedido.unidades_de(producto):
				almacen.get("_reposicion_manual").retirar(producto.id)
				var cuerpo := agarre.cuerpo_sostenido()
				var identidad := agarre.manos().sostenido()
				assert_object(cuerpo).is_not_null()
				_pulsar(almacen)
				assert_object(agarre.manos().sostenido()).is_null()
				assert_object(cuerpo.get("datos")).is_same(identidad)
				assert_bool(cuerpo.visible).is_false()
				assert_bool(atendida.vendida()).is_false()
		assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_false()
		var papel := _ticket(almacen, pedido)
		assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
		_pulsar(almacen)
		assert_object(agarre.manos().sostenido()).is_null()
		assert_bool(atendida.vendida()).is_true()
		assert_bool(atendida.despachada()).is_false()
		var despedida := atendida.dialogo()
		var textos: Array[String] = []
		for _entrada in 4:
			if atenciones.puede_abandonar():
				break
			var texto: RichTextLabel = _panel(almacen).get_node("Fisico/Dialogo/Texto")
			assert_bool(texto.is_visible_in_tree()).is_true()
			assert_str(texto.text).is_equal(despedida.entrada_actual())
			textos.append(texto.text)
			_pulsar(almacen)
		if atendida.comprador().personaje == DialogosDeCompradores.Personaje.TIAGO:
			assert_array(textos).has_size(4)
			assert_str(textos[1]).contains("investigador criminal")
			assert_str(textos[2]).contains("Enrique Peldaño")
			assert_str(textos[3]).contains("11 ****-****")
		assert_bool(atendida.despachada()).is_true()
		assert_bool(sprite.is_visible_in_tree()).is_false()
		assert_object(atenciones.tarea().en_ventanilla()).is_null()
		puesto.cerrar()
	assert_array(compras).has_size(2)
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_true()
	var registro: RegistroDeVentas = almacen.get("_computadora").registro()
	for fila: Array in [
		[Producto.Id.MAROLINI, 1],
		[Producto.Id.CORACOLA, 1],
		[Producto.Id.MALBARDO, 1],
		[Producto.Id.ZUCARACHAS, 2],
		[Producto.Id.PEPITOS, 1]
	]:
		var producto := Catalogo.de(fila[0])
		assert_int(atenciones.tarea().vendidas_de(producto)).is_equal(fila[1])
		for _unidad: int in int(fila[1]):
			registro.sumar(producto)
	assert_bool(registro.coincide()).is_true()


# AC-CTR-040, AC-STK-055, AC-PLY-079
func test_vencer_retira_productos_y_ticket_sin_registrar_una_venta() -> void:
	var almacen := await _abrir()
	var puesto: Puesto = almacen.get_node("Estructura/Ventanilla")
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var atenciones: Ventanilla = almacen.get("_atenciones")
	var agarre: Agarre = almacen.get("_agarre")
	reloj.avanzar(120.0)
	puesto.abrir()
	_conversar(almacen)
	var producto := Catalogo.de(Producto.Id.MAROLINI)
	almacen.get("_reposicion_manual").retirar(producto.id)
	var cuerpo := agarre.cuerpo_sostenido() as ObjetoAgarrable
	var identidad := cuerpo.datos as UnidadDeProducto
	_pulsar(almacen)
	assert_object(agarre.manos().sostenido()).is_null()
	var papel := _ticket(almacen, atenciones.atencion().comprador().pedido())
	agarre.pedir_agarrar(papel.datos, papel)
	_pulsar(almacen)
	assert_object(agarre.manos().sostenido()).is_null()
	_pulsar(almacen)
	assert_bool(atenciones.puede_abandonar()).is_false()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	pausa._input(escape)
	assert_bool(get_tree().paused).is_true()
	assert_bool(_panel(almacen).visible).is_true()
	pausa._input(escape)
	assert_bool(get_tree().paused).is_false()
	var derecho := InputEventAction.new()
	derecho.action = ReglasDelJugador.ACCION_USAR
	derecho.pressed = true
	puesto._input(derecho)
	assert_bool(_panel(almacen).visible).is_true()
	reloj.avanzar(120.0)
	assert_bool(atenciones.puede_abandonar()).is_true()
	assert_object(atenciones.tarea().en_ventanilla()).is_null()
	for _cuadro in 20:
		await get_tree().physics_frame
	assert_bool(is_instance_valid(papel)).is_false()
	assert_bool(is_instance_valid(cuerpo)).is_false()
	var repositor: Repositor = almacen.get("_repositor")
	assert_bool(repositor.caja(producto.id).meter(identidad)).is_false()
	assert_int(atenciones.tarea().vendidas_de(producto)).is_zero()
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_false()
