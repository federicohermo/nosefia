extends GdUnitTestSuite

const R := ReflexionDeCierre.Eleccion


func _con(pistas: Array[String]) -> Expediente:
	var expediente := Expediente.new(CasoDeInvestigacion.de_la_partida())
	for pista: String in pistas:
		expediente.registrar(pista)
	return expediente


func _eleccion(expediente: Expediente) -> ReflexionDeCierre:
	var reflexion := ReflexionDeCierre.para(4, expediente)
	reflexion.empezar()
	return reflexion


func _identidades(opciones: Array[Hipotesis]) -> Array[String]:
	var identidades: Array[String] = []
	for opcion: Hipotesis in opciones:
		identidades.append(opcion.identidad)
	return identidades


func test_cuatro_combinaciones_en_el_recuadro() -> void:  # AC-INV-060
	var combinaciones: Array[Array] = [[], ["2A"], ["2B"]]
	var esperadas: Array[String] = ["2P", "2A", "2B"]
	for indice: int in combinaciones.size():
		var pistas: Array[String] = []
		pistas.assign(combinaciones[indice])
		var reflexion := _eleccion(_con(pistas))
		assert_str(reflexion.encabezado()).is_equal(ReflexionDeCierre.ENCABEZADOS[4])
		assert_array(_identidades(reflexion.opciones())).is_equal([esperadas[indice]])
		assert_str(reflexion.mostrada().identidad).is_equal(esperadas[indice])
		assert_bool(reflexion.siguiente()).is_false()
		assert_bool(reflexion.anterior()).is_false()
	var ambas := _con(["2B", "2A"])
	var notas := ambas.mensajes_de_notas().size()
	var reflexion := _eleccion(ambas)
	assert_array(_identidades(reflexion.opciones())).is_equal(["2A", "2B"])
	assert_str(reflexion.mostrada().identidad).is_equal("2A")
	assert_bool(reflexion.siguiente()).is_true()
	assert_str(reflexion.mostrada().identidad).is_equal("2B")
	assert_bool(reflexion.siguiente()).is_true()
	assert_str(reflexion.mostrada().identidad).is_equal("2A")
	assert_bool(reflexion.anterior()).is_true()
	assert_str(reflexion.mostrada().identidad).is_equal("2B")
	assert_int(ambas.mensajes_de_notas().size()).is_equal(notas)
	assert_array(Array(ambas.identidades())).is_equal(["2B", "2A"])
	assert_str(ambas.eleccion(4)).is_empty()


func test_elegir_una_sola_vez() -> void:  # AC-INV-061
	var expediente := _con(["2A", "2B"])
	assert_int(expediente.mensajes_de_notas().size()).is_equal(4)
	var reflexion := _eleccion(expediente)
	reflexion.siguiente()
	assert_int(reflexion.elegir(reflexion.mostrada().identidad)).is_equal(R.ACEPTADA)
	var notas := expediente.mensajes_de_notas()
	assert_int(notas.size()).is_equal(5)
	var hipotesis_2b: Hipotesis = reflexion.opciones()[1]
	assert_str(notas[-1].texto).is_equal(hipotesis_2b.texto)
	assert_int(notas[-1].jornada).is_equal(4)
	assert_int(notas[-1].orden).is_greater(notas[-2].orden)
	assert_str(expediente.eleccion(4)).is_equal("2B")
	for otra: String in ["2B", "2A"]:
		assert_int(reflexion.elegir(otra)).is_equal(R.REPETIDA)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(5)
	assert_str(expediente.eleccion(4)).is_equal("2B")


func test_lo_no_habilitado_no_se_elige() -> void:  # AC-INV-061
	var expediente := _con(["2A"])
	var reflexion := _eleccion(expediente)
	assert_str(expediente.eleccion(4)).is_empty()
	for ajena: String in ["2B", "2P", "desconocida", ""]:
		assert_int(reflexion.elegir(ajena)).is_equal(R.NO_DISPONIBLE)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(2)
	assert_str(expediente.eleccion(4)).is_empty()
	assert_int(reflexion.etapa()).is_equal(ReflexionDeCierre.Etapa.ELEGIR)


func test_la_primera_jornada_no_elige() -> void:  # AC-INV-061
	var expediente := _con([])
	var reflexion := ReflexionDeCierre.para(3, expediente)
	reflexion.empezar()
	assert_int(reflexion.elegir("2P")).is_equal(R.FUERA_DE_ETAPA)
	assert_array(expediente.mensajes_de_notas()).is_empty()
	assert_str(expediente.eleccion(4)).is_empty()


func test_restaurar_conserva_pistas_notas_y_eleccion_valida() -> void:  # AC-INV-064
	var anterior := _con(["2B"])
	_eleccion(anterior).elegir("2B")
	var restaurado := Expediente.new(CasoDeInvestigacion.de_la_partida())
	restaurado.restaurar(anterior.identidades(), anterior.elecciones())
	assert_array(Array(restaurado.identidades())).is_equal(["2B"])
	assert_str(restaurado.eleccion(4)).is_equal("2B")
	var antes := anterior.mensajes_de_notas()
	var despues := restaurado.mensajes_de_notas()
	assert_int(despues.size()).is_equal(antes.size())
	for indice: int in antes.size():
		assert_str(despues[indice].identidad).is_equal(antes[indice].identidad)
		assert_str(despues[indice].texto).is_equal(antes[indice].texto)
		assert_object(despues[indice].foto).is_same(antes[indice].foto)
	assert_object(ReflexionDeCierre.para(4, restaurado)).is_null()


func test_restaurar_descarta_lo_ajeno_sin_perder_lo_valido() -> void:  # AC-SAV-031
	var restaurado := Expediente.new(CasoDeInvestigacion.de_la_partida())
	restaurado.restaurar(PackedStringArray(["2B", "desconocida", "2B"]), {4: "2A"})
	assert_array(Array(restaurado.identidades())).is_equal(["2B"])
	assert_str(restaurado.eleccion(4)).is_empty()
	var reflexion := _eleccion(restaurado)
	assert_array(_identidades(reflexion.opciones())).is_equal(["2B"])
