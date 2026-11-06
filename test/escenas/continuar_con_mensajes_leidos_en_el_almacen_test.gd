## Continuar desde el menú: sólo cuenta como nuevo lo de la jornada que arranca.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA

var _almacen: Node3D
var _ruta_anterior: String


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = create_temp_dir("continuar").path_join("partida.guardado")


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null
	Guardado.ruta_por_defecto = _ruta_anterior


func _bandeja() -> Bandeja:
	return (_almacen.get("_celular") as CelularDelEmpleado).bandeja()


func _de_la_jornada(jornada: int) -> int:
	var cuenta := 0
	for conversacion in _bandeja().conversaciones():
		for mensaje in _bandeja().mensajes_de(conversacion.interlocutor):
			if mensaje.jornada == jornada:
				cuenta += 1
	return cuenta


func test_continuar_deja_leido_lo_de_jornadas_anteriores() -> void:  # AC-INV-230
	var datos := {
		PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA): COMPLETA + 1,
		PartidaSerializada.clave(PartidaSerializada.Campo.DEVOLUCIONES):
		["Hola", "Sin comentarios."],
	}
	assert_bool(Guardado.new().escribir(PartidaSerializada.sanear(datos))).is_true()
	_almacen = ALMACEN.instantiate()
	get_tree().root.add_child(_almacen)
	var avisos: Array[int] = []
	(_almacen.get("_celular") as CelularDelEmpleado).no_leidos_cambiados.connect(
		func(cuenta: int) -> void: avisos.append(cuenta)
	)
	var nuevos := _de_la_jornada(COMPLETA + 1)
	assert_int(nuevos).is_greater(0)
	assert_int(_bandeja().no_leidos_totales()).is_greater(nuevos)
	_almacen.call("retomar_la_partida")
	assert_int(_bandeja().no_leidos_totales()).is_equal(nuevos)
	assert_int(avisos.back()).is_equal(nuevos)
