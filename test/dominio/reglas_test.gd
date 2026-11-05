## Los valores fijos del juego, y lo que sí se puede verificar de un archivo de constantes:
## cuántos son, y las invariantes que cruzan dos de ellos. Un número suelto no se afirma acá: se
## afirma donde se usa.
extends GdUnitTestSuite


func test_los_tipos_conservan_su_identidad_al_sumar_ordenar() -> void:
	assert_dict(Tarea.Tipo).is_equal(
		{
			"CAJA": 0,
			"REPONER": 1,
			"REGISTRAR": 2,
			"LIMPIAR": 3,
			"SACAR_LA_BASURA": 4,
			"ORDENAR_LAS_CAJAS": 5,
			"DESECHAR_VENCIDOS": 6,
			"PEDIR_AL_PROVEEDOR": 7
		}
	)


func test_la_noche_arranca_a_una_hora_del_dia() -> void:
	# La hora de apertura es la que el reloj de pared suma a lo transcurrido: fuera de las
	# veinticuatro, la lectura nacería con un `HH` que ningún reloj muestra.
	assert_int(Reglas.HORA_DE_APERTURA).is_between(0, 23)


func test_una_jornada_grave_pesa_el_doble_que_un_aviso() -> void:
	# Es de acá que sale que dos jornadas graves seguidas despidan y tres de aviso todavía no.
	assert_int(Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE).is_equal(
		2 * Reglas.APERCIBIMIENTOS_POR_AVISO
	)
