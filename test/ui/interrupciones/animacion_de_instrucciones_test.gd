extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/interrupciones/pantalla_de_instrucciones.tscn")

var _ahora: Array[int] = [0]
var _pantalla: PantallaDeInstrucciones
var _marco: Control
var _fondo: TextureRect
var _comienzos: int = 0


func before_test() -> void:
	_ahora = [0]
	_comienzos = 0
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(viewport)
	_pantalla = ESCENA.instantiate()
	viewport.add_child(_pantalla)
	_pantalla.set("_ahora", func() -> int: return _ahora[0])
	_pantalla.comenzar_pedido.connect(func() -> void: _comienzos += 1)
	_marco = _pantalla.get("_marco")
	_fondo = _pantalla.get("_fondo")
	_mostrar()


func after_test() -> void:
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame


func _mostrar() -> void:
	var mensaje := Mensaje.new()
	mensaje.texto = "Instrucciones de Enrique"
	_pantalla.mostrar([mensaje])


func _avanzar(microsegundos: int) -> void:
	var hasta := _ahora[0] + microsegundos
	while _ahora[0] < hasta:
		_ahora[0] = mini(_ahora[0] + 10000, hasta)
		if _pantalla.is_processing():
			_pantalla._process(0.0)


func _comenzar() -> void:
	(_pantalla.get("_siguiente") as Button).pressed.emit()


func test_entrada_desde_fuera_del_margen_derecho_con_ease_out() -> void:  # AC-EMP-049
	for tamano: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(2560, 1080)]:
		(_pantalla.get_viewport() as SubViewport).size = tamano
		_mostrar()
		assert_float(_marco.position.x).is_greater_equal(float(tamano.x))
		var y := _marco.position.y
		var inicio := _marco.position.x
		_avanzar(100000)
		var primera := _marco.position.x
		_avanzar(100000)
		var segunda := _marco.position.x
		_avanzar(100000)
		var destino := (tamano.x - _marco.size.x * _marco.scale.x) / 2.0
		assert_float(_marco.position.x).is_equal_approx(destino, 0.01)
		assert_float(inicio - primera).is_greater(primera - segunda)
		assert_float(primera - segunda).is_greater(segunda - destino)
		assert_float(_marco.position.y).is_equal(y)
		assert_bool(_pantalla.is_processing()).is_false()


func test_salida_acelera_hacia_la_izquierda_y_emite_una_sola_vez() -> void:  # AC-EMP-049
	_avanzar(300000)
	_comenzar()
	_comenzar()
	assert_int(_comienzos).is_zero()
	assert_bool(_pantalla.visible).is_true()
	assert_bool((_pantalla.get("_siguiente") as Button).disabled).is_true()
	assert_bool((_pantalla.get("_volver") as Button).disabled).is_true()
	var inicio := _marco.position.x
	_avanzar(100000)
	var primera := _marco.position.x
	_comenzar()
	_avanzar(100000)
	var segunda := _marco.position.x
	assert_float(primera - segunda).is_greater(inicio - primera)
	_avanzar(99999)
	assert_int(_comienzos).is_zero()
	assert_bool(_pantalla.visible).is_true()
	_avanzar(1)
	assert_float(_marco.get_global_rect().end.x).is_less_equal(0.0)
	assert_bool(_pantalla.visible).is_false()
	assert_int(_comienzos).is_equal(1)
	_comenzar()
	_avanzar(300000)
	assert_int(_comienzos).is_equal(1)


func test_el_fondo_no_se_desplaza_ni_se_desvanece_al_salir() -> void:  # AC-EMP-049
	var posicion := _fondo.position
	var tamano := _fondo.size
	assert_float(_fondo.modulate.a).is_zero()
	_avanzar(150000)
	assert_float(_fondo.modulate.a).is_equal_approx(0.5, 0.001)
	_avanzar(150000)
	_comenzar()
	_avanzar(150000)
	assert_float(_fondo.modulate.a).is_equal(1.0)
	assert_vector(_fondo.position).is_equal(posicion)
	assert_vector(_fondo.size).is_equal(tamano)


func test_pausar_entrada_y_salida_conserva_el_punto_y_excluye_dos_minutos() -> void:  # AC-EMP-049
	for salida: bool in [false, true]:
		_mostrar()
		if salida:
			_avanzar(300000)
			_comenzar()
		_avanzar(150000)
		var posicion := _marco.position
		get_tree().paused = true
		_ahora[0] += 120000000
		for _cuadro in 4:
			await get_tree().process_frame
		assert_vector(_marco.position).is_equal(posicion)
		assert_int(_comienzos).is_zero()
		get_tree().paused = false
		_avanzar(10000)
		assert_float(_marco.position.x).is_less(posicion.x)
		assert_bool(_pantalla.visible).is_true()
		_avanzar(140000)
		assert_bool(_pantalla.visible).is_equal(not salida)
	assert_int(_comienzos).is_equal(1)


func test_mostrar_durante_salida_reinicia_la_entrada_sin_comienzo_pendiente() -> void:  # AC-EMP-049
	_avanzar(300000)
	_comenzar()
	_avanzar(150000)
	_mostrar()
	assert_float(_marco.position.x).is_greater_equal(_fondo.size.x)
	_avanzar(300000)
	assert_bool(_pantalla.visible).is_true()
	assert_bool((_pantalla.get("_siguiente") as Button).disabled).is_false()
	assert_int(_comienzos).is_zero()


func test_comenzar_durante_entrada_sale_desde_el_punto_actual() -> void:  # AC-EMP-049
	_avanzar(150000)
	var posicion := _marco.position
	_comenzar()
	assert_vector(_marco.position).is_equal(posicion)
	_avanzar(10000)
	assert_float(_fondo.modulate.a).is_equal_approx(160000.0 / 300000.0, 0.001)
	_avanzar(290000)
	assert_float(_marco.get_global_rect().end.x).is_less_equal(0.0)
	assert_int(_comienzos).is_equal(1)
