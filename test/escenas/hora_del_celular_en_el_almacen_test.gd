## La hora del celular, en el local de verdad: sigue al turno, no se detiene con el reloj de pared y
## entre jornadas queda en la hora de cierre. Qué hora es lo prueba el marcador; acá, el cableado.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const TABLERO := "Estructura/tableroluz/StaticBody3D"


func after_test() -> void:
	get_tree().paused = false


func _local(jornada: int, con_reloj_vivo: bool = false) -> Node3D:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	local.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	add_child(local)
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(con_reloj_vivo)
	return local


func _celular(local: Node3D) -> String:
	var pantalla: PantallaDelCelular = local.get("_pantalla_del_celular")
	return (pantalla.find_child("Hora", true, false) as Label).text


func _pared(local: Node3D) -> String:
	return (local.get("_reloj_de_mesa") as Label3D).text


func _restante(local: Node3D) -> float:
	return (local.get("_reloj")._turno as Turno).tiempo_restante()


func _jornada_libre() -> int:
	return AnomaliasDeLaJornada.JORNADA_DEL_CORTE + 1


func test_el_celular_lee_lo_mismo_que_el_reloj_fuera_de_la_noche_del_corte() -> void:  # AC-SHF-120
	var local := _local(_jornada_libre())
	var reloj: RelojDelTurno = local.get("_reloj")
	var leidas: Array[String] = []
	for hora: Vector2i in [Vector2i(23, 59), Vector2i(0, 0), Vector2i(4, 0)]:
		RelojDePrueba.avanzar_hasta(reloj, hora)
		assert_str(_celular(local)).is_equal(Marcador.hora(_restante(local)))
		assert_str(_celular(local)).is_equal(_pared(local))
		leidas.append(_celular(local))
	assert_array(leidas).has_size(3)
	assert_bool(leidas[0] != leidas[1] and leidas[1] != leidas[2]).is_true()


func test_el_celular_trunca_al_minuto_como_el_reloj() -> void:  # AC-SHF-120
	var local := _local(_jornada_libre())
	var reloj: RelojDelTurno = local.get("_reloj")
	RelojDePrueba.avanzar_turno(reloj, float(Marcador.SEGUNDOS_POR_MINUTO) - 1.0)
	var antes := _celular(local)
	assert_str(antes).is_equal(Marcador.hora(Reglas.DURACION_DEL_TURNO))
	RelojDePrueba.avanzar_turno(reloj, 1.0)
	assert_str(_celular(local)).is_not_equal(antes)
	assert_str(_celular(local)).is_equal(_pared(local))


func test_la_noche_del_corte_el_celular_sigue_andando_con_el_reloj_detenido() -> void:  # AC-SHF-121
	var local := _local(AnomaliasDeLaJornada.JORNADA_DEL_CORTE)
	var reloj: RelojDelTurno = local.get("_reloj")
	var corte := Vector2i(
		AnomaliasDeLaJornada.HORA_DEL_CORTE, AnomaliasDeLaJornada.MINUTO_DEL_CORTE
	)
	RelojDePrueba.avanzar_hasta(reloj, corte)
	assert_str(_celular(local)).is_equal(_pared(local))
	var detenida := _pared(local)
	for hora: Vector2i in [Vector2i(22, 0), Vector2i(1, 0), Vector2i(4, 0)]:
		RelojDePrueba.avanzar_hasta(reloj, hora)
		assert_str(_pared(local)).is_equal(detenida)
		assert_str(_celular(local)).is_equal(Marcador.hora(_restante(local)))
		assert_str(_celular(local)).is_not_equal(detenida)


func test_restaurar_la_luz_no_detiene_el_celular() -> void:  # AC-SHF-121
	var local := _local(AnomaliasDeLaJornada.JORNADA_DEL_CORTE)
	var reloj: RelojDelTurno = local.get("_reloj")
	var corte := Vector2i(
		AnomaliasDeLaJornada.HORA_DEL_CORTE, AnomaliasDeLaJornada.MINUTO_DEL_CORTE
	)
	RelojDePrueba.avanzar_hasta(reloj, corte)
	local.get_node(TABLERO).accionar()
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(22, 0))
	assert_str(_celular(local)).is_equal(Marcador.hora(_restante(local)))
	assert_str(_celular(local)).is_not_equal(_pared(local))


func test_en_pausa_la_hora_del_celular_no_cambia() -> void:  # AC-SHF-122
	var local := _local(_jornada_libre(), true)
	await get_tree().process_frame
	RelojDePrueba.avanzar_turno(local.get("_reloj"), 600.0)
	var restante := _restante(local)
	var leida := _celular(local)
	assert_str(leida).is_equal(Marcador.hora(restante))
	(local.get_node("Interfaz/ControlDePausa") as ControlDePausa).pausar()
	assert_bool(get_tree().paused).is_true()
	for _cuadro in 10:
		await get_tree().process_frame
	assert_float(_restante(local)).is_equal(restante)
	assert_str(_celular(local)).is_equal(leida)


func test_con_el_turno_cerrado_el_celular_lee_la_hora_de_cierre() -> void:  # AC-SHF-123
	for jornada: int in [_jornada_libre(), AnomaliasDeLaJornada.JORNADA_DEL_CORTE]:
		var local := _local(jornada)
		var reloj: RelojDelTurno = local.get("_reloj")
		RelojDePrueba.avanzar_hasta(reloj, Vector2i(1, 0))
		RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
		assert_bool(reloj.corriendo()).is_false()
		assert_str(_celular(local)).is_equal(Marcador.hora(0.0))


func test_cerrar_antes_deja_la_hora_de_cierre_y_no_la_de_la_salida() -> void:  # AC-SHF-123
	var local := _local(_jornada_libre())
	var reloj: RelojDelTurno = local.get("_reloj")
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(1, 0))
	assert_str(_celular(local)).is_not_equal(Marcador.hora(0.0))
	reloj.terminar()
	assert_bool(reloj.corriendo()).is_false()
	assert_str(_celular(local)).is_equal(Marcador.hora(0.0))
