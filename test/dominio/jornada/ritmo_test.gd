## El factor que convierte un segundo real en segundos de turno.
##
## Los casos no eligen números redondos por comodidad: cada duración real es la sesión que cubre
## el turno entero, así que el test falla el día que alguien rebalancee un ritmo sin recalcular
## cuánto dura jugar esa noche.
extends GdUnitTestSuite

## `jornada → [segundos reales de la noche, segundos de turno por segundo real]`.
const DURACIONES := {
	1: [360.0, 120.0],
	2: [540.0, 80.0],
	3: [600.0, 72.0],
	4: [720.0, 60.0],
	8: [720.0, 60.0],
}


func test_cada_jornada_dura_su_sesion_y_cubre_el_turno_entero() -> void:  # AC-SHF-002
	for jornada: int in DURACIONES:
		var ritmo := Ritmo.de_la_jornada(jornada)
		var fila: Array = DURACIONES[jornada]
		assert_float(ritmo).is_equal(fila[1])
		assert_float(Ritmo.escalar(1.0, ritmo)).is_equal(fila[1])
		assert_float(Ritmo.escalar(fila[0], ritmo)).is_equal(Reglas.DURACION_DEL_TURNO)


func test_una_jornada_sin_fila_corre_a_un_minuto_por_segundo() -> void:  # AC-SHF-002
	assert_float(Ritmo.escalar(1.0, Ritmo.de_la_jornada(0))).is_equal(60.0)
	assert_float(Ritmo.escalar(1.0)).is_equal(60.0)


func test_sin_tiempo_real_no_se_consume_nada_del_turno() -> void:
	assert_float(Ritmo.escalar(0.0)).is_equal(0.0)


func test_es_lineal_y_medio_segundo_vale_la_mitad() -> void:
	assert_float(Ritmo.escalar(0.5)).is_equal(30.0)
