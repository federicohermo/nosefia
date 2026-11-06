extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/interrupciones/persiana_de_la_noche.tscn")

var _persiana: PersianaDeLaNoche
var _ahora: Array[int] = [0]
var _bajadas := 0


func before_test() -> void:
	_ahora[0] = 0
	_bajadas = 0
	_persiana = ESCENA.instantiate()
	get_tree().root.add_child(_persiana)
	_persiana.set("_ahora", func() -> int: return _ahora[0])
	_persiana.set_process(false)
	_persiana.persiana_bajada.connect(func() -> void: _bajadas += 1)


func after_test() -> void:
	_persiana.free()


func _avanzar(segundos: float) -> void:
	_ahora[0] += int(segundos * 1000000.0)
	_persiana.call("_process", 0.0)
	_persiana.set_process(false)


func _posicion() -> float:
	return (_persiana.get_node("Persiana") as TextureRect).position.y


func _altura() -> float:
	return _persiana.get_viewport().get_visible_rect().size.y


func test_la_persiana_baja_frenando_al_llegar_abajo() -> void:  # AC-EMP-118
	var duracion := EntradaALaNoche.SUBIDA_DE_LA_PERSIANA
	_persiana.call("bajar")
	assert_float(_posicion()).is_equal(-_altura())
	_avanzar(duracion * 0.1)
	var tras_el_primero := _posicion()
	_avanzar(duracion * 0.4)
	assert_float(_posicion()).is_greater(-_altura() / 2.0).is_less(0.0)
	_avanzar(duracion * 0.4)
	var antes_del_ultimo := _posicion()
	_avanzar(duracion * 0.1)
	var primer_tramo := tras_el_primero - (-_altura())
	var ultimo_tramo := _posicion() - antes_del_ultimo
	assert_float(ultimo_tramo).is_greater(0.0).is_less(primer_tramo)
	assert_float(_posicion()).is_zero()
	assert_int(_bajadas).is_equal(1)
	_avanzar(duracion)
	assert_int(_bajadas).is_equal(1)


func test_pausar_a_mitad_de_la_bajada_congela_la_curva() -> void:  # AC-EMP-118
	var duracion := EntradaALaNoche.SUBIDA_DE_LA_PERSIANA
	_persiana.call("bajar")
	_avanzar(duracion * 0.5)
	var antes := _posicion()
	_ahora[0] += 5000000
	_persiana.notification(Node.NOTIFICATION_UNPAUSED)
	_avanzar(0.0)
	assert_float(_posicion()).is_equal(antes)
	assert_int(_bajadas).is_equal(0)
	_avanzar(duracion * 0.5)
	assert_float(_posicion()).is_zero()
	assert_int(_bajadas).is_equal(1)


func test_el_sonido_de_la_bajada_dura_lo_que_la_bajada() -> void:  # AC-EMP-119
	var movimiento: AudioStreamPlayer = _persiana.get_node("Movimiento")
	_persiana.call("bajar")
	var segundos := movimiento.stream.get_length() / movimiento.pitch_scale
	assert_float(segundos).is_equal_approx(EntradaALaNoche.SUBIDA_DE_LA_PERSIANA, 0.001)
