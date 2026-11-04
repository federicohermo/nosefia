## Una nota lleva la hora del reloj del juego, y esa hora no cambia al guardar y cargar.
extends GdUnitTestSuite

const C := PartidaSerializada.Campo


func _por_disco(partida: Partida) -> Dictionary:
	return PartidaSerializada.sanear(str_to_var(var_to_str(PoliticaDeGuardado.datos(partida))))


func _cerrada(jornada: int, pistas: Array[String], hora_del_cierre: String) -> Partida:
	var partida := Partida.desde({"jornada": jornada})
	partida.abrir_la_jornada()
	for pista: String in pistas:
		partida.expediente.registrar(pista, "21:00")
	for tarea: Tarea in partida.obligatorias():
		tarea.completar()
	partida.cerrar_la_jornada(partida.obligatorias().size(), 0, hora_del_cierre)
	return partida


func _horas(notas: Array[Mensaje]) -> Array[String]:
	var horas: Array[String] = []
	for nota: Mensaje in notas:
		horas.append(nota.hora)
	return horas


func test_las_dos_notas_de_una_pista_llevan_la_hora_del_hallazgo() -> void:  # AC-INV-085
	var expediente := Expediente.new(CasoDeInvestigacion.de_la_partida())
	assert_int(expediente.registrar("2A", "21:00")).is_equal(Expediente.Resultado.ANOTADA)
	assert_array(_horas(expediente.mensajes_de_notas())).is_equal(["21:00", "21:00"])


func test_una_pista_hallada_con_el_turno_recien_abierto_lleva_las_20() -> void:  # AC-INV-085
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(Turno.new(Reglas.DURACION_DEL_TURNO, []), [])
	var expediente := Expediente.new(CasoDeInvestigacion.de_la_partida())
	expediente.registrar("2A", reloj.hora())
	assert_array(_horas(expediente.mensajes_de_notas())).is_equal(["20:00", "20:00"])


func test_la_hora_de_la_pista_sobrevive_al_guardado() -> void:  # AC-INV-085
	var partida := Partida.desde({"jornada": 4})
	partida.expediente.registrar("2A", "21:00")
	var cargada := Partida.desde(_por_disco(partida))
	assert_array(_horas(cargada.expediente.mensajes_de_notas())).is_equal(["21:00", "21:00"])


func test_la_hipotesis_lleva_la_hora_del_cierre() -> void:  # AC-INV-085
	var partida := _cerrada(4, ["2A"], "08:00")
	partida.reflexion.empezar()
	assert_int(partida.reflexion.elegir("2A")).is_equal(ReflexionDeCierre.Eleccion.ACEPTADA)
	var hipotesis: Array[Mensaje] = []
	for nota: Mensaje in partida.expediente.mensajes_de_notas():
		if nota.identidad.ends_with("_HIPOTESIS"):
			hipotesis.append(nota)
	assert_array(_horas(hipotesis)).is_equal(["08:00"])
	var cargada := Partida.desde(_por_disco(partida))
	var guardadas: Array[Mensaje] = []
	for nota: Mensaje in cargada.expediente.mensajes_de_notas():
		if nota.identidad.ends_with("_HIPOTESIS"):
			guardadas.append(nota)
	assert_array(_horas(guardadas)).is_equal(["08:00"])


func test_irse_antes_adelanta_la_hora_de_la_reflexion() -> void:  # AC-INV-085
	var partida := _cerrada(3, [], "03:15")
	partida.reflexion.empezar()
	partida.reflexion.continuar(partida.reflexion.identidad_del_texto())
	partida.reflexion.continuar(partida.reflexion.identidad_del_texto())
	assert_array(_horas(partida.expediente.mensajes_de_notas())).is_equal(["03:15", "03:15"])
	var cargada := Partida.desde(_por_disco(partida))
	assert_array(_horas(cargada.expediente.mensajes_de_notas())).is_equal(["03:15", "03:15"])


func test_una_nota_guardada_sin_hora_carga_sin_hora() -> void:  # AC-INV-085
	var partida := _cerrada(3, [], "")
	partida.reflexion.empezar()
	partida.reflexion.continuar(partida.reflexion.identidad_del_texto())
	var datos := _por_disco(partida)
	for nota: Variant in datos[PartidaSerializada.clave(C.NOTAS)]:
		(nota as Dictionary).erase("hora")
	var cargada := Partida.desde(datos)
	var notas := cargada.expediente.mensajes_de_notas()
	assert_int(notas.size()).is_equal(1)
	assert_array(_horas(notas)).is_equal([""])
