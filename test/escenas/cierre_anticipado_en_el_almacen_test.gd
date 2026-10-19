## El cableado de la primera noche que termina sola: el almacén pregunta al dominio cada vez que
## una obligatoria se cumple, y el reloj acelera. La noche abre sin compradores para que el ciclo
## de la ventanilla ya esté cerrado y la condición dependa sólo de las obligatorias.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

var _cierres := 0


func before_test() -> void:
	_cierres = 0


func _abrir(jornada: int, con_compradores: bool = false) -> RelojDelTurno:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": jornada}))
	if not con_compradores:
		almacen.set(
			"compradores_de_la_apertura",
			func(_jornada: int) -> Array[Comprador]:
				var nadie: Array[Comprador] = []
				return nadie
		)
	add_child(almacen)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.set_process(false)
	almacen.get("_jugador").set_physics_process(false)
	await get_tree().process_frame
	assert_bool((almacen.get("_atenciones") as Ventanilla).tarea().compras_cerradas()).is_equal(
		not con_compradores
	)
	reloj.turno_cerrado.connect(func(_cumplidas: int) -> void: _cierres += 1)
	return reloj


func _cumplir_lo_que_no_es_cobrar(reloj: RelojDelTurno, jornada: int) -> void:
	for tarea in Apertura.obligatorias(jornada):
		if tarea.tipo() != Tarea.Tipo.CAJA:
			reloj.completar(reloj.obligatoria(tarea.tipo()))


func _restante(reloj: RelojDelTurno) -> float:
	return (reloj.get("_turno") as Turno).tiempo_restante()


func _baja_en(reloj: RelojDelTurno, segundos_reales: float) -> float:
	var antes := _restante(reloj)
	reloj.avanzar(segundos_reales)
	return antes - _restante(reloj)


func test_cumplir_lo_ultimo_acelera_hasta_el_cierre() -> void:  # AC-SHF-031, AC-SHF-032
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var reloj := await _abrir(jornada)
	assert_float(_baja_en(reloj, 1.0)).is_equal(Ritmo.de_la_jornada(jornada))
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(5, 59))
	var cobrar := reloj.obligatoria(Tarea.Tipo.CAJA)
	assert_bool(cobrar.completada()).is_false()
	_cumplir_lo_que_no_es_cobrar(reloj, jornada)
	var duracion := CierreAnticipado.DURACION_DE_LA_ACELERACION
	var restante := _restante(reloj)
	assert_float(_baja_en(reloj, 1.0)).is_equal_approx(restante / duracion, 0.001)
	reloj.avanzar(duracion * 0.5)
	assert_int(_cierres).is_zero()
	reloj.avanzar(duracion)
	assert_float(_restante(reloj)).is_equal(0.0)
	assert_int(_cierres).is_equal(1)
	assert_bool(cobrar.completada()).is_false()


func test_si_nadie_compra_acelera_al_vencer_el_ultimo() -> void:  # AC-SHF-032
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var reloj := await _abrir(jornada, true)
	var reponer := reloj.obligatoria(Tarea.Tipo.REPONER)
	if not reponer.completada():
		reloj.completar(reponer)
	var compradores := Compradores.de_la_jornada(jornada)
	var vencido := [false]
	var atenciones: Ventanilla = reloj.get_parent().get("_atenciones")
	atenciones.comprador_vencido.connect(
		func(comprador: Comprador) -> void:
			if comprador.nombre() == compradores[-1].nombre():
				vencido[0] = true
	)
	assert_float(_baja_en(reloj, 1.0)).is_equal(Ritmo.de_la_jornada(jornada))
	var transcurrido := Reglas.DURACION_DEL_TURNO - _restante(reloj)
	RelojDePrueba.avanzar_turno(reloj, compradores[-1].horario.y - transcurrido - 1.0)
	assert_bool(vencido[0]).is_false()
	RelojDePrueba.avanzar_turno(reloj, 2.0)
	assert_bool(vencido[0]).is_true()
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_false()
	var restante := _restante(reloj)
	var duracion := CierreAnticipado.DURACION_DE_LA_ACELERACION
	assert_float(_baja_en(reloj, 1.0)).is_equal_approx(restante / duracion, 0.001)
	reloj.avanzar(duracion)
	assert_int(_cierres).is_equal(1)
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()


func test_descumplir_despues_de_acelerar_no_frena() -> void:  # AC-SHF-034
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var reloj := await _abrir(jornada)
	_cumplir_lo_que_no_es_cobrar(reloj, jornada)
	var reponer := reloj.obligatoria(Tarea.Tipo.REPONER)
	assert_bool(reloj.descumplir(reponer)).is_true()
	var duracion := CierreAnticipado.DURACION_DE_LA_ACELERACION
	var restante := _restante(reloj)
	assert_float(_baja_en(reloj, 1.0)).is_equal_approx(restante / duracion, 0.001)
	reloj.avanzar(duracion)
	assert_int(_cierres).is_equal(1)
	assert_bool(reponer.completada()).is_false()


func test_las_otras_noches_no_aceleran() -> void:  # AC-SHF-035
	for jornada: int in [
		ReglasDeLaPartida.PRIMERA_JORNADA + 1,
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA,
		ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA,
	]:
		var reloj := await _abrir(jornada)
		_cumplir_lo_que_no_es_cobrar(reloj, jornada)
		(
			assert_float(_baja_en(reloj, 1.0))
			. override_failure_message("jornada %d" % jornada)
			. is_equal(Ritmo.de_la_jornada(jornada))
		)


func test_retomar_la_primera_noche_vuelve_al_ritmo_de_la_jornada() -> void:  # AC-SHF-035
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var reloj := await _abrir(jornada)
	_cumplir_lo_que_no_es_cobrar(reloj, jornada)
	assert_float(_baja_en(reloj, 1.0)).is_greater(Ritmo.de_la_jornada(jornada))
	var retomado := await _abrir(jornada)
	assert_float(_baja_en(retomado, 1.0)).is_equal(Ritmo.de_la_jornada(jornada))
