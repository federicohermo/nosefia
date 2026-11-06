## El epílogo del final 1 en el almacén: entre la devolución del cierre y la pantalla de final se
## ven sus placas, y mientras se ven el juego queda quieto.
extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")
const AvanceDelEpilogo := preload("res://test/avance_del_epilogo.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const ALMACEN := preload("res://src/escenas/almacen.tscn")

var _almacen: Node3D
var _escena_anterior: Node
var _ruta_anterior: String


func before_test() -> void:
	_escena_anterior = get_tree().current_scene
	_ruta_anterior = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://epilogo_836_prueba.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	get_tree().current_scene = _escena_anterior
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_anterior


func _esc() -> InputEventAction:
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	return esc


func _restante() -> float:
	var turno: Turno = _almacen.get("_reloj").get("_turno")
	return turno.tiempo_restante()


## El contrato cumplido sin pistas, con la devolución del cierre ya elegida: el epílogo del final 1
## queda en pantalla.
func _hasta_el_epilogo_del_final_1() -> void:
	_almacen = ALMACEN.instantiate()
	_almacen.set(
		"_partida",
		Partida.desde(
			PartidaSerializada.sanear({"jornada": ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA})
		)
	)
	get_tree().root.add_child(_almacen)
	await get_tree().process_frame
	RelojDePrueba.avanzar_turno(_almacen.get("_reloj"), Reglas.DURACION_DEL_TURNO)
	var devolucion: PantallaDeDevolucion = _almacen.get("_pantalla")
	AvanceDeDevolucion.esperar_el_celular(devolucion)
	AvanceDeDevolucion.entregar(devolucion)
	devolucion.elegir()


func test_el_final_1_pasa_por_sus_seis_placas_antes_de_su_pantalla() -> void:  # AC-SHF-134
	await _hasta_el_epilogo_del_final_1()
	assert_int(AvanceDelEpilogo.cuantos(_almacen)).is_equal(1)
	assert_object(_almacen.get_node_or_null("PantallaDeFinal")).is_null()
	var esperadas := EpilogosDeLosFinales.placas_de(FinalConPantalla.Cual.EMPLEADO_ESTRESADO)
	assert_int(esperadas.size()).is_greater(1)
	var pedidos := [0]
	_almacen.set("_ir_al_menu", func() -> void: pedidos[0] += 1)
	var vistas := AvanceDelEpilogo.recorrer(_almacen)
	assert_int(vistas.size()).is_equal(esperadas.size())
	for indice in range(esperadas.size()):
		assert_str(vistas[indice].texto).is_equal(esperadas[indice].texto)
	var final: PantallaDeFinal = _almacen.get_node("PantallaDeFinal")
	assert_bool(final.visible).is_true()
	assert_str(final.encabezado()).is_equal(
		PantallaDeFinal.ENCABEZADOS[FinalConPantalla.Cual.EMPLEADO_ESTRESADO]
	)
	assert_int(pedidos[0]).is_zero()
	assert_int(AvanceDelEpilogo.cuantos(_almacen)).is_zero()


func test_elegir_dos_veces_la_devolucion_muestra_un_solo_epilogo() -> void:  # AC-SHF-067
	await _hasta_el_epilogo_del_final_1()
	var devolucion: PantallaDeDevolucion = _almacen.get("_pantalla")
	devolucion.elegir()
	assert_int(AvanceDelEpilogo.cuantos(_almacen)).is_equal(1)


func test_durante_el_epilogo_esc_no_pausa_y_el_reloj_no_corre() -> void:  # AC-SHF-139
	await _hasta_el_epilogo_del_final_1()
	var epilogo := AvanceDelEpilogo.de(_almacen)
	assert_bool(epilogo.visible).is_true()
	var pausa: ControlDePausa = _almacen.get_node("Interfaz/ControlDePausa")
	var antes := _restante()
	pausa._input(_esc())
	for _cuadro in 3:
		await get_tree().process_frame
	assert_bool(get_tree().paused).is_false()
	assert_bool((_almacen.get("_jugador") as Node).call("suspendido")).is_true()
	assert_float(_restante()).is_equal(antes)
	epilogo.avanzar(RecorridoDelEpilogo.SEGUNDOS_DEL_FUNDIDO)
	pausa._input(_esc())
	assert_bool(get_tree().paused).is_false()
