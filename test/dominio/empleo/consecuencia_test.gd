## Cuántas tareas se cumplieron, traducido a la banda que el cierre dispara.
##
## Los casos que mueven `obligatorias` no son de adorno: los que están escritos con 5
## obligatorias los pasa igual una implementación que compare contra un `5` a mano, que es
## justo el error que este diseño quiere impedir.
extends GdUnitTestSuite


func test_cumplir_las_cinco_obligatorias_no_trae_consecuencias() -> void:
	assert_int(Consecuencias.consecuencia_de(5, 5)).is_equal(Consecuencias.Banda.NINGUNA)


func test_cumplir_cuatro_de_cinco_es_un_aviso() -> void:
	assert_int(Consecuencias.consecuencia_de(4, 5)).is_equal(Consecuencias.Banda.AVISO)


func test_cumplir_tres_de_cinco_todavia_es_un_aviso() -> void:
	# El 3 es el borde de abajo del aviso, y el que la lectura de «tres puntos de control» como
	# tres valores exactos dejaba sin cubrir.
	assert_int(Consecuencias.consecuencia_de(3, 5)).is_equal(Consecuencias.Banda.AVISO)


func test_cumplir_menos_de_tres_es_grave() -> void:
	for cumplidas in [2, 1, 0]:
		(
			assert_int(Consecuencias.consecuencia_de(cumplidas, 5))
			. override_failure_message(
				"con %d de 5 cumplidas la banda tiene que ser GRAVE" % cumplidas
			)
			. is_equal(Consecuencias.Banda.GRAVE)
		)


func test_cumplir_todas_se_mide_contra_las_obligatorias_y_no_contra_un_cinco() -> void:
	# El día que haya una sexta tarea, esta función no se toca. Es la misma decisión que
	# `Turno.todas_cumplidas()`, y las dos tienen que decidir igual o el juego se contradice.
	assert_int(Consecuencias.consecuencia_de(3, 3)).is_equal(Consecuencias.Banda.NINGUNA)
	assert_int(Consecuencias.consecuencia_de(4, 4)).is_equal(Consecuencias.Banda.NINGUNA)


func test_el_corte_del_aviso_son_tres_tareas_y_no_una_fraccion_de_las_obligatorias() -> void:
	# Es el único caso que distingue las dos lecturas: con 6 obligatorias, un corte por
	# fracción estaría en 3,6 y contaría estas 3 como GRAVE. Con 5 obligatorias las dos
	# lecturas dan lo mismo, así que ningún otro caso de este archivo lo cubre.
	assert_int(Consecuencias.consecuencia_de(3, 6)).is_equal(Consecuencias.Banda.AVISO)


func test_cumplir_casi_todas_no_es_ninguna_consecuencia() -> void:
	# Con 6 obligatorias y 5 cumplidas falta una, así que es aviso — no «casi todas, ninguna
	# consecuencia». `NINGUNA` es `cumplidas == obligatorias` y nunca una fracción de ellas.
	assert_int(Consecuencias.consecuencia_de(5, 6)).is_equal(Consecuencias.Banda.AVISO)
