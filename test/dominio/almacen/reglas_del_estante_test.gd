## Los valores fijos de reponer, y la relación que los vuelve jugables.
##
## No afirma el número: afirma **contra qué tiene que ser** ese número. Una caja que trae menos
## unidades de las que a un producto le faltan deja una noche en la que reponer no se puede
## terminar, y el síntoma no nombra a esta constante: el jugador vacía la caja, coloca todo lo
## que tenía y la tarea sigue sin contar.
extends GdUnitTestSuite


## Las jornadas de la partida, de la primera a la última.
func _jornadas() -> Array[int]:
	var jornadas: Array[int] = []
	for numero in ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA:
		jornadas.append(ReglasDeLaPartida.PRIMERA_JORNADA + numero)
	return jornadas


## Un faltante de 9 es un error de los datos y no un caso que el juego acomoda: la caja trae 8, y
## ninguna otra cosa del depósito repone ese producto. Se recorren las cinco jornadas y no sólo
## la primera: las que la ficha todavía no decidió también arrancan con algo.
func test_ningun_faltante_de_ninguna_jornada_pasa_de_una_caja() -> void:  # AC-STK-033
	for jornada in _jornadas():
		var faltantes := Apertura.faltantes_de_la_jornada(jornada)
		for id: Producto.Id in faltantes:
			(
				assert_int(faltantes[id])
				. override_failure_message(
					(
						"jornada %d: faltan %d %s y la caja trae %d"
						% [
							jornada,
							faltantes[id],
							Catalogo.de(id).nombre,
							ReglasDelEstante.UNIDADES_POR_CAJA,
						]
					)
				)
				. is_between(1, ReglasDelEstante.UNIDADES_POR_CAJA)
			)


func test_las_unidades_de_una_caja_son_una_cantidad_y_no_un_centinela() -> void:
	assert_int(ReglasDelEstante.UNIDADES_POR_CAJA).is_greater(0)
