## El corte de luz de la séptima noche, en el local de verdad: la luz, las interfaces, el tablero y
## el reloj de mesa. Cuándo se corta y qué quiere decir «hay luz» lo prueba el dominio; acá se
## prueba que el local lo cumpla.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const GRUPO_DE_LA_EMERGENCIA := &"luz_de_emergencia"
const ESCRITORIO := "Estructura/base compu/StaticBody3D"
const TABLERO := "Estructura/tableroluz/StaticBody3D"
const HORNO_CON_LUZ := "res://src/escenas/almacen.lmbake"
const LIGHTMAP_CON_LUZ := "res://src/escenas/almacen.exr"
const LIGHTMAP_SIN_LUZ := "res://src/escenas/almacen_sin_luz.exr"
## Lado de la primera capa del atlas, la de la luz: las otras guardan la dirección.
const LADO_DEL_ATLAS := 2048
const PASO_DEL_MUESTREO := 4
const LUZ_VISIBLE := 0.01
## Qué parte, como mínimo, del local con luz queda visible en la penumbra: el piso, las góndolas y
## las paredes de al lado de los ventanales.
const PENUMBRA_MINIMA := 0.1

var _con_luz: LightmapGIData


func before_test() -> void:
	_con_luz = load(HORNO_CON_LUZ)


func after_test() -> void:
	get_tree().paused = false


func _local(jornada: int = AnomaliasDeLaJornada.JORNADA_DEL_CORTE) -> Node3D:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	local.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	add_child(local)
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	return local


func _hasta_el_corte(local: Node3D, minutos_de_diferencia: int = 0) -> void:
	var hora := Vector2i(AnomaliasDeLaJornada.HORA_DEL_CORTE, AnomaliasDeLaJornada.MINUTO_DEL_CORTE)
	RelojDePrueba.avanzar_hasta(local.get("_reloj"), hora + Vector2i(0, minutos_de_diferencia))


func _hay_luz(local: Node3D) -> bool:
	var horno: LightmapGI = local.get_node("LightmapGI")
	return horno.light_data == _con_luz


func _luces_normales_encendidas(local: Node3D) -> Array[bool]:
	var encendidas: Array[bool] = []
	for luz: Light3D in local.find_children("*", "Light3D", true, false):
		if not luz.is_in_group(GRUPO_DE_LA_EMERGENCIA):
			encendidas.append(luz.is_visible_in_tree())
	return encendidas


func _luz_de_emergencia(local: Node3D) -> Light3D:
	var luces := local.get_tree().get_nodes_in_group(GRUPO_DE_LA_EMERGENCIA)
	assert_array(luces).has_size(1)
	return luces[0] as Light3D


func _computadora_abierta(local: Node3D) -> bool:
	var computadora: ComputadoraDeEscritorio = local.get("_computadora")
	return computadora.computadora().abierta()


func _lectura_del_reloj(local: Node3D) -> String:
	return (local.get("_reloj_de_mesa") as Label3D).text


func _detenida() -> String:
	return (
		"%02d:%02d" % [AnomaliasDeLaJornada.HORA_DEL_CORTE, AnomaliasDeLaJornada.MINUTO_DEL_CORTE]
	)


func _restante(local: Node3D) -> float:
	return (local.get("_reloj")._turno as Turno).tiempo_restante()


func test_antes_de_la_hora_la_noche_tiene_luz_y_reloj_normales() -> void:  # AC-ANO-015, AC-AMB-028
	var local := _local()
	_hasta_el_corte(local, -1)
	assert_bool(_hay_luz(local)).is_true()
	assert_array(_luces_normales_encendidas(local)).is_not_empty().not_contains(false)
	assert_str(_lectura_del_reloj(local)).is_not_equal(_detenida())


func test_a_la_hora_del_corte_queda_solo_la_luz_de_emergencia() -> void:  # AC-AMB-028
	var local := _local()
	_hasta_el_corte(local)
	assert_bool(_hay_luz(local)).is_false()
	assert_array(_luces_normales_encendidas(local)).not_contains(true)
	assert_bool(_luz_de_emergencia(local).is_visible_in_tree()).is_true()


func test_el_corte_se_da_una_sola_vez() -> void:  # AC-ANO-016
	var local := _local()
	_hasta_el_corte(local)
	var horno: LightmapGI = local.get_node("LightmapGI")
	var oscuro := horno.light_data
	RelojDePrueba.avanzar_turno(local.get("_reloj"), 60.0)
	assert_object(horno.light_data).is_same(oscuro)
	local.get_node(TABLERO).accionar()
	RelojDePrueba.avanzar_turno(local.get("_reloj"), 60.0)
	assert_bool(_hay_luz(local)).is_true()


