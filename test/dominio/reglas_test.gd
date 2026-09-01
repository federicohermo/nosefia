## Los valores fijos del juego, y lo que sí se puede verificar de un archivo de constantes: que
## estén **todos**, cuántos son, y que el turno alcance para pagarlos. El día que alguien agregue
## un sexto tipo de tarea al enum y se olvide de darle costo, es este archivo el que se pone en
## rojo y no la partida.
extends GdUnitTestSuite


func test_cada_tipo_de_tarea_tiene_un_costo_mayor_que_cero() -> void:
	# Se recorre el enum, nunca una lista escrita a mano: una lista a mano se olvida del tipo
	# nuevo justo el día que el tipo nuevo aparece, que es lo que este test tiene que cazar.
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		(
			assert_float(Reglas.costo_de(tipo))
			. override_failure_message(
				"el tipo %d de Tarea.Tipo no tiene costo en Reglas.costo_de()" % tipo
			)
			. is_greater(0.0)
		)


func test_los_tipos_de_tarea_son_las_cinco_obligatorias() -> void:
	assert_int(Tarea.Tipo.size()).is_equal(5)


func test_el_turno_dura_mas_que_hacer_las_cinco_tareas() -> void:
	# Es un **piso**, no la cuenta completa: no descuenta el trayecto entre una tarea y la
	# siguiente. Si el turno no alcanzara ni para esto, las cinco serían imposibles siempre.
	var suma_de_costos := 0.0
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		suma_de_costos += Reglas.costo_de(tipo)
	assert_float(Reglas.DURACION_DEL_TURNO).is_greater(suma_de_costos)


func test_el_turno_deja_lugar_para_investigar_con_los_numeros_reales() -> void:
	# **El test que firma la tensión central del juego.** El de arriba es el piso viejo, escrito
	# antes de que existiera el `Ritmo`: le falta el trayecto, que no es el término más grande
	# —los cinco costos siguen pesando más— pero sí el único que el ritmo multiplica por 24, y
	# eso alcanza para que tres minutos de reloj de pared se coman más segundos de ficción que
	# el piso de investigación entero. Éste hace la cuenta entera y se pone en rojo si alguien
	# toca la duración, un costo, el trayecto o el ritmo sin mirar los otros tres.
	#
	# Vive acá y no en `presupuesto_test.gd` a propósito: aquél verifica la resta, que seguiría
	# estando bien con el balance roto. Separarlos es lo que hace que el rojo diga cuál de las
	# dos cosas se rompió.
	var costos: Array[float] = []
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		costos.append(Reglas.costo_de(tipo))

	var duracion := Reglas.DURACION_DEL_TURNO
	var trayecto := Reglas.SEGUNDOS_DE_TRAYECTO_ESTIMADOS
	var ritmo := Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL
	var margen := Presupuesto.margen(duracion, costos, trayecto, ritmo)

	# Los dos mensajes dicen **cuánto** y no sólo que falló: es el número con el que se
	# rebalancea, y sin él el rojo obliga a rehacer la cuenta a mano para saber qué tocar.
	var no_alcanza := "el turno no alcanza para las cinco tareas y el trayecto: faltan %.1f"
	var no_llega_al_piso := (
		"quedan %.1f segundos de ficción para investigar y el piso son %.1f: faltan %.1f. "
		+ "Se arregla bajando un costo o el trayecto, no agrandando el turno."
	)
	var falta_para_el_piso := [margen, Reglas.MARGEN_MINIMO, Reglas.MARGEN_MINIMO - margen]

	(
		assert_bool(Presupuesto.alcanza(duracion, costos, trayecto, ritmo))
		. override_failure_message(no_alcanza % -margen)
		. is_true()
	)
	assert_float(margen).override_failure_message(no_llega_al_piso % falta_para_el_piso).is_greater(
		Reglas.MARGEN_MINIMO
	)


func test_el_piso_de_investigacion_es_mayor_que_cero() -> void:
	# Sin esto, `MARGEN_MINIMO := 0.0` dejaría al test de arriba diciendo «el margen es
	# positivo», que es exactamente la afirmación vacía que el piso vino a evitar.
	assert_float(Reglas.MARGEN_MINIMO).is_greater(0.0)


func test_el_trayecto_estimado_es_mayor_que_cero() -> void:
	# El gemelo del de arriba, y por el mismo agujero: `SEGUNDOS_DE_TRAYECTO_ESTIMADOS := 0.0`
	# devolvería el test del balance al piso viejo —duración contra costos y nada más— sin
	# ponerlo en rojo ni una vez, porque sacar el trayecto de la cuenta sólo agranda el margen.
	assert_float(Reglas.SEGUNDOS_DE_TRAYECTO_ESTIMADOS).is_greater(0.0)


func test_al_cuarto_apercibimiento_lo_echan() -> void:
	# Escrito acá y no adentro de `legajo.gd` para que el número viva una sola vez: sin esta
	# aserción, `despedido()` puede decir `>= 4` con todos los tests del legajo en verde.
	assert_int(Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO).is_equal(4)


func test_una_jornada_grave_pesa_el_doble_que_un_aviso() -> void:
	# Es de acá que sale que dos jornadas graves seguidas despidan y tres de aviso todavía no.
	assert_int(Reglas.APERCIBIMIENTOS_POR_AVISO).is_equal(1)
	assert_int(Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE).is_equal(2)
