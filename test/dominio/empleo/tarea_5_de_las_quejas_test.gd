## La Tarea 5 de la jornada 7: las quejas sin resolver.
extends GdUnitTestSuite

const T := Tarea.Tipo

const JORNADA := QuejasDeLaJornada.JORNADA


func _devolucion(sin_cumplir: Array[T]) -> Array[String]:
	var partida := Partida.desde({"jornada": JORNADA})
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		if not sin_cumplir.has(tarea.tipo()):
			tarea.completar()
	partida.cerrar_la_jornada(partida.obligatorias().size() - sin_cumplir.size())
	return DevolucionDelJefe.new(JORNADA, partida).mensajes()


func test_con_las_quejas_sin_cumplir_la_devolucion_trae_su_tarea_5() -> void:  # AC-SHF-082
	var mensajes := _devolucion([T.RESPONDER_QUEJAS])
	assert_int(mensajes.count(DevolucionDelJefe.PARTICULARES[JORNADA])).is_equal(1)
	assert_str(DevolucionDelJefe.PARTICULARES[JORNADA]).is_not_empty()


func test_con_las_quejas_cumplidas_la_devolucion_no_trae_tarea_5() -> void:  # AC-SHF-082
	var mensajes := _devolucion([])
	assert_array(mensajes).not_contains([DevolucionDelJefe.PARTICULARES[JORNADA]])


func test_la_tarea_5_de_las_quejas_no_aparece_si_falla_otra_obligatoria() -> void:  # AC-SHF-082
	var mensajes := _devolucion([T.LIMPIAR])
	assert_array(mensajes).not_contains([DevolucionDelJefe.PARTICULARES[JORNADA]])


func test_ninguna_otra_jornada_trae_ese_texto() -> void:  # AC-SHF-082
	for jornada in range(ReglasDeLaPartida.PRIMERA_JORNADA, JORNADA):
		if DevolucionDelJefe.PARTICULARES.has(jornada):
			assert_str(DevolucionDelJefe.PARTICULARES[jornada]).is_not_equal(
				DevolucionDelJefe.PARTICULARES[JORNADA]
			)
