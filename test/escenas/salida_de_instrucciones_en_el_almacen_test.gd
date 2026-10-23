extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

var _almacen: Node3D
var _instrucciones: PantallaDeInstrucciones
var _persiana: PersianaDeLaNoche
var _ahora: Array[int] = [0]
var _ruta_anterior: String


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = create_temp_dir("salida_intro").path_join("partida.guardado")
	_ahora = [0]
	_almacen = ALMACEN.instantiate()
	get_tree().root.add_child(_almacen)
	_instrucciones = _almacen.get("_instrucciones")
	_persiana = _almacen.get_node("Interfaz/PersianaDeLaNoche")
	_instrucciones.set("_ahora", func() -> int: return _ahora[0])
	_persiana.set("_ahora", func() -> int: return _ahora[0])


func after_test() -> void:
	get_tree().paused = false
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in _almacen.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	_almacen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Guardado.ruta_por_defecto = _ruta_anterior


func _animar(microsegundos: int) -> void:
	var hasta := _ahora[0] + microsegundos
	while _ahora[0] < hasta:
		_ahora[0] = mini(_ahora[0] + 10000, hasta)
		_instrucciones._process(0.0)
		_persiana._process(0.0)


func _siguiente() -> void:
	(_instrucciones.get("_siguiente") as Button).pressed.emit()


func _pausar() -> void:
	var evento := InputEventAction.new()
	evento.action = "ui_cancel"
	evento.pressed = true
	(_almacen.get_node("Interfaz/ControlDePausa") as ControlDePausa)._input(evento)


# AC-EMP-048, AC-EMP-049
func test_placa_y_subida_esperan_la_salida_incluso_con_pausa_y_doble_clic() -> void:
	_almacen.call("empezar_partida_nueva")
	_animar(300000)
	var instrucciones: InstruccionesDelJefe = _instrucciones.get("_instrucciones")
	while not instrucciones.terminadas():
		_siguiente()
	_siguiente()
	var placa: Label = _persiana.get("_placa")
	var fondo: TextureRect = _persiana.get("_persiana")
	var marco: Control = _instrucciones.get("_marco")
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	var turno: Turno = reloj.get("_turno")
	var restante := turno.tiempo_restante()
	var pedidos: Array[int] = [0]
	_instrucciones.comenzar_pedido.connect(func() -> void: pedidos[0] += 1)
	_animar(150000)
	assert_bool(placa.visible).is_false()
	assert_object(_persiana.get("_entrada")).is_null()
	var posicion := marco.position
	var posicion_del_fondo := fondo.position
	_pausar()
	assert_bool(get_tree().paused).is_true()
	_ahora[0] += 120000000
	for _cuadro in 4:
		await get_tree().process_frame
	assert_vector(marco.position).is_equal(posicion)
	assert_bool(placa.visible).is_false()
	assert_float(turno.tiempo_restante()).is_equal(restante)
	_pausar()
	_animar(149999)
	assert_bool(placa.visible).is_false()
	assert_bool(_instrucciones.visible).is_true()
	_animar(1)
	assert_bool(_instrucciones.visible).is_false()
	assert_bool(placa.visible).is_true()
	assert_str(placa.text).is_equal("NOCHE 1")
	assert_vector(fondo.position).is_equal(posicion_del_fondo)
	assert_float(turno.tiempo_restante()).is_equal(restante)
	_siguiente()
	assert_int(pedidos[0]).is_equal(1)
	_persiana.terminar()
	assert_bool(reloj.corriendo()).is_true()


func test_retomar_desde_menu_repite_entrada_en_las_cuatro_jornadas() -> void:  # AC-EMP-049
	for jornada in range(1, 5):
		var guardado := Guardado.new()
		assert_bool(guardado.escribir(PartidaSerializada.sanear({"jornada": jornada}))).is_true()
		_almacen.call("retomar_la_partida")
		var marco: Control = _instrucciones.get("_marco")
		var disponible := _instrucciones.get_viewport().get_visible_rect().size
		assert_bool(_instrucciones.visible).is_true()
		assert_float(marco.position.x).is_greater_equal(disponible.x)
		var y := marco.position.y
		_animar(150000)
		var mitad := marco.position.x
		_animar(150000)
		assert_float(mitad).is_greater(marco.position.x)
		assert_float(marco.position.x).is_equal_approx(
			(disponible.x - marco.size.x * marco.scale.x) / 2.0, 0.01
		)
		assert_float(marco.position.y).is_equal(y)
		assert_bool((_persiana.get("_placa") as Label).visible).is_false()
