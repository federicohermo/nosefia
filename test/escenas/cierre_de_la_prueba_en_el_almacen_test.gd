extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const GUION := preload("res://src/dominio/investigacion/conversacion_con_el_jefe.tres")
const PRIMERA := ReglasDeLaPartida.PRIMERA_JORNADA
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA

var _ruta_anterior: String
var _abierto: Node3D


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = create_temp_dir("cierre_de_la_prueba").path_join("partida.guardado")


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_abierto):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _abierto.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_abierto.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_abierto = null
	Guardado.ruta_por_defecto = _ruta_anterior


func _almacen(jornada: int, medios: int = 0) -> Node3D:
	var almacen: Node3D = load(ESCENA_DEL_ALMACEN).instantiate()
	almacen.set("_partida", Partida.desde({"jornada": jornada, "medios": medios}))
	add_child(almacen)
	_abierto = almacen
	await get_tree().process_frame
	return almacen


func _cerrar_el_turno(almacen: Node3D) -> void:
	RelojDePrueba.avanzar_turno(
		almacen.get_node("Servicios/RelojDelTurno"), Reglas.DURACION_DEL_TURNO
	)


func _persiana(almacen: Node3D) -> PersianaDeLaNoche:
	return almacen.get_node("Interfaz/PersianaDeLaNoche")


func _instrucciones(almacen: Node3D) -> PantallaDeInstrucciones:
	return almacen.get_node("Interfaz/PantallaDeInstrucciones")


func _celular(almacen: Node3D) -> CelularDelEmpleado:
	return almacen.get_node("Interfaz/CelularDelEmpleado")


func _esc(almacen: Node3D) -> void:
	var evento := InputEventAction.new()
	evento.action = &"ui_cancel"
	evento.pressed = true
	(almacen.get_node("Interfaz/ControlDePausa") as ControlDePausa)._input(evento)


func _sin_celular(almacen: Node3D) -> void:
	assert_bool((almacen.get("_pantalla") as PantallaDeDevolucion).visible).is_false()
	assert_bool(_celular(almacen).celular().abierto()).is_false()


func _cerrar_sin_celular(jornada: int) -> int:
	var almacen: Node3D = await _almacen(jornada)
	_cerrar_el_turno(almacen)
	assert_bool(_persiana(almacen).en_pantalla()).is_true()
	assert_bool((almacen.get("_jugador") as Node).call("suspendido")).is_true()
	assert_bool(_instrucciones(almacen).visible).is_false()
	_sin_celular(almacen)
	AvanceDeDevolucion.terminar_la_bajada(_persiana(almacen))
	assert_bool(await AvanceDeDevolucion.esperar_la_noche_siguiente(almacen)).is_true()
	var partida: Partida = almacen.get("_partida")
	assert_int(partida.jornada()).is_equal(jornada + 1)
	_sin_celular(almacen)
	assert_bool(_instrucciones(almacen).visible).is_true()
	assert_bool(_persiana(almacen).en_pantalla()).is_true()
	assert_bool((_persiana(almacen).get("_placa") as Label).visible).is_false()
	var propias := InstruccionesDelJefe.de_la_jornada(
		GUION.mensajes, jornada + 1, CondicionesDelJefe.elegidas(partida.noches_de_prueba)
	)
	var pasos := InstruccionesDelJefe.pasos_de(propias)
	assert_str((_instrucciones(almacen).get("_contador") as Label).text).is_equal(
		"1/%d" % pasos.size()
	)
	(
		assert_str(
			(
				((_instrucciones(almacen).get("_pasos") as Array)[0] as InstruccionesDelJefe.Paso)
				. textos[0]
				. identidad
			)
		)
		. is_equal(pasos[0].textos[0].identidad)
	)
	var guardada := Partida.desde(Guardado.new().cargar()).jornada()
	AvanceDeDevolucion.leer_las_instrucciones(almacen)
	assert_int(_persiana(almacen).get("_jornada")).is_equal(jornada + 1)
	assert_bool((_persiana(almacen).get("_placa") as Label).visible).is_true()
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in almacen.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	almacen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var retomado: Node3D = load(ESCENA_DEL_ALMACEN).instantiate()
	_abierto = retomado
	add_child(retomado)
	retomado.call("retomar_la_partida")
	var partida_retomada: Partida = retomado.get("_partida")
	assert_int(partida_retomada.jornada()).is_equal(jornada + 1)
	assert_bool(_instrucciones(retomado).visible).is_true()
	assert_str((_instrucciones(retomado).get("_contador") as Label).text).is_equal(
		"1/%d" % pasos.size()
	)
	var pasos_retomados: Array = _instrucciones(retomado).get("_pasos")
	assert_str((pasos_retomados[0] as InstruccionesDelJefe.Paso).textos[0].identidad).is_equal(
		pasos[0].textos[0].identidad
	)
	assert_bool((retomado.get("_jugador") as Node).call("suspendido")).is_true()
	var reloj: RelojDelTurno = retomado.get("_reloj")
	assert_float((reloj.get("_turno") as Turno).tiempo_restante()).is_equal(
		Reglas.DURACION_DEL_TURNO
	)
	_sin_celular(retomado)
	return guardada


