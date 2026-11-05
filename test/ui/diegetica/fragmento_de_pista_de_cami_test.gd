extends GdUnitTestSuite

const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const JORNADA_4 := GeneradorDeTickets.JORNADA_SIN_LECTOR - 1
const JORNADA_5 := GeneradorDeTickets.JORNADA_SIN_LECTOR
const LLEGADA_DE_CAMI := Vector2i(20, 30)
## Más entradas que las de Cami: corta el recorrido si el fragmento no aparece nunca.
const TOPE_DE_ENTRADAS := 30

var _almacenes: Array[Node3D] = []
var _ruta_anterior: String


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://fragmento_de_cami_prueba.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	for almacen in _almacenes:
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		almacen.queue_free()
	_almacenes.clear()
	for cuadro in 4:
		await get_tree().process_frame
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_anterior


## La quinta noche con `camino` elegido en la cuarta, y Cami ya en la ventanilla con su diálogo
## empezado.
func _con_cami(camino: String) -> Node3D:
	var partida := Partida.desde({"jornada": JORNADA_5, "medios": 0})
	partida.expediente.registrar(camino)
	partida.expediente.elegir(JORNADA_4, camino)
	var almacen: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
	almacen.set("_partida", partida)
	_almacenes.append(almacen)
	add_child(almacen)
	almacen.get_node("Jugador").set_physics_process(false)
	for cuadro in 3:
		await get_tree().physics_frame
	RelojDePrueba.avanzar_hasta(almacen.get("_reloj"), LLEGADA_DE_CAMI)
	almacen.get_node("Estructura/Ventanilla/Comprador/Objetivo").call("accionar")
	return almacen


func _texto_de(almacen: Node3D) -> RichTextLabel:
	var panel: PanelDeLaVentanilla = almacen.get_node("Estructura/Ventanilla").get("panel")
	return panel.get_node("Fisico/Dialogo/Texto") as RichTextLabel


func _clic_izquierdo(almacen: Node3D) -> void:
	var clic := InputEventMouseButton.new()
	clic.pressed = true
	clic.button_index = MOUSE_BUTTON_LEFT
	almacen.get_node("Estructura/Ventanilla").call("_input", clic)


func _atencion(almacen: Node3D) -> Atencion:
	return almacen.get("_atenciones").atencion()


func _avanzar_hasta_el_fragmento(almacen: Node3D) -> bool:
	for _paso in TOPE_DE_ENTRADAS:
		if _atencion(almacen).dialogo().entrada_actual().contains("[url="):
			return true
		if _atencion(almacen).dialogo().terminado():
			return false
		_clic_izquierdo(almacen)
	return false


func test_pulsar_el_fragmento_de_cami_registra_la_5a_sin_avanzar_el_dialogo() -> void:  # AC-INV-165
	var almacen := await _con_cami("2A")
	var expediente: Expediente = almacen.get("_partida").expediente
	assert_bool(_avanzar_hasta_el_fragmento(almacen)).is_true()
	var texto := _texto_de(almacen)
	assert_int(texto.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_array(Array(expediente.identidades())).is_equal(["2A"])
	var entrada := _atencion(almacen).dialogo().entrada_actual()
	texto.meta_clicked.emit("5A")
	assert_array(Array(expediente.identidades())).is_equal(["2A", "5A"])
	assert_str(_atencion(almacen).dialogo().entrada_actual()).is_equal(entrada)
	texto.meta_clicked.emit("5A")
	assert_array(Array(expediente.identidades())).is_equal(["2A", "5A"])


func test_con_el_juego_en_pausa_pulsar_el_fragmento_no_registra() -> void:  # AC-INV-165
	var almacen := await _con_cami("2A")
	var expediente: Expediente = almacen.get("_partida").expediente
	assert_bool(_avanzar_hasta_el_fragmento(almacen)).is_true()
	get_tree().paused = true
	_texto_de(almacen).meta_clicked.emit("5A")
	assert_array(Array(expediente.identidades())).is_equal(["2A"])


func test_leer_a_cami_sin_pulsar_el_fragmento_no_registra_nada() -> void:  # AC-INV-165
	var almacen := await _con_cami("2A")
	var expediente: Expediente = almacen.get("_partida").expediente
	for _paso in TOPE_DE_ENTRADAS:
		if _atencion(almacen).dialogo().terminado():
			break
		_clic_izquierdo(almacen)
	assert_bool(_atencion(almacen).dialogo().terminado()).is_true()
	assert_array(Array(expediente.identidades())).is_equal(["2A"])


func test_un_clic_sobre_el_fragmento_no_avanza_y_fuera_de_el_si() -> void:  # AC-INV-165
	var almacen := await _con_cami("2A")
	assert_bool(_avanzar_hasta_el_fragmento(almacen)).is_true()
	var texto := _texto_de(almacen)
	var entrada := _atencion(almacen).dialogo().entrada_actual()
	texto.meta_hover_started.emit("5A")
	_clic_izquierdo(almacen)
	assert_str(_atencion(almacen).dialogo().entrada_actual()).is_equal(entrada)
	texto.meta_hover_ended.emit("5A")
	_clic_izquierdo(almacen)
	assert_str(_atencion(almacen).dialogo().entrada_actual()).is_not_equal(entrada)


func test_por_el_camino_de_2b_cami_no_trae_el_fragmento_ni_registra() -> void:  # AC-INV-165
	var almacen := await _con_cami("2B")
	var expediente: Expediente = almacen.get("_partida").expediente
	assert_bool(_avanzar_hasta_el_fragmento(almacen)).is_false()
	assert_bool(_atencion(almacen).dialogo().terminado()).is_true()
	assert_array(Array(expediente.identidades())).is_equal(["2B"])
	_texto_de(almacen).meta_clicked.emit("5A")
	assert_array(Array(expediente.identidades())).is_equal(["2B"])
