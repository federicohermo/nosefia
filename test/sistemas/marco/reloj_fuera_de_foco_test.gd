extends GdUnitTestSuite


class RelojConTiempo:
	extends RelojDelTurno
	var ahora_usec: int = 1000000

	func _ahora_usec() -> int:
		return ahora_usec


var _turno: Turno


func after_test() -> void:
	get_tree().paused = false


func _reloj(segundos_reales: float) -> RelojConTiempo:
	var reloj: RelojConTiempo = auto_free(RelojConTiempo.new())
	reloj.set_process(false)
	add_child(reloj)
	_turno = Turno.new(Ritmo.escalar(segundos_reales), [])
	reloj.arrancar(_turno, [])
	return reloj


func test_diez_segundos_sin_cuadros_se_descuentan_sin_duplicarse() -> void:  # AC-SHF-021
	var reloj := _reloj(20.0)
	reloj.ahora_usec += 10000000
	reloj._process(0.0)
	assert_float(_turno.tiempo_restante()).is_equal_approx(Ritmo.escalar(10.0), 0.001)
	reloj.ahora_usec += 250000
	reloj._process(0.25)
	assert_float(_turno.tiempo_restante()).is_equal_approx(Ritmo.escalar(9.75), 0.001)


func test_la_pausa_manual_excluye_la_ausencia_y_reanuda_el_reloj() -> void:  # AC-SHF-021
	var reloj := _reloj(20.0)
	get_tree().paused = true
	reloj.ahora_usec += 10000000
	get_tree().paused = false
	reloj.ahora_usec += 500000
	reloj._process(0.0)
	assert_float(_turno.tiempo_restante()).is_equal_approx(Ritmo.escalar(19.5), 0.001)


func test_una_ausencia_larga_cierra_una_sola_vez() -> void:  # AC-SHF-021
	var reloj := _reloj(5.0)
	var cierres: Array[int] = []
	reloj.turno_cerrado.connect(func(cumplidas: int) -> void: cierres.append(cumplidas))
	reloj.ahora_usec += 10000000
	reloj._process(0.0)
	reloj.ahora_usec += 1000000
	reloj._process(0.0)
	assert_bool(_turno.cerrado()).is_true()
	assert_float(_turno.tiempo_restante()).is_zero()
	assert_array(cierres).has_size(1)
