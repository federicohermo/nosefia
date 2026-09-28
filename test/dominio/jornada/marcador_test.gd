## Los números del turno formateados: la hora de la noche y el marcador de obligatorias.
##
## El nodo que pinta no formatea nada: si estos casos pasan, el reloj de mesa del local dice la
## verdad. La hora se prueba acá y no mirando el label porque la aritmética de la apertura más lo
## transcurrido es una regla del juego — en `escenas/` habría nacido sin test.
extends GdUnitTestSuite


func test_con_el_turno_entero_se_lee_la_hora_de_apertura() -> void:  # AC-SHF-016
	assert_str(Marcador.hora(43200.0)).is_equal("20:00")


func test_la_hora_pasa_por_la_medianoche_sin_llegar_a_veinticuatro() -> void:  # AC-SHF-016
	# El único cruce del `HH` en la noche, y el que distingue «módulo 24» de «apertura más
	# horas»: sin el módulo, la medianoche se leería `"24:00"`.
	assert_str(Marcador.hora(28801.0)).is_equal("23:59")
	assert_str(Marcador.hora(28799.0)).is_equal("00:00")


func test_la_hora_avanza_a_medida_que_el_turno_se_gasta() -> void:  # AC-SHF-016
	assert_str(Marcador.hora(21600.0)).is_equal("02:00")
	assert_str(Marcador.hora(14400.0)).is_equal("04:00")


func test_un_turno_agotado_se_lee_como_la_hora_de_cierre() -> void:  # AC-SHF-016
	assert_str(Marcador.hora(0.0)).is_equal("08:00")


func test_los_segundos_se_truncan_al_minuto_y_no_se_redondean() -> void:  # AC-SHF-014
	# Con 59 segundos de ficción gastados todavía no pasó un minuto entero: mostrar `20:01` es
	# adelantarle la hora al jugador. Al segundo 60 justo, sí.
	assert_str(Marcador.hora(43141.0)).is_equal("20:00")
	assert_str(Marcador.hora(43140.0)).is_equal("20:01")


func test_un_restante_negativo_nunca_pasa_de_la_hora_de_cierre() -> void:  # AC-SHF-014
	# Un `08:10` en el display es un turno que siguió después de cerrar, y eso no existe.
	assert_str(Marcador.hora(-10.0)).is_equal("08:00")


func test_las_tareas_se_leen_como_cumplidas_sobre_declaradas() -> void:
	assert_str(Marcador.tareas(3, 4)).is_equal("3/4")


func test_la_cantidad_de_obligatorias_entra_por_argumento() -> void:
	# El segundo argumento cambia y el resultado lo sigue: el marcador no sabe cuántas tareas
	# pide el jefe, y por eso una tarea más no lo toca.
	assert_str(Marcador.tareas(0, 5)).is_equal("0/5")
