extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/interrupciones/persiana_de_la_noche.tscn")

var _persiana: PersianaDeLaNoche
var _ahora: Array[int] = [0]
var _ordenes: Array[String] = []


func before_test() -> void:
	_ahora[0] = 0
	_ordenes.clear()
	_persiana = ESCENA.instantiate()
	get_tree().root.add_child(_persiana)
	_persiana.set("_ahora", func() -> int: return _ahora[0])
	_persiana.set_process(false)
	_persiana.sonido_pedido.connect(func() -> void: _ordenes.append("sonar"))
	_persiana.silencio_pedido.connect(func() -> void: _ordenes.append("callar"))


func after_test() -> void:
	_persiana.free()


func _avanzar(segundos: float) -> void:
	_ahora[0] += int(segundos * 1000000.0)
	_persiana.call("_process", 0.0)
	_persiana.set_process(false)


func _sonido() -> AudioStreamPlayer:
	return _persiana.get_node_or_null("Movimiento") as AudioStreamPlayer


func test_suena_al_moverse_y_no_durante_la_placa_ni_la_intro() -> void:
	assert_object(_sonido()).is_not_null()
	if _sonido() == null:
		return
	_persiana.mostrar_baja()
	_avanzar(0.3)
	assert_array(_ordenes).not_contains(["sonar"])
	_persiana.anunciar(1)
	_avanzar(1.5)
	assert_array(_ordenes).not_contains(["sonar"])
	_avanzar(0.1)
	assert_int(_ordenes.count("sonar")).is_equal(1)
	_avanzar(0.1)
	assert_int(_ordenes.count("sonar")).is_equal(1)
	assert_str(_sonido().stream.resource_path).ends_with("SFX_NOLEV_Puerta_Garage.wav")
	assert_str(_sonido().bus).is_equal(EntradaSonora.BUS_DE_EFECTOS)
	_persiana.terminar()
	assert_str(_ordenes.back()).is_equal("callar")


func test_bajar_mueve_la_misma_persiana_con_sonido_y_sin_anunciar_noche() -> void:
	assert_object(_sonido()).is_not_null()
	if _sonido() == null:
		return
	var subidas: Array[int] = []
	_persiana.persiana_subida.connect(func(noche: int) -> void: subidas.append(noche))
	_persiana.call("bajar")
	var textura: TextureRect = _persiana.get_node("Persiana")
	assert_float(textura.position.y).is_less(0.0)
	assert_array(_ordenes).is_equal(["sonar"])
	_avanzar(0.5)
	assert_float(textura.position.y).is_less(0.0)
	_avanzar(0.5)
	assert_float(textura.position.y).is_zero()
	assert_array(_ordenes).is_equal(["sonar", "callar"])
	assert_array(subidas).is_empty()
	assert_bool((_persiana.get_node("Marco/Placa") as Label).visible).is_false()
