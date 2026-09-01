## La aritmética del presupuesto del turno, ejercida con números inventados.
##
## Los casos usan `100.0` y costos redondos a propósito: acá se verifica **la cuenta**, no el
## balance del juego. Que los números reales cierren es otro test y vive en `reglas_test.gd`,
## porque si se mezclaran, un rebalanceo del turno pondría en rojo a la resta —que seguiría
## estando bien— y el rojo dejaría de decir qué se rompió.
extends GdUnitTestSuite


func test_sin_trayecto_el_margen_es_la_duracion_menos_los_costos() -> void:
	var costos: Array[float] = [10.0, 10.0]
	assert_float(Presupuesto.margen(100.0, costos, 0.0, 1.0)).is_equal(80.0)


func test_sin_tareas_no_se_descuenta_nada_y_la_lista_vacia_no_rompe() -> void:
	var costos: Array[float] = []
	assert_float(Presupuesto.margen(100.0, costos, 0.0, 24.0)).is_equal(100.0)


func test_el_trayecto_entra_multiplicado_por_el_ritmo() -> void:
	# Es el término que hasta este spec no aparecía en ningún criterio del repo, y con un ritmo
	# de 24 es el que domina: un segundo real caminando cuesta más que un segundo de tarea.
	var costos: Array[float] = [10.0, 10.0]
	assert_float(Presupuesto.margen(100.0, costos, 1.0, 24.0)).is_equal(56.0)


func test_un_turno_que_no_alcanza_devuelve_cuanto_falta_y_no_cero() -> void:
	# Que devuelva `-20.0` y no `0.0` ni un booleano es lo que hace que el rojo del balance
	# diga qué número tocar y en cuánto.
	var costos: Array[float] = [60.0, 60.0]
	assert_float(Presupuesto.margen(100.0, costos, 0.0, 1.0)).is_equal(-20.0)


func test_alcanza_solo_con_margen_estrictamente_positivo() -> void:
	var sobra: Array[float] = [10.0, 10.0]
	assert_bool(Presupuesto.alcanza(100.0, sobra, 0.0, 1.0)).is_true()

	# El turno que se consume exacto es `false`: sin un segundo libre no se puede investigar, y
	# la investigación no es opcional en este juego.
	var exacto: Array[float] = [50.0, 50.0]
	assert_float(Presupuesto.margen(100.0, exacto, 0.0, 1.0)).is_equal(0.0)
	assert_bool(Presupuesto.alcanza(100.0, exacto, 0.0, 1.0)).is_false()

	var falta: Array[float] = [60.0, 60.0]
	assert_bool(Presupuesto.alcanza(100.0, falta, 0.0, 1.0)).is_false()


func test_la_cuenta_no_depende_de_cuantas_tareas_haya() -> void:
	# Con cinco costos da lo mismo que restarlos uno por uno, así que definir una sexta tarea no
	# obliga a tocar `presupuesto.gd`: no hay ningún `5` escrito ahí adentro.
	#
	# Los cinco valores son inventados y **todos distintos** a propósito. Distintos porque una
	# lista con repetidos no caza que la suma sume dos veces el mismo elemento; e inventados
	# porque copiar acá los costos reales de `Reglas` pondría el balance del juego en un segundo
	# archivo, que es exactamente el modo de falla que este spec vino a cerrar.
	var costos: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0]
	var trayecto := 2.0
	var a_mano := 100.0
	for costo: float in costos:
		a_mano -= costo
	a_mano -= 24.0 * trayecto
	assert_float(Presupuesto.margen(100.0, costos, trayecto, 24.0)).is_equal(a_mano)