func test_la_primera_noche_cierra_sin_celular_y_sigue_la_segunda() -> void:  # AC-EMP-093
	assert_int(await _cerrar_sin_celular(PRIMERA)).is_equal(PRIMERA + 1)


func test_la_segunda_noche_cierra_sin_celular_y_sigue_la_tercera() -> void:  # AC-EMP-093
	assert_int(await _cerrar_sin_celular(PRIMERA + 1)).is_equal(PRIMERA + 2)


func test_la_tercera_noche_cierra_sin_celular_y_sigue_la_cuarta() -> void:  # AC-EMP-093
	assert_int(await _cerrar_sin_celular(COMPLETA - 1)).is_equal(COMPLETA)


func test_pausar_con_la_persiana_bajando_no_sube_el_celular() -> void:  # AC-EMP-094
	var almacen: Node3D = await _almacen(PRIMERA)
	_cerrar_el_turno(almacen)
	var persiana := _persiana(almacen)
	var lectura: Callable = persiana.get("_ahora")
	var ahora := [int(persiana.get("_ultimo"))]
	persiana.set("_ahora", func() -> int: return ahora[0])
	ahora[0] += 250000
	persiana.call("_process", 0.0)
	var antes: float = persiana.get("_avance_de_la_bajada")
	assert_float(antes).is_greater(0.0)
	_esc(almacen)
	assert_bool(get_tree().paused).is_true()
	ahora[0] += 3000000
	for _cuadro in 4:
		await get_tree().process_frame
	assert_float(persiana.get("_avance_de_la_bajada")).is_equal(antes)
	assert_bool(_instrucciones(almacen).visible).is_false()
	_sin_celular(almacen)
	_esc(almacen)
	assert_bool(get_tree().paused).is_false()
	persiana.call("_process", 0.0)
	assert_float(persiana.get("_avance_de_la_bajada")).is_equal(antes)
	ahora[0] += 250000
	persiana.call("_process", 0.0)
	var reanudada: float = persiana.get("_avance_de_la_bajada")
	assert_float(reanudada).is_greater(antes).is_less(1.0)
	assert_bool(_instrucciones(almacen).visible).is_false()
	persiana.set("_ahora", lectura)
	AvanceDeDevolucion.terminar_la_bajada(persiana)
	assert_bool(await AvanceDeDevolucion.esperar_la_noche_siguiente(almacen)).is_true()
	assert_bool(_instrucciones(almacen).visible).is_true()
	_sin_celular(almacen)


func test_pausar_con_la_persiana_baja_no_repite_las_instrucciones() -> void:  # AC-EMP-094
	var almacen: Node3D = await _almacen(PRIMERA)
	_cerrar_el_turno(almacen)
	AvanceDeDevolucion.terminar_la_bajada(_persiana(almacen))
	assert_bool(await AvanceDeDevolucion.esperar_la_noche_siguiente(almacen)).is_true()
	(_instrucciones(almacen).get("_siguiente") as Button).pressed.emit()
	_esc(almacen)
	for _cuadro in 4:
		await get_tree().process_frame
	_esc(almacen)
	var lectura: InstruccionesDelJefe = _instrucciones(almacen).get("_instrucciones")
	assert_int(lectura.paso_actual()).is_equal(2)
	_sin_celular(almacen)


func test_con_la_prueba_perdida_el_despido_es_el_unico_mensaje_de_la_cuarta() -> void:  # AC-EMP-090
	var almacen: Node3D = await _almacen(COMPLETA - 1, 2 * Reglas.MEDIOS_POR_APERCIBIMIENTO)
	var menus := [0]
	almacen.set("_ir_al_menu", func() -> void: menus[0] += 1)
	var aperturas := [0]
	(almacen.get_node("Servicios/CicloDeJornadas") as CicloDeJornadas).jornada_abierta.connect(
		func(_jornada: int) -> void: aperturas[0] += 1
	)
	_cerrar_el_turno(almacen)
	var partida: Partida = almacen.get("_partida")
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)
	_sin_celular(almacen)
	assert_bool(_instrucciones(almacen).visible).is_false()
	AvanceDeDevolucion.terminar_la_bajada(_persiana(almacen))
	for _cuadro in 2:
		await get_tree().process_frame
	_sin_celular(almacen)
	assert_bool(_instrucciones(almacen).visible).is_true()
	var pasos: Array = _instrucciones(almacen).get("_pasos")
	assert_int(pasos.size()).is_equal(1)
	assert_str((pasos[0] as InstruccionesDelJefe.Paso).textos[0].texto).is_equal(
		DevolucionDelJefe.DESPIDO_DE_LA_PRUEBA
	)
	assert_str((_instrucciones(almacen).get("_contador") as Label).text).is_equal("1/1")
	var comenzar: Button = _instrucciones(almacen).get("_siguiente")
	comenzar.pressed.emit()
	comenzar.pressed.emit()
	assert_int(menus[0]).is_equal(1)
	assert_int(aperturas[0]).is_zero()
	assert_int(partida.jornada()).is_equal(COMPLETA - 1)
	assert_bool((_persiana(almacen).get("_placa") as Label).visible).is_false()
