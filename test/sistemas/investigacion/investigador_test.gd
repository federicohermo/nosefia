extends GdUnitTestSuite


func _expediente() -> Expediente:
	var pista := Pista.new()
	pista.identidad = "A"
	pista.jornada = 2
	pista.canal = Pista.Canal.CHAT
	pista.origen = &"origen"
	pista.foto = GradientTexture2D.new()
	pista.texto = "Texto de A"
	var caso := CasoDeInvestigacion.new()
	caso.pistas = [pista]
	return Expediente.new(caso)


func test_sin_usar_no_crea_un_expediente_alternativo() -> void:  # AC-EMP-069
	var investigador: Investigador = auto_free(Investigador.new())
	assert_object(investigador.get("_expediente")).is_null()
	assert_int(investigador.pedir_pista(&"origen", Pista.Canal.CHAT, 2, true)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_object(investigador.get("_expediente")).is_null()


func test_solo_anotada_publica_pista_y_dos_mensajes() -> void:  # AC-INV-043, AC-INV-051
	var investigador: Investigador = auto_free(Investigador.new())
	var expediente := _expediente()
	var pistas: Array[Pista] = []
	var notas: Array[Mensaje] = []
	investigador.pista_nueva.connect(func(pista: Pista) -> void: pistas.append(pista))
	investigador.nota_agregada.connect(func(mensaje: Mensaje) -> void: notas.append(mensaje))
	investigador.usar(expediente)
	assert_object(investigador.get("_expediente")).is_same(expediente)
	assert_int(investigador.pedir_pista(&"origen", Pista.Canal.CHAT, 2, true)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_int(investigador.pedir_pista(&"origen", Pista.Canal.CHAT, 2, true)).is_equal(
		Expediente.Resultado.REPETIDA
	)
	assert_int(investigador.pedir_pista(&"ajena", Pista.Canal.CHAT, 2, true)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_int(pistas.size()).is_equal(1)
	assert_int(notas.size()).is_equal(2)
	if pistas.is_empty() or notas.size() != 2:
		return
	assert_str(pistas[0].identidad).is_equal("A")
	assert_int(pistas[0].jornada).is_equal(2)
	assert_object(notas[0].foto).is_not_null()
	assert_str(notas[1].texto).is_equal("Texto de A")


func test_rechazos_sin_efecto() -> void:  # AC-INV-048, AC-INV-049, AC-INV-054
	var investigador: Investigador = auto_free(Investigador.new())
	var expediente := _expediente()
	investigador.usar(expediente)
	assert_int(investigador.pedir_pista(&"origen", Pista.Canal.CHAT, 2, false)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_int(investigador.pedir_pista(&"origen", Pista.Canal.LEVANTAR, 2, true)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_int(investigador.pedir_pista(&"origen", Pista.Canal.CHAT, 1, true)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_int(investigador.pedir_pista(&"origen", Pista.Canal.CHAT, 3, true)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_array(Array(expediente.identidades())).is_empty()
	assert_array(expediente.mensajes_de_notas()).is_empty()


func test_dos_consumidores_observan_el_mismo_registro() -> void:  # AC-EMP-069
	var primero: Investigador = auto_free(Investigador.new())
	var segundo: Investigador = auto_free(Investigador.new())
	var expediente := _expediente()
	primero.usar(expediente)
	segundo.usar(expediente)
	assert_int(primero.pedir_pista(&"origen", Pista.Canal.CHAT, 2, true)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_int(segundo.pedir_pista(&"origen", Pista.Canal.CHAT, 2, true)).is_equal(
		Expediente.Resultado.REPETIDA
	)
	assert_array(Array(expediente.identidades())).is_equal(["A"])
	assert_object(primero.get("_expediente")).is_same(segundo.get("_expediente"))


func test_reconectar_al_mismo_no_duplica_las_notas_recibidas() -> void:  # AC-INV-051
	var investigador: Investigador = auto_free(Investigador.new())
	var celular: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	var expediente := _expediente()
	investigador.nota_agregada.connect(
		func(mensaje: Mensaje) -> void: celular.recibir(Conversacion.Interlocutor.NOTAS, mensaje)
	)
	investigador.usar(expediente)
	investigador.pedir_pista(&"origen", Pista.Canal.CHAT, 2, true)
	celular.abrir_jornada(2)
	assert_int(celular.bandeja().mensajes_de(Conversacion.Interlocutor.NOTAS).size()).is_equal(2)
	investigador.usar(expediente)
	celular.abrir_jornada(3)
	assert_int(celular.bandeja().mensajes_de(Conversacion.Interlocutor.NOTAS).size()).is_equal(2)


func test_cambiar_de_partida_desconecta_los_eventos_anteriores() -> void:  # AC-EMP-069
	var investigador: Investigador = auto_free(Investigador.new())
	var anterior := _expediente()
	var actual := _expediente()
	var pistas: Array[Pista] = []
	investigador.pista_nueva.connect(func(pista: Pista) -> void: pistas.append(pista))
	investigador.usar(anterior)
	investigador.usar(actual)
	anterior.registrar("A")
	assert_array(pistas).is_empty()
	assert_array(Array(actual.identidades())).is_empty()
	investigador.pedir_pista(&"origen", Pista.Canal.CHAT, 2, true)
	assert_int(pistas.size()).is_equal(1)