func test_las_otras_noches_no_se_cortan() -> void:  # AC-ANO-015
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	for jornada in range(primera, primera + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		if jornada == AnomaliasDeLaJornada.JORNADA_DEL_CORTE:
			continue
		var local := _local(jornada)
		_hasta_el_corte(local, 5)
		assert_bool(_hay_luz(local)).is_true()
		local.queue_free()
		await get_tree().process_frame


func test_sin_luz_la_computadora_y_la_caja_no_abren() -> void:  # AC-ANO-017
	var local := _local()
	_hasta_el_corte(local)
	local.get_node(ESCRITORIO).accionar()
	assert_bool(_computadora_abierta(local)).is_false()
	var puesto: Node3D = local.get("_puesto_de_la_caja")
	puesto.accionar()
	assert_bool(puesto.get("_abierta")).is_false()


func test_una_interfaz_abierta_al_cortarse_se_cierra() -> void:  # AC-ANO-017
	var local := _local()
	_hasta_el_corte(local, -1)
	local.get_node(ESCRITORIO).accionar()
	assert_bool(_computadora_abierta(local)).is_true()
	_hasta_el_corte(local)
	assert_bool(_computadora_abierta(local)).is_false()


func test_con_luz_o_restaurada_las_interfaces_abren() -> void:  # AC-ANO-017
	var local := _local()
	local.get_node(ESCRITORIO).accionar()
	assert_bool(_computadora_abierta(local)).is_true()
	local.get_node(ESCRITORIO).cerrar()
	_hasta_el_corte(local)
	local.get_node(TABLERO).accionar()
	local.get_node(ESCRITORIO).accionar()
	assert_bool(_computadora_abierta(local)).is_true()


func test_el_tablero_restablece_la_luz_y_las_interfaces() -> void:  # AC-ANO-018, AC-AMB-028
	var local := _local()
	_hasta_el_corte(local)
	local.get_node(TABLERO).accionar()
	assert_bool(_hay_luz(local)).is_true()
	assert_array(_luces_normales_encendidas(local)).not_contains(false)
	local.get_node(TABLERO).accionar()
	assert_bool(_hay_luz(local)).is_true()


func test_pulsar_el_tablero_sin_corte_no_cambia_nada() -> void:  # AC-ANO-018
	var local := _local()
	local.get_node(TABLERO).accionar()
	assert_bool(_hay_luz(local)).is_true()
	_hasta_el_corte(local)
	assert_bool(_hay_luz(local)).is_false()


func test_el_reloj_queda_detenido_hasta_el_cierre() -> void:  # AC-SHF-049, AC-SHF-050
	var local := _local()
	var reloj: RelojDelTurno = local.get("_reloj")
	_hasta_el_corte(local)
	assert_str(_lectura_del_reloj(local)).is_equal(_detenida())
	RelojDePrueba.avanzar_turno(reloj, 3600.0)
	assert_str(_lectura_del_reloj(local)).is_equal(_detenida())
	local.get_node(TABLERO).accionar()
	local.get_node(TABLERO).accionar()
	RelojDePrueba.avanzar_turno(reloj, 3600.0)
	assert_str(_lectura_del_reloj(local)).is_equal(_detenida())
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	assert_bool(reloj.corriendo()).is_false()
	assert_str(_lectura_del_reloj(local)).is_equal(_detenida())


func test_la_jornada_siguiente_lee_la_hora() -> void:  # AC-SHF-049
	var local := _local(AnomaliasDeLaJornada.JORNADA_DEL_CORTE + 1)
	RelojDePrueba.avanzar_hasta(local.get("_reloj"), Vector2i(23, 0))
	assert_str(_lectura_del_reloj(local)).is_equal(Marcador.hora(_restante(local)))


func test_el_turno_descuenta_igual_durante_el_corte_y_despues() -> void:  # AC-ANO-019
	var local := _local()
	var reloj: RelojDelTurno = local.get("_reloj")
	_hasta_el_corte(local)
	var antes := _restante(local)
	RelojDePrueba.avanzar_turno(reloj, 600.0)
	assert_float(_restante(local)).is_equal(antes - 600.0)
	local.get_node(TABLERO).accionar()
	RelojDePrueba.avanzar_turno(reloj, 600.0)
	assert_float(_restante(local)).is_equal(antes - 1200.0)
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	assert_bool(reloj.corriendo()).is_false()


func test_pausar_y_reanudar_conserva_el_estado_y_no_consume_turno() -> void:  # AC-ANO-020
	var local := _local()
	local.get("_reloj").set_process(true)
	_hasta_el_corte(local)
	var restante := _restante(local)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_hay_luz(local)).is_false()
	assert_float(_restante(local)).is_equal(restante)
	get_tree().paused = false
	assert_bool(_hay_luz(local)).is_false()
	local.get_node(TABLERO).accionar()
	get_tree().paused = true
	await get_tree().process_frame
	assert_bool(_hay_luz(local)).is_true()
	assert_float(_restante(local)).is_equal(restante)


func test_abrir_la_noche_otra_vez_parte_con_luz_y_sin_guardado() -> void:  # AC-ANO-020
	var local := _local()
	_hasta_el_corte(local)
	assert_bool(_hay_luz(local)).is_false()
	assert_bool(Guardado.new().hay_guardado()).is_false()
	var otra := _local()
	assert_bool(_hay_luz(otra)).is_true()
	assert_str(_lectura_del_reloj(otra)).is_not_equal(_detenida())


## La penumbra de la noche del corte: el horneado oscuro no es negro, pero tampoco es el del local
## con luz. Se mide en la capa de luz del atlas, que es la que se ve en pantalla.
func test_el_horneado_del_corte_deja_en_penumbra_mas_que_el_tablero() -> void:  # AC-AMB-028
	var con_luz := _texeles_con_luz(LIGHTMAP_CON_LUZ)
	var sin_luz := _texeles_con_luz(LIGHTMAP_SIN_LUZ)
	assert_float(con_luz).is_greater(0.0)
	assert_float(sin_luz).is_greater(con_luz * PENUMBRA_MINIMA)
	assert_float(sin_luz).is_less(con_luz)


func _texeles_con_luz(ruta: String) -> float:
	var capa := Image.load_from_file(ruta).get_region(Rect2i(0, 0, LADO_DEL_ATLAS, LADO_DEL_ATLAS))
	var con_luz := 0
	var total := 0
	for y: int in range(0, LADO_DEL_ATLAS, PASO_DEL_MUESTREO):
		for x: int in range(0, LADO_DEL_ATLAS, PASO_DEL_MUESTREO):
			var color := capa.get_pixel(x, y)
			total += 1
			if (color.r + color.g + color.b) / 3.0 > LUZ_VISIBLE:
				con_luz += 1
	return float(con_luz) / total
