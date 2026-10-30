extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/interrupciones/pantalla_de_instrucciones.tscn")
const PLACAS := 4
const CUADRO := 10000

var _ahora: Array[int] = [0]
var _pantalla: PantallaDeInstrucciones
var _mensajes: Array[Mensaje] = []


func before_test() -> void:
	_ahora = [0]
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(viewport)
	_pantalla = ESCENA.instantiate()
	viewport.add_child(_pantalla)
	_pantalla.set("_ahora", func() -> int: return _ahora[0])
	_mensajes = []
	for numero in PLACAS:
		var mensaje := Mensaje.new()
		mensaje.texto = "Placa %d" % (numero + 1)
		_mensajes.append(mensaje)
	_pantalla.mostrar(_mensajes)
	_avanzar(_duracion_de_la_entrada())


func after_test() -> void:
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame


func _duracion_de_la_entrada() -> int:
	return roundi(PantallaDeInstrucciones.DURACION_DEL_MOVIMIENTO * 1000000.0)


func _duracion() -> int:
	return roundi(PantallaDeInstrucciones.DURACION_DEL_DESLIZAMIENTO * 1000000.0)


func _avanzar(microsegundos: int) -> void:
	var hasta := _ahora[0] + microsegundos
	while _ahora[0] < hasta:
		_ahora[0] = mini(_ahora[0] + CUADRO, hasta)
		if _pantalla.is_processing():
			_pantalla._process(0.0)


func _nodo(nombre: String) -> Control:
	return _pantalla.get(nombre)


func _boton(nombre: String) -> Button:
	return _pantalla.get(nombre)


func _siguiente() -> void:
	_boton("_siguiente").pressed.emit()


func _volver() -> void:
	_boton("_volver").pressed.emit()


## La placa de la que sale el contenido: lo que quedó en el recuadro al cambiar.
func _textos(contenedor: Control) -> Array[String]:
	var textos: Array[String] = []
	for cuerpo: RichTextLabel in contenedor.find_children("*", "RichTextLabel", false, false):
		textos.append(cuerpo.get_parsed_text())
	return textos


func _fijos() -> Array[Vector2]:
	var posiciones: Array[Vector2] = []
	for nombre in ["_retrato", "_botones", "_contador", "_volver", "_siguiente"]:
		posiciones.append(_nodo(nombre).global_position)
	var bocadillo := _nodo("_retrato").find_child("Bocadillo", true, false) as Control
	posiciones.append(bocadillo.global_position)
	return posiciones


func _terminado() -> void:
	assert_int(_nodo("_saliente").get_child_count()).is_zero()
	assert_float(_nodo("_contenido").position.x).is_zero()


func test_siguiente_desliza_la_placa_nueva_desde_la_derecha() -> void:  # AC-EMP-112
	var fijos := _fijos()
	var recuadro := _nodo("_recuadro")
	assert_bool(recuadro.clip_contents).is_true()
	assert_object(_nodo("_contenido").get_parent()).is_same(recuadro)
	assert_object(_nodo("_saliente").get_parent()).is_same(recuadro)
	_siguiente()
	assert_float(_nodo("_contenido").position.x).is_greater(0.0)
	_avanzar(_duracion() / 2)
	var vieja := _nodo("_saliente")
	var nueva := _nodo("_contenido")
	assert_array(_textos(vieja)).is_equal([_mensajes[0].texto.replace("[b]", "")])
	assert_array(_textos(nueva)).is_equal([_mensajes[1].texto.replace("[b]", "")])
	assert_float(vieja.position.x).is_less(0.0)
	assert_float(nueva.position.x).is_greater(0.0)
	assert_float(nueva.position.x).is_less(recuadro.size.x)
	assert_float(nueva.position.x).is_greater(vieja.position.x)
	assert_str((_nodo("_contador") as Label).text).is_equal("1/%d" % PLACAS)
	assert_array(_fijos()).is_equal(fijos)
	_avanzar(_duracion() - _duracion() / 2)
	_terminado()
	assert_str((_nodo("_contador") as Label).text).is_equal("2/%d" % PLACAS)
	assert_array(_textos(_nodo("_contenido"))).is_equal([_mensajes[1].texto.replace("[b]", "")])
	assert_array(_fijos()).is_equal(fijos)
	assert_bool(_pantalla.is_processing()).is_false()


func test_el_movimiento_dura_lo_declarado_y_la_nueva_no_pasa_de_su_lugar() -> void:  # AC-EMP-112
	var ancho := _nodo("_contenido").size.x
	_siguiente()
	var anterior := _nodo("_contenido").position.x
	for _cuadro in (_duracion() - CUADRO) / CUADRO:
		_avanzar(CUADRO)
		var actual := _nodo("_contenido").position.x
		assert_float(actual).is_less_equal(anterior)
		assert_float(actual).is_greater_equal(-0.05 * ancho)
		anterior = actual
	assert_int(_nodo("_saliente").get_child_count()).is_greater(0)
	assert_bool(_pantalla.is_processing()).is_true()
	_avanzar(CUADRO)
	_terminado()
	assert_bool(_pantalla.is_processing()).is_false()


