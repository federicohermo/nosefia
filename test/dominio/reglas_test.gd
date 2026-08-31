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


func test_al_cuarto_apercibimiento_lo_echan() -> void:
	# Escrito acá y no adentro de `legajo.gd` para que el número viva una sola vez: sin esta
	# aserción, `despedido()` puede decir `>= 4` con todos los tests del legajo en verde.
	assert_int(Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO).is_equal(4)


func test_una_jornada_grave_pesa_el_doble_que_un_aviso() -> void:
	# Es de acá que sale que dos jornadas graves seguidas despidan y tres de aviso todavía no.
	assert_int(Reglas.APERCIBIMIENTOS_POR_AVISO).is_equal(1)
	assert_int(Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE).is_equal(2)
