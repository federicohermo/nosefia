extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Puesto := preload("res://src/escenas/puestos/ventanilla.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

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
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	if puesto.get("_abierta"):
		puesto.call("_input", clic)
	else:
		puesto.get_node("Comprador/Objetivo").call("accionar")


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


# AC-CTR-039, AC-CTR-041, AC-STK-054, AC-STK-056, AC-PLY-102
func test_las_dos_compras_fisicas_registran_una_vez_y_se_van_tras_despedirse() -> void:
	var almacen := await _abrir()
	var puesto: Puesto = almacen.get_node("Estructura/Ventanilla")
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var atenciones: Ventanilla = almacen.get("_atenciones")
	var agarre: Agarre = almacen.get("_agarre")
	var computadora: ComputadoraDeEscritorio = almacen.get("_computadora")
	var deposito: Puerta = almacen.get_node("Estructura/puerta/CuerpoDeLaHoja").call("puerta")
	assert_bool(deposito.trabada()).is_true()
	var compras: Array[bool] = []
	atenciones.compra_realizada.connect(func() -> void: compras.append(true))
	puesto.abrir()
	assert_object(atenciones.atencion()).is_null()
	puesto.cerrar()
	for hora: Vector2i in [Vector2i(22, 0), Vector2i(23, 30)]:
		RelojDePrueba.avanzar_hasta(reloj, hora)
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
				computadora.pedir_sumar(producto)
		assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_false()
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
		assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_equal(
			hora == Vector2i(23, 30)
		)
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
		if atendida.comprador().personaje == DialogosDeCompradores.Personaje.TIA:
			assert_array(textos).has_size(4)
		assert_bool(atendida.despachada()).is_true()
		assert_bool(sprite.is_visible_in_tree()).is_false()
		assert_object(atenciones.tarea().en_ventanilla()).is_null()
		puesto.cerrar()
	assert_array(compras).has_size(2)
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_true()
	var registro: RegistroDeVentas = almacen.get("_computadora").registro()
	for fila: Array in [
		[Producto.Id.MAROLINI, 1],
		[Producto.Id.PURA_COLA, 1],
		[Producto.Id.MALBARDO, 1],
		[Producto.Id.ZUCARACHAS, 1],
		[Producto.Id.PEPITO, 1]
	]:
		var producto := Catalogo.de(fila[0])
		assert_int(atenciones.tarea().vendidas_de(producto)).is_equal(fila[1])
	assert_bool(registro.coincide()).is_true()
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()
	for tarea: Tarea in (almacen.get("_partida") as Partida).obligatorias():
		assert_bool(tarea.completada()).override_failure_message(str(tarea.tipo())).is_true()
	assert_bool(deposito.trabada()).is_true()
	assert_bool(deposito.abierta()).is_false()


func _vender_y_anotar_actual(almacen: Node3D) -> void:
	var atenciones: Ventanilla = almacen.get("_atenciones")
	var agarre: Agarre = almacen.get("_agarre")
	var computadora: ComputadoraDeEscritorio = almacen.get("_computadora")
	var pedido := atenciones.atencion().comprador().pedido()
	for producto in pedido.productos():
		for _unidad in pedido.unidades_de(producto):
			almacen.get("_reposicion_manual").retirar(producto.id)
			_pulsar(almacen)
			assert_object(agarre.manos().sostenido()).is_null()
			computadora.pedir_sumar(producto)
	var papel := _ticket(almacen, pedido)
	assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
	_pulsar(almacen)
	assert_bool(atenciones.atencion().vendida()).is_true()
	assert_bool(atenciones.atencion().despachada()).is_false()


# AC-CTR-040, AC-STK-055, AC-STK-024, AC-STK-056, AC-PLY-079
func test_vencer_devuelve_producto_y_descarta_ticket_sin_venderlo() -> void:
	var almacen := await _abrir()
	var puesto: Puesto = almacen.get_node("Estructura/Ventanilla")
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var atenciones: Ventanilla = almacen.get("_atenciones")
	var agarre: Agarre = almacen.get("_agarre")
	var computadora: ComputadoraDeEscritorio = almacen.get("_computadora")
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(22, 0))
	puesto.abrir()
	_conversar(almacen)
	_vender_y_anotar_actual(almacen)
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_false()
	_conversar(almacen)
	puesto.cerrar()
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(23, 30))
	puesto.abrir()
	_conversar(almacen)
	var producto := Catalogo.de(Producto.Id.ZUCARACHAS)
	almacen.get("_reposicion_manual").retirar(producto.id)
	var cuerpo := agarre.cuerpo_sostenido() as ObjetoAgarrable
	var identidad := cuerpo.datos as UnidadDeProducto
	_pulsar(almacen)
	assert_object(agarre.manos().sostenido()).is_null()
	var papel := _ticket(almacen, atenciones.atencion().comprador().pedido())
	assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
	_pulsar(almacen)
	assert_object(agarre.manos().sostenido()).is_null()
	# El recordatorio sale como subtítulo: no abre la ventanilla ni retiene al jugador.
	_pulsar(almacen)
	assert_bool(atenciones.puede_abandonar()).is_true()
	assert_bool(_panel(almacen).visible).is_false()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	pausa._input(escape)
	assert_bool(get_tree().paused).is_true()
	pausa._input(escape)
	assert_bool(get_tree().paused).is_false()
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_false()
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(2, 0))
	assert_bool(atenciones.puede_abandonar()).is_true()
	assert_object(atenciones.tarea().en_ventanilla()).is_null()
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()
	for _cuadro in 30:
		await get_tree().physics_frame
	assert_bool(is_instance_valid(papel)).is_false()
	assert_bool(is_instance_valid(cuerpo)).is_true()
	if not is_instance_valid(cuerpo):
		return
	assert_object(cuerpo.datos).is_same(identidad)
	assert_array(almacen.get("_reposicion_manual").unidades_sueltas()).contains_exactly([cuerpo])
	assert_bool(cuerpo.freeze).is_false()
	assert_bool(cuerpo.visible).is_true()
	assert_bool(cuerpo.has_meta(&"recibido_por_comprador")).is_false()
	assert_int(atenciones.tarea().vendidas_de(producto)).is_zero()
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_false()
	computadora.pedir_sumar(producto)
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_false()
	computadora.pedir_restar(producto)
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	assert_bool(reloj.corriendo()).is_false()
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()


