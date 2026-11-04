## Qué piensa el protagonista al hacer clic sobre la computadora o la caja registradora mientras el
## corte de luz está cortado, y que los aparatos no se abran por eso. Qué quiere decir «hay luz» lo
## prueba el dominio del corte; acá, que el almacén lo traduzca en un pensamiento.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const ESCRITORIO := "Estructura/base compu/StaticBody3D"
const TABLERO := "Estructura/tableroluz/StaticBody3D"
const S := SubtitulosDeLosGestos.Id


func after_test() -> void:
	get_tree().paused = false


func _local() -> Node3D:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	local.set(
		"_partida", Partida.desde({"jornada": AnomaliasDeLaJornada.JORNADA_DEL_CORTE, "medios": 0})
	)
	add_child(local)
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	return local


func _cortar(local: Node3D) -> void:
	var hora := Vector2i(AnomaliasDeLaJornada.HORA_DEL_CORTE, AnomaliasDeLaJornada.MINUTO_DEL_CORTE)
	RelojDePrueba.avanzar_hasta(local.get("_reloj"), hora)


func _linea(local: Node3D) -> String:
	return (local.get("_hud").get("_subtitulo") as Label).text


func _computadora_abierta(local: Node3D) -> bool:
	return (local.get("_computadora") as ComputadoraDeEscritorio).computadora().abierta()


func _aparatos(local: Node3D) -> Array[Node3D]:
	var aparatos: Array[Node3D] = [local.get_node(ESCRITORIO), local.get("_puesto_de_la_caja")]
	return aparatos


func _abierto(aparato: Node3D, local: Node3D) -> bool:
	if aparato == local.get("_puesto_de_la_caja"):
		return aparato.get("_abierta")
	return _computadora_abierta(local)


func test_sin_luz_el_clic_sobre_cada_aparato_piensa_y_no_lo_abre() -> void:  # AC-SUB-032
	var local := _local()
	_cortar(local)
	for aparato in _aparatos(local):
		assert_str(_linea(local)).is_empty()
		aparato.accionar()
		assert_str(_linea(local)).is_equal(SubtitulosDeLosGestos.texto(S.SIN_LUZ))
		assert_bool(_abierto(aparato, local)).is_false()
		(local.get("_hud") as Hud).call("_process", 1000.0)
		assert_str(_linea(local)).is_empty()


func test_el_pensamiento_sin_luz_tiene_dos_renglones() -> void:  # AC-SUB-032
	assert_array(SubtitulosDeLosGestos.texto(S.SIN_LUZ).split("\n")).has_size(2)


func test_repetir_el_clic_deja_una_sola_linea_que_empieza_de_nuevo() -> void:  # AC-SUB-032
	var local := _local()
	_cortar(local)
	var texto := SubtitulosDeLosGestos.texto(S.SIN_LUZ)
	var hud: Hud = local.get("_hud")
	var escritorio: Node3D = local.get_node(ESCRITORIO)
	escritorio.accionar()
	hud.call("_process", Subtitulo.duracion(texto) + Subtitulo.DESVANECIDO / 2.0)
	assert_float((hud.get("_subtitulo") as Label).modulate.a).is_less(1.0)
	escritorio.accionar()
	assert_str(_linea(local)).is_equal(texto)
	assert_float((hud.get("_subtitulo") as Label).modulate.a).is_equal(1.0)


func test_con_luz_el_clic_abre_y_no_piensa() -> void:  # AC-SUB-032
	var local := _local()
	for aparato in _aparatos(local):
		aparato.accionar()
		assert_bool(_abierto(aparato, local)).is_true()
		assert_str(_linea(local)).is_empty()
		aparato.cerrar()


func test_restaurada_la_luz_el_clic_abre_y_no_piensa() -> void:  # AC-SUB-032
	var local := _local()
	_cortar(local)
	local.get_node(TABLERO).accionar()
	for aparato in _aparatos(local):
		aparato.accionar()
		assert_bool(_abierto(aparato, local)).is_true()
		assert_str(_linea(local)).is_empty()
		aparato.cerrar()


func test_cortarse_con_la_computadora_abierta_la_cierra_sin_pensar() -> void:  # AC-SUB-032
	var local := _local()
	local.get_node(ESCRITORIO).accionar()
	assert_bool(_computadora_abierta(local)).is_true()
	_cortar(local)
	assert_bool(_computadora_abierta(local)).is_false()
	assert_str(_linea(local)).is_empty()
