## El factor que convierte un segundo de reloj de pared en segundos de turno.
##
## Los casos no eligen números redondos por comodidad: `1200.0` es la sesión de veinte minutos
## reales y `28800.0` el turno de ocho horas de ficción, así que el test falla el día que alguien
## rebalancee el factor sin recalcular cuánto dura jugar una noche.
extends GdUnitTestSuite


func test_un_segundo_real_vale_veinticuatro_segundos_de_turno() -> void:
	assert_float(Ritmo.escalar(1.0)).is_equal(24.0)


func test_sin_tiempo_real_no_se_consume_nada_del_turno() -> void:
	assert_float(Ritmo.escalar(0.0)).is_equal(0.0)


func test_es_lineal_y_medio_segundo_vale_la_mitad() -> void:
	assert_float(Ritmo.escalar(0.5)).is_equal(12.0)


func test_una_sesion_de_veinte_minutos_reales_cubre_el_turno_entero() -> void:
	# Es la aritmética de la que sale el factor, no una consecuencia de él: si deja de dar
	# `DURACION_DEL_TURNO`, la noche termina antes o después de que se acabe la sesión.
	assert_float(Ritmo.escalar(1200.0)).is_equal(Reglas.DURACION_DEL_TURNO)