# AC-CTR-041
func test_otra_jornada_atiende_con_el_panel_de_cobro_mientras_corre_el_reloj() -> void:
	var almacen := await _abrir()
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2)
	var puesto: Puesto = almacen.get_node("Estructura/Ventanilla")
	var camara := Camera3D.new()
	puesto.add_child(camara)
	camara.position = Vector3(0.0, 0.7, -2.0)
	camara.make_current()
	puesto.abrir()
	var atenciones: Ventanilla = almacen.get("_atenciones")
	assert_bool(atenciones.atencion().fisica()).is_false()
	var renglones: VBoxContainer = _panel(almacen).get("_renglones")
	var primero := renglones.get_child(0)
	RelojDePrueba.avanzar_turno(almacen.get("_reloj"), 1.0)
	assert_object(renglones.get_child(0)).is_same(primero)
	assert_bool((_panel(almacen).get("_cobrar") as Button).visible).is_true()


func _texto_del_comprador(almacen: Node3D) -> RichTextLabel:
	return almacen.get("_hud").get("_texto_del_comprador")


# AC-CTR-037, AC-CTR-066, AC-CTR-067
func test_tia_conserva_la_mano_al_rechazar_el_sobrante_y_recuerda_lo_que_falta() -> void:
	var almacen := await _abrir()
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var atenciones: Ventanilla = almacen.get("_atenciones")
	var agarre: Agarre = almacen.get("_agarre")
	var puesto: Puesto = almacen.get_node("Estructura/Ventanilla")
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(23, 30))
	puesto.abrir()
	_conversar(almacen)
	var producto := Catalogo.de(Producto.Id.ZUCARACHAS)
	var texto := _texto_del_comprador(almacen)
	_pulsar(almacen)
	assert_int(texto.text.count("[color=#e4f850]")).is_equal(2)
	almacen.get("_reposicion_manual").retirar(producto.id)
	var primera := agarre.cuerpo_sostenido()
	_pulsar(almacen)
	assert_object(agarre.cuerpo_sostenido()).is_null()
	assert_bool(primera.visible).is_false()
	assert_bool(texto.text.begins_with(DialogosDeCompradores.FALTA)).is_true()
	assert_int(texto.text.count("[color=#e4f850]")).is_equal(1)
	_pulsar(almacen)
	assert_int(texto.text.count("[color=#e4f850]")).is_equal(1)
	almacen.get("_reposicion_manual").retirar(producto.id)
	var sobrante := agarre.cuerpo_sostenido()
	var identidad := agarre.manos().sostenido()
	_pulsar(almacen)
	assert_object(agarre.cuerpo_sostenido()).is_same(sobrante)
	assert_object(agarre.manos().sostenido()).is_same(identidad)
	assert_str(texto.text).is_equal(DialogosDeCompradores.YA_ENTREGADO)
	assert_int(atenciones.tarea().vendidas_de(producto)).is_zero()
	assert_bool(atenciones.atencion().vendida()).is_false()
	_pulsar(almacen)
	assert_object(agarre.cuerpo_sostenido()).is_same(sobrante)
