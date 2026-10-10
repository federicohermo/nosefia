extends GdUnitTestSuite


class RelojConTiempo:
	extends RelojDelTurno
	var ahora_usec: int = 1000000

	func _ahora_usec() -> int:
		return ahora_usec


func test_retenido_no_cobra_cuadros_ni_ausencia_al_soltar() -> void:  # AC-SHF-023
	var reloj: RelojConTiempo = auto_free(RelojConTiempo.new())
	var turno := Turno.new(Ritmo.escalar(20.0), [])
	reloj.arrancar(turno, [])
	reloj.retener()
	for _cuadro in 4:
		reloj.ahora_usec += 500000
		reloj._process(0.5)
	assert_float(turno.tiempo_restante()).is_equal(Ritmo.escalar(20.0))
	assert_bool(reloj.corriendo()).is_true()
	# El último tramo no entrega cuadros: simula la pestaña oculta antes de soltar.
	reloj.ahora_usec += 8000000
	reloj.soltar()
	reloj.ahora_usec += 1000000
	reloj._process(1.0)
	assert_float(turno.tiempo_restante()).is_equal(Ritmo.escalar(19.0))
	reloj._process(0.0)
	assert_float(turno.tiempo_restante()).is_equal(Ritmo.escalar(19.0))


func test_retener_no_rearma_el_turno_ni_impide_el_avance_explicito() -> void:  # AC-SHF-023
	var reloj: RelojConTiempo = auto_free(RelojConTiempo.new())
	var turno := Turno.new(Ritmo.escalar(20.0), [])
	reloj.arrancar(turno, [])
	reloj.retener()
	reloj.avanzar(3.0)
	assert_float(turno.tiempo_restante()).is_equal(Ritmo.escalar(17.0))
	reloj.retener()
	reloj.soltar()
	reloj.soltar()
	reloj.ahora_usec += 1000000
	reloj._process(1.0)
	assert_float(turno.tiempo_restante()).is_equal(Ritmo.escalar(16.0))
