## Una pista de acción como la 7B no avisa ni deja notas: sólo suma al expediente.
extends GdUnitTestSuite

const JORNADA_7 := ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
const JORNADA_6 := JORNADA_7 - 1
const JORNADA_5 := JORNADA_6 - 1
const CUARTA := JORNADA_5 - 1


func _por_la_5a() -> Expediente:
	var expediente := Expediente.new(CasoDeInvestigacion.de_la_partida())
	expediente.registrar("2A")
	expediente.elegir(CUARTA, "2A")
	expediente.registrar("5A")
	expediente.elegir(JORNADA_5, "5A")
	return expediente


func test_registrar_7b_no_publica_pista_nueva_ni_notas() -> void:  # AC-INV-179
	var expediente := _por_la_5a()
	var investigador: Investigador = auto_free(Investigador.new())
	investigador.usar(expediente)
	var nuevas: Array[Pista] = []
	var notas: Array[Mensaje] = []
	investigador.pista_nueva.connect(func(pista: Pista) -> void: nuevas.append(pista))
	investigador.nota_agregada.connect(func(mensaje: Mensaje) -> void: notas.append(mensaje))
	var con_documento := investigador.pedir_pista(
		&"documento_impreso", Pista.Canal.LEVANTAR, JORNADA_6, true
	)
	assert_int(con_documento).is_equal(Expediente.Resultado.ANOTADA)
	assert_int(nuevas.size()).is_equal(1)
	assert_int(notas.size()).is_equal(2)
	expediente.elegir(JORNADA_6, "6B")
	var notas_antes := notas.size()
	var con_la_palanca := investigador.pedir_pista(
		Partida.PALANCA, Pista.Canal.ACCION, JORNADA_7, true
	)
	assert_int(con_la_palanca).is_equal(Expediente.Resultado.ANOTADA)
	assert_array(Array(expediente.identidades())).contains(["6B", "7B"])
	assert_int(nuevas.size()).is_equal(1)
	assert_int(notas.size()).is_equal(notas_antes)


func test_una_pista_de_accion_pedida_sin_permiso_no_registra() -> void:  # AC-INV-179
	var expediente := _por_la_5a()
	expediente.registrar("6B")
	expediente.elegir(JORNADA_6, "6B")
	var investigador: Investigador = auto_free(Investigador.new())
	investigador.usar(expediente)
	var rechazada := investigador.pedir_pista(Partida.PALANCA, Pista.Canal.ACCION, JORNADA_7, false)
	assert_int(rechazada).is_equal(Expediente.Resultado.DESCONOCIDA)
	assert_array(Array(expediente.identidades())).not_contains(["7B"])
