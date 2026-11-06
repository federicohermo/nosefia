## Lo que el reloj contesta sobre su turno sin que nadie lo avance: cuánto queda y a qué ritmo.
extends GdUnitTestSuite


func test_sin_turno_no_queda_tiempo() -> void:
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	assert_float(reloj.tiempo_restante()).is_equal(0.0)


func test_el_tiempo_restante_baja_con_lo_que_se_avanza() -> void:
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var ritmo := 2.0
	reloj.arrancar(Turno.new(100.0, [] as Array[Tarea]), [] as Array[Tarea], ritmo)
	assert_float(reloj.tiempo_restante()).is_equal(100.0)
	reloj.avanzar(10.0)
	assert_float(reloj.tiempo_restante()).is_equal(100.0 - 10.0 * ritmo)


func test_el_ritmo_es_el_que_recibio_al_arrancar() -> void:
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(Turno.new(100.0, [] as Array[Tarea]), [] as Array[Tarea], 3.0)
	assert_float(reloj.ritmo()).is_equal(3.0)
