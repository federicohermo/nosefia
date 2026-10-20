extends GdUnitTestSuite


class RelojConTiempo:
	extends RelojDelTurno
	var ahora_usec: int = 1000000

	func _ahora_usec() -> int:
		return ahora_usec


var _turno: Turno
var _inicios := 0
var _cierres := 0
var _consumos := 0


func _reloj(presupuesto: float = 21600.0) -> RelojConTiempo:
	_inicios = 0
	_cierres = 0
	_consumos = 0
	var reloj: RelojConTiempo = auto_free(RelojConTiempo.new())
	_turno = Turno.new(presupuesto, [])
	reloj.arrancar(_turno, [], 120.0)
	reloj.cierre_iniciado.connect(func() -> void: _inicios += 1)
	reloj.turno_cerrado.connect(func(_cumplidas: int) -> void: _cierres += 1)
	reloj.tiempo_consumido.connect(func(_restante: float) -> void: _consumos += 1)
	return reloj


func test_acelerar_no_aplica_el_ritmo_nuevo_al_intervalo_anterior() -> void:  # AC-SHF-031
	var reloj := _reloj()
	reloj.ahora_usec += 1000000
	reloj.acelerar_hasta_el_cierre(10.0)
	assert_int(_consumos).is_zero()
	reloj._process(0.0)
	assert_float(_turno.tiempo_restante()).is_equal_approx(21480.0, 0.001)
	reloj.ahora_usec += 9000000
	reloj._process(0.0)
	assert_bool(_turno.cerrado()).is_false()
	assert_float(_turno.tiempo_restante()).is_equal_approx(2148.0, 0.001)
	reloj.ahora_usec += 1000000
	reloj._process(0.0)
	assert_bool(_turno.cerrado()).is_true()
	assert_int(_inicios).is_equal(1)
	assert_int(_cierres).is_equal(1)


func test_el_pedido_en_una_senal_conserva_su_instante_y_el_primer_ritmo() -> void:  # AC-SHF-034
	var reloj := _reloj()
	reloj.tiempo_consumido.connect(
		func(_restante: float) -> void:
			reloj.ahora_usec += 1000000
			reloj.acelerar_hasta_el_cierre(10.0)
			reloj.acelerar_hasta_el_cierre(5.0)
			assert_int(_consumos).is_equal(1)
			reloj.ahora_usec += 2000000,
		CONNECT_ONE_SHOT
	)
	reloj.ahora_usec += 1000000
	reloj._process(0.0)
	assert_float(_turno.tiempo_restante()).is_equal(21480.0)
	reloj._process(0.0)
	assert_float(_turno.tiempo_restante()).is_equal_approx(17088.0, 0.001)
	reloj.ahora_usec += 7000000
	reloj._process(0.0)
	assert_float(_turno.tiempo_restante()).is_equal_approx(2136.0, 0.001)
	assert_int(_cierres).is_zero()
	reloj.ahora_usec += 1000000
	reloj._process(0.0)
	assert_int(_inicios).is_equal(1)
	assert_int(_cierres).is_equal(1)


func test_pedir_aceleracion_durante_el_inicio_del_cierre_no_reabre() -> void:  # AC-SHF-033
	var reloj := _reloj(120.0)
	reloj.cierre_iniciado.connect(func() -> void: reloj.acelerar_hasta_el_cierre(10.0))
	reloj.ahora_usec += 1000000
	reloj._process(0.0)
	reloj.ahora_usec += 1000000
	reloj._process(0.0)
	assert_float(_turno.tiempo_restante()).is_zero()
	assert_int(_inicios).is_equal(1)
	assert_int(_cierres).is_equal(1)


func test_el_intervalo_anterior_puede_agotar_el_turno_sin_otro_cierre() -> void:  # AC-SHF-033
	var reloj := _reloj(60.0)
	reloj.ahora_usec += 1000000
	reloj.acelerar_hasta_el_cierre(10.0)
	assert_int(_consumos).is_zero()
	reloj._process(0.0)
	reloj.avanzar(10.0)
	assert_float(_turno.tiempo_restante()).is_zero()
	assert_int(_inicios).is_equal(1)
	assert_int(_cierres).is_equal(1)


func test_retener_conserva_el_tramo_previo_y_excluye_la_ausencia() -> void:  # AC-SHF-034
	var reloj := _reloj()
	reloj.ahora_usec += 1000000
	reloj.acelerar_hasta_el_cierre(10.0)
	reloj.retener()
	reloj.ahora_usec += 100000000
	reloj._process(0.0)
	assert_float(_turno.tiempo_restante()).is_equal(21600.0)
	reloj.avanzar(-1.0)
	assert_float(_turno.tiempo_restante()).is_equal(21480.0)
	reloj.avanzar(1.0)
	assert_float(_turno.tiempo_restante()).is_equal(19332.0)
	reloj.soltar()
	reloj.ahora_usec += 8000000
	reloj._process(0.0)
	assert_float(_turno.tiempo_restante()).is_equal(2148.0)
	assert_int(_cierres).is_zero()
	reloj.ahora_usec += 1000000
	reloj._process(0.0)
	assert_int(_cierres).is_equal(1)


func test_pedir_durante_pausa_excluye_la_pausa_y_permite_avance_explicito() -> void:  # AC-SHF-034
	var reloj := _reloj()
	reloj.notification(Node.NOTIFICATION_PAUSED)
	reloj.ahora_usec += 100000000
	reloj.acelerar_hasta_el_cierre(10.0)
	reloj.avanzar(1.0)
	assert_float(_turno.tiempo_restante()).is_equal(19440.0)
	reloj.ahora_usec += 100000000
	reloj.notification(Node.NOTIFICATION_UNPAUSED)
	reloj.ahora_usec += 8000000
	reloj._process(0.0)
	assert_float(_turno.tiempo_restante()).is_equal(2160.0)
	assert_int(_cierres).is_zero()
	reloj.ahora_usec += 1000000
	reloj._process(0.0)
	assert_int(_cierres).is_equal(1)


func test_avanzar_explicito_conserva_el_ancla_automatica() -> void:
	var reloj := _reloj()
	reloj.ahora_usec += 1000000
	reloj.avanzar(1.0)
	assert_float(_turno.tiempo_restante()).is_equal(21480.0)
	reloj._process(0.0)
	assert_float(_turno.tiempo_restante()).is_equal(21360.0)


func test_arrancar_descarta_el_corte_de_la_noche_anterior() -> void:  # AC-SHF-035
	var reloj := _reloj()
	reloj.ahora_usec += 1000000
	reloj.acelerar_hasta_el_cierre(10.0)
	_turno = Turno.new(21600.0, [])
	reloj.arrancar(_turno, [], 120.0)
	reloj.ahora_usec += 1000000
	reloj._process(0.0)
	assert_float(_turno.tiempo_restante()).is_equal(21480.0)
	reloj.acelerar_hasta_el_cierre(10.0)
	reloj.avanzar(9.0)
	assert_float(_turno.tiempo_restante()).is_equal(2148.0)
