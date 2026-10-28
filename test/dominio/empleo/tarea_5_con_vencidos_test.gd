## La Tarea 5 de la jornada 6: qué texto gana según dónde quedó el vencido sin desechar.
extends GdUnitTestSuite

const T := Tarea.Tipo

const JORNADA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2


func _partida_de_la_noche(
	jornada: int, cumplidas: Array[T], en_el_local: bool = false, afuera: bool = false
) -> Partida:
	var partida := Partida.desde({"jornada": jornada})
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		if cumplidas.has(tarea.tipo()):
			tarea.completar()
	partida.vencido_en_el_local = en_el_local
	partida.vencido_afuera = afuera
	partida.cerrar_la_jornada(cumplidas.size())
	return partida


func _con_los_vencidos_sin_desechar(jornada: int) -> Array[T]:
	var cumplidas: Array[T] = []
	for tarea: Tarea in Apertura.obligatorias(jornada):
		if tarea.tipo() != T.DESECHAR_VENCIDOS:
			cumplidas.append(tarea.tipo())
	return cumplidas


func _todas(jornada: int) -> Array[T]:
	var cumplidas: Array[T] = []
	for tarea: Tarea in Apertura.obligatorias(jornada):
		cumplidas.append(tarea.tipo())
	return cumplidas


func _tarea_5(en_el_local: bool, afuera: bool) -> Array[String]:
	var partida := _partida_de_la_noche(
		JORNADA, _con_los_vencidos_sin_desechar(JORNADA), en_el_local, afuera
	)
	return DevolucionDelJefe.new(JORNADA, partida).mensajes()


func _textos() -> Array[String]:
	return [
		DevolucionDelJefe.VENCIDO_EN_EL_LOCAL,
		DevolucionDelJefe.VENCIDO_POR_LA_VENTANA,
		DevolucionDelJefe.VENCIDO_EN_EL_LOCAL_Y_POR_LA_VENTANA,
	]


## Cuántos de los tres textos trae la devolución, y cuál.
func _cuales(mensajes: Array[String]) -> Array[String]:
	var presentes: Array[String] = []
	for texto in _textos():
		if mensajes.has(texto):
			presentes.append(texto)
	return presentes


func test_un_vencido_en_el_local_y_ninguno_afuera_dice_el_primer_texto() -> void:  # AC-EMP-100
	var mensajes := _tarea_5(true, false)
	assert_array(_cuales(mensajes)).contains_exactly([DevolucionDelJefe.VENCIDO_EN_EL_LOCAL])
	assert_int(mensajes.size()).is_equal(3)


func test_un_vencido_solo_afuera_dice_el_de_la_ventana() -> void:  # AC-EMP-100
	var mensajes := _tarea_5(false, true)
	assert_array(_cuales(mensajes)).contains_exactly([DevolucionDelJefe.VENCIDO_POR_LA_VENTANA])
	assert_int(mensajes.size()).is_equal(3)


func test_uno_en_el_local_y_otro_afuera_dice_los_dos_juntos_en_un_mensaje() -> void:  # AC-EMP-100
	var mensajes := _tarea_5(true, true)
	assert_array(_cuales(mensajes)).contains_exactly(
		[DevolucionDelJefe.VENCIDO_EN_EL_LOCAL_Y_POR_LA_VENTANA]
	)
	assert_int(mensajes.size()).is_equal(3)


func test_con_la_particular_cumplida_no_hay_tarea_5() -> void:  # AC-EMP-101
	var partida := _partida_de_la_noche(JORNADA, _todas(JORNADA), true, true)
	var mensajes := DevolucionDelJefe.new(JORNADA, partida).mensajes()
	assert_array(_cuales(mensajes)).is_empty()
	assert_int(mensajes.size()).is_equal(2)


func test_las_demas_jornadas_no_traen_estos_textos() -> void:  # AC-EMP-101
	for numero in ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA:
		var jornada := ReglasDeLaPartida.PRIMERA_JORNADA + numero
		if jornada < ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA or jornada == JORNADA:
			continue
		var partida := _partida_de_la_noche(jornada, [], true, true)
		assert_array(_cuales(DevolucionDelJefe.new(jornada, partida).mensajes())).is_empty()
