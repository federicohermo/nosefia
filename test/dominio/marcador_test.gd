## Los números del turno formateados, y el umbral con el que la pantalla cambia de color.
##
## El HUD no formatea nada: si estos casos pasan, el reloj de pantalla dice la verdad. Y el
## umbral se prueba acá y no mirando la pantalla porque es un número que decide — en `ui/`
## habría nacido sin test.
extends GdUnitTestSuite


func test_un_minuto_y_medio_se_lee_como_minutos_y_segundos() -> void:
	assert_str(Marcador.reloj(90.0)).is_equal("01:30")


func test_un_turno_agotado_se_lee_en_cero() -> void:
	assert_str(Marcador.reloj(0.0)).is_equal("00:00")


func test_un_restante_negativo_no_se_muestra_con_signo() -> void:
	# Un `-00:00` en pantalla es un número imposible justo en el momento en que el jugador más
	# lo mira, y el dominio es el único lugar donde se puede impedir de una vez.
	assert_str(Marcador.reloj(-5.0)).is_equal("00:00")


func test_los_segundos_se_truncan_y_no_se_redondean() -> void:
	# Mostrar `01:00` cuando ya no queda un minuto entero es mentirle al jugador.
	assert_str(Marcador.reloj(59.9)).is_equal("00:59")


func test_menos_de_un_segundo_ya_se_lee_como_cero() -> void:
	assert_str(Marcador.reloj(0.9)).is_equal("00:00")


func test_hasta_la_hora_el_reloj_no_muestra_horas() -> void:
	assert_str(Marcador.reloj(3599.0)).is_equal("59:59")


func test_desde_la_hora_el_reloj_cambia_de_forma() -> void:
	# Sin este corte, un turno entero daría `480:00`, que nadie lee como ocho horas.
	assert_str(Marcador.reloj(3600.0)).is_equal("1:00:00")


func test_el_turno_entero_se_lee_como_ocho_horas() -> void:
	assert_str(Marcador.reloj(28800.0)).is_equal("8:00:00")


func test_con_horas_los_minutos_son_los_de_esta_hora_y_no_los_del_turno() -> void:
	# Es el único caso donde los tres campos son distintos de cero, y por eso el único que
	# distingue «minutos de esta hora» de «minutos totales»: con los totales daría `2:121:05`.
	# Los otros casos con hora caen justo en el minuto 0 y no lo pueden ver.
	assert_str(Marcador.reloj(7265.0)).is_equal("2:01:05")


func test_un_segundo_antes_del_umbral_todavia_no_es_aviso() -> void:
	assert_bool(Marcador.en_aviso(1801.0)).is_false()


func test_el_umbral_exacto_ya_es_aviso() -> void:
	assert_bool(Marcador.en_aviso(1800.0)).is_true()


func test_un_turno_agotado_sigue_estando_en_aviso() -> void:
	assert_bool(Marcador.en_aviso(0.0)).is_true()


func test_las_tareas_se_leen_como_cumplidas_sobre_declaradas() -> void:
	assert_str(Marcador.tareas(3, 4)).is_equal("3/4")


func test_la_cantidad_de_obligatorias_entra_por_argumento() -> void:
	# El segundo argumento cambia y el resultado lo sigue: el marcador no sabe cuántas tareas
	# pide el jefe, y por eso una tarea más no lo toca.
	assert_str(Marcador.tareas(0, 5)).is_equal("0/5")