func test_volver_invierte_la_direccion() -> void:  # AC-EMP-113
	_siguiente()
	_avanzar(_duracion())
	_siguiente()
	_avanzar(_duracion())
	assert_str((_nodo("_contador") as Label).text).is_equal("3/%d" % PLACAS)
	var fijos := _fijos()
	_volver()
	_avanzar(_duracion() / 2)
	var vieja := _nodo("_saliente")
	var nueva := _nodo("_contenido")
	assert_array(_textos(vieja)).is_equal([_mensajes[2].texto.replace("[b]", "")])
	assert_array(_textos(nueva)).is_equal([_mensajes[1].texto.replace("[b]", "")])
	assert_float(vieja.position.x).is_greater(0.0)
	assert_float(nueva.position.x).is_less(0.0)
	assert_float(nueva.position.x).is_greater(-_nodo("_recuadro").size.x)
	assert_str((_nodo("_contador") as Label).text).is_equal("3/%d" % PLACAS)
	assert_array(_fijos()).is_equal(fijos)
	_avanzar(_duracion())
	_terminado()
	assert_str((_nodo("_contador") as Label).text).is_equal("2/%d" % PLACAS)


func test_volver_en_la_primera_no_mueve_nada() -> void:  # AC-EMP-113
	assert_bool(_boton("_volver").disabled).is_true()
	_volver()
	assert_bool(_pantalla.is_processing()).is_false()
	_terminado()
	assert_str((_nodo("_contador") as Label).text).is_equal("1/%d" % PLACAS)


func test_un_gesto_durante_el_movimiento_lo_completa_sin_saltear_placas() -> void:  # AC-EMP-114
	_siguiente()
	_avanzar(_duracion() / 2)
	_siguiente()
	assert_array(_textos(_nodo("_saliente"))).is_equal([_mensajes[1].texto.replace("[b]", "")])
	assert_array(_textos(_nodo("_contenido"))).is_equal([_mensajes[2].texto.replace("[b]", "")])
	assert_int(_nodo("_saliente").get_child_count()).is_equal(1)
	assert_str((_nodo("_contador") as Label).text).is_equal("2/%d" % PLACAS)
	_avanzar(_duracion())
	_terminado()
	assert_array(_textos(_nodo("_contenido"))).is_equal([_mensajes[2].texto.replace("[b]", "")])
	assert_str((_nodo("_contador") as Label).text).is_equal("3/%d" % PLACAS)


func test_volver_durante_el_movimiento_lo_completa_y_regresa() -> void:  # AC-EMP-114
	_siguiente()
	_avanzar(_duracion() / 2)
	_volver()
	assert_array(_textos(_nodo("_saliente"))).is_equal([_mensajes[1].texto.replace("[b]", "")])
	assert_array(_textos(_nodo("_contenido"))).is_equal([_mensajes[0].texto.replace("[b]", "")])
	assert_float(_nodo("_contenido").position.x).is_less(0.0)
	_avanzar(_duracion())
	_terminado()
	assert_array(_textos(_nodo("_contenido"))).is_equal([_mensajes[0].texto.replace("[b]", "")])
	assert_str((_nodo("_contador") as Label).text).is_equal("1/%d" % PLACAS)


func test_pausar_a_mitad_del_movimiento_lo_congela_y_lo_reanuda() -> void:  # AC-EMP-114
	_siguiente()
	_avanzar(_duracion() / 2)
	var posicion := _nodo("_contenido").position.x
	get_tree().paused = true
	_ahora[0] += 120000000
	for _cuadro in 4:
		await get_tree().process_frame
	assert_float(_nodo("_contenido").position.x).is_equal(posicion)
	assert_int(_nodo("_saliente").get_child_count()).is_greater(0)
	get_tree().paused = false
	_avanzar(CUADRO)
	assert_float(_nodo("_contenido").position.x).is_less(posicion)
	assert_float(_nodo("_contenido").position.x).is_greater(0.0)
	_avanzar(_duracion())
	_terminado()


func test_ok_no_mueve_pantallas_y_arranca_la_salida() -> void:  # AC-EMP-114
	for _paso in PLACAS - 1:
		_siguiente()
		_avanzar(_duracion())
	assert_str(_boton("_siguiente").text).is_equal(PantallaDeInstrucciones.TEXTO_DE_COMENZAR)
	_siguiente()
	_terminado()
	var marco := _nodo("_marco")
	var inicio := marco.position.x
	_avanzar(CUADRO)
	assert_float(marco.position.x).is_less(inicio)
	assert_array(_textos(_nodo("_contenido"))).is_equal(
		[_mensajes[PLACAS - 1].texto.replace("[b]", "")]
	)


func test_ok_durante_el_movimiento_lo_completa_antes_de_salir() -> void:  # AC-EMP-114
	for _paso in PLACAS - 2:
		_siguiente()
		_avanzar(_duracion())
	_siguiente()
	_avanzar(_duracion() / 2)
	_siguiente()
	_terminado()
	assert_array(_textos(_nodo("_contenido"))).is_equal(
		[_mensajes[PLACAS - 1].texto.replace("[b]", "")]
	)
	assert_bool(_pantalla.is_processing()).is_true()
	_avanzar(_duracion_de_la_entrada())
	assert_bool(_pantalla.visible).is_false()


func test_el_resorte_parte_de_cero_llega_a_uno_y_no_da_un_salto_al_final() -> void:  # AC-EMP-112
	assert_float(PantallaDeInstrucciones.avance_del_resorte(0.0)).is_zero()
	assert_float(PantallaDeInstrucciones.avance_del_resorte(1.0)).is_equal(1.0)
	assert_float(PantallaDeInstrucciones.avance_del_resorte(0.999)).is_equal_approx(1.0, 0.005)
	var anterior := 0.0
	for cuadro in range(1, 81):
		var avance := PantallaDeInstrucciones.avance_del_resorte(cuadro / 80.0)
		assert_float(avance).is_greater_equal(anterior)
		assert_float(avance).is_less_equal(1.0 + 0.05)
		anterior = avance
