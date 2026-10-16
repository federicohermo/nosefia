extends GdUnitTestSuite


func _pista(identidad: String, exigencias: PackedStringArray = PackedStringArray()) -> Pista:
	var pista := Pista.new()
	pista.identidad = identidad
	pista.jornada = 2
	pista.origen = StringName(identidad)
	pista.canal = Pista.Canal.CHAT
	pista.exigencias = exigencias
	return pista


func _caso(pistas: Array[Pista], desenlaces: Array[Desenlace] = []) -> CasoDeInvestigacion:
	var caso := CasoDeInvestigacion.new()
	caso.pistas = pistas
	caso.desenlaces = desenlaces
	return caso


func _con_nota(identidad: String) -> Pista:
	var pista := _pista(identidad)
	pista.foto = GradientTexture2D.new()
	pista.texto = "Nota " + identidad
	return pista


func test_registrar_nueva_repetida_y_ajena_publica_solo_la_nueva() -> void:  # AC-INV-043
	var expediente := Expediente.new(_caso([_pista("A")]))
	var nuevas: Array[Pista] = []
	expediente.pista_nueva.connect(func(pista: Pista) -> void: nuevas.append(pista))
	assert_int(expediente.registrar("A")).is_equal(Expediente.Resultado.ANOTADA)
	assert_int(expediente.registrar("A")).is_equal(Expediente.Resultado.REPETIDA)
	assert_int(expediente.registrar("ajena")).is_equal(Expediente.Resultado.DESCONOCIDA)
	assert_array(Array(expediente.identidades())).is_equal(["A"])
	assert_int(nuevas.size()).is_equal(1)
	if nuevas.is_empty():
		return
	assert_str(nuevas[0].identidad).is_equal("A")
	assert_int(nuevas[0].jornada).is_equal(2)


func test_una_y_dos_exigencias_pendientes_no_registran() -> void:  # AC-INV-044
	var a := _pista("A")
	var b := _pista("B", PackedStringArray(["A"]))
	var c := _pista("C", PackedStringArray(["A", "B"]))
	var expediente := Expediente.new(_caso([a, b, c]))
	assert_int(expediente.registrar("B")).is_equal(Expediente.Resultado.DESCONOCIDA)
	assert_array(Array(expediente.identidades())).is_empty()
	assert_int(expediente.registrar("A")).is_equal(Expediente.Resultado.ANOTADA)
	assert_int(expediente.registrar("C")).is_equal(Expediente.Resultado.DESCONOCIDA)
	assert_int(expediente.registrar("B")).is_equal(Expediente.Resultado.ANOTADA)
	assert_int(expediente.registrar("C")).is_equal(Expediente.Resultado.ANOTADA)
	assert_array(Array(expediente.identidades())).is_equal(["A", "B", "C"])


func test_umbral_y_exigencia_publican_cada_desenlace_una_vez() -> void:  # AC-INV-045
	var primero := Desenlace.new()
	primero.identidad = "primero"
	primero.umbral = 2
	var segundo := Desenlace.new()
	segundo.identidad = "segundo"
	segundo.umbral = 2
	segundo.exigencias = PackedStringArray(["C"])
	var expediente := Expediente.new(
		_caso([_pista("A"), _pista("B"), _pista("C")], [primero, segundo])
	)
	var avisos: Array[Desenlace] = []
	expediente.desenlace_alcanzado.connect(func(final: Desenlace) -> void: avisos.append(final))
	expediente.registrar("A")
	assert_array(expediente.desenlaces_alcanzados()).is_empty()
	assert_array(avisos).is_empty()
	expediente.registrar("B")
	assert_array(expediente.desenlaces_alcanzados()).is_equal([primero])
	assert_array(avisos).is_equal([primero])
	expediente.registrar("C")
	assert_array(expediente.desenlaces_alcanzados()).is_equal([primero, segundo])
	expediente.registrar("B")
	expediente.registrar("C")
	assert_array(avisos).is_equal([primero, segundo])
	var copia := expediente.desenlaces_alcanzados()
	copia.clear()
	assert_array(expediente.desenlaces_alcanzados()).is_equal([primero, segundo])


func test_caso_inconsistente_no_registra_ni_publica() -> void:  # AC-INV-046
	var a := _pista("A")
	var expediente := Expediente.new(_caso([a, a]))
	var nuevas: Array[Pista] = []
	expediente.pista_nueva.connect(func(pista: Pista) -> void: nuevas.append(pista))
	assert_int(expediente.registrar("A")).is_equal(Expediente.Resultado.DESCONOCIDA)
	assert_array(Array(expediente.identidades())).is_empty()
	assert_array(nuevas).is_empty()


func test_reconstruir_sanea_en_orden_sin_emitir_y_entrega_copia() -> void:  # AC-INV-047
	var expediente := Expediente.new(_caso([_pista("A"), _pista("B")]))
	var nuevas: Array[Pista] = []
	expediente.pista_nueva.connect(func(pista: Pista) -> void: nuevas.append(pista))
	expediente.reconstruir(PackedStringArray(["B", "A", "B", "ajena"]))
	assert_array(Array(expediente.identidades())).is_equal(["B", "A"])
	var copia := expediente.identidades()
	copia.reverse()
	copia.clear()
	assert_array(Array(expediente.identidades())).is_equal(["B", "A"])
	assert_array(nuevas).is_empty()
	assert_array(expediente.mensajes_de_notas()).is_empty()
	assert_int(expediente.registrar("B")).is_equal(Expediente.Resultado.REPETIDA)
	assert_array(nuevas).is_empty()


func test_canal_y_jornada_ajenos_no_registran_la_pista() -> void:  # AC-INV-054
	var examen := _pista("examen")
	examen.canal = Pista.Canal.EXAMINAR_NO_LEVANTABLE
	var comprador := _pista("comprador")
	comprador.canal = Pista.Canal.COMPRADOR
	var expediente := Expediente.new(_caso([examen, comprador]))
	assert_int(expediente.registrar_por_canal(&"examen", Pista.Canal.LEVANTAR, 2)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_int(expediente.registrar_por_canal(&"comprador", Pista.Canal.CHAT, 2)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	(
		assert_int(expediente.registrar_por_canal(&"examen", Pista.Canal.EXAMINAR_NO_LEVANTABLE, 1))
		. is_equal(Expediente.Resultado.DESCONOCIDA)
	)
	assert_array(Array(expediente.identidades())).is_empty()
	(
		assert_int(expediente.registrar_por_canal(&"examen", Pista.Canal.EXAMINAR_NO_LEVANTABLE, 2))
		. is_equal(Expediente.Resultado.ANOTADA)
	)
	assert_int(expediente.registrar_por_canal(&"comprador", Pista.Canal.COMPRADOR, 2)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_int(expediente.registrar_por_canal(&"comprador", Pista.Canal.COMPRADOR, 2)).is_equal(
		Expediente.Resultado.REPETIDA
	)


func test_notas_se_agregan_foto_texto_en_orden_de_descubrimiento() -> void:  # AC-INV-051
	var a := _con_nota("A")
	var b := _con_nota("B")
	var expediente := Expediente.new(_caso([a, b]))
	expediente.registrar("B")
	expediente.registrar("A")
	var notas := expediente.mensajes_de_notas()
	assert_int(notas.size()).is_equal(4)
	if notas.size() != 4:
		return
	assert_object(notas[0].foto).is_same(b.foto)
	assert_str(notas[1].texto).is_equal(b.texto)
	assert_object(notas[2].foto).is_same(a.foto)
	assert_str(notas[3].texto).is_equal(a.texto)
	var ids := PackedStringArray()
	for indice: int in notas.size():
		assert_int(notas[indice].jornada).is_equal(2)
		assert_int(notas[indice].orden).is_equal(indice)
		assert_bool(ids.has(notas[indice].identidad)).is_false()
		assert_str(notas[indice].identidad).is_not_empty()
		ids.append(notas[indice].identidad)
	expediente.registrar("A")
	expediente.registrar("B")
	expediente.registrar("ajena")
	assert_int(expediente.mensajes_de_notas().size()).is_equal(4)
	expediente.reconstruir(expediente.identidades(), notas)
	expediente.reconstruir(expediente.identidades(), notas)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(4)
	var reconstruido := Expediente.new(_caso([a, b]))
	reconstruido.reconstruir(expediente.identidades(), notas)
	assert_array(Array(reconstruido.identidades())).is_equal(["B", "A"])
	assert_int(reconstruido.mensajes_de_notas().size()).is_equal(4)


func test_consultar_notas_no_muta_estado_ni_guion() -> void:  # AC-INV-055
	var a := _con_nota("A")
	var expediente := Expediente.new(_caso([a]))
	var nuevas: Array[Pista] = []
	expediente.pista_nueva.connect(func(pista: Pista) -> void: nuevas.append(pista))
	expediente.registrar("A")
	var copia := expediente.mensajes_de_notas()
	assert_int(copia.size()).is_equal(2)
	if copia.size() != 2:
		return
	copia[1].texto = "alterado por consumidor"
	copia.reverse()
	copia.clear()
	var ids := expediente.identidades()
	ids.clear()
	assert_array(Array(expediente.identidades())).is_equal(["A"])
	assert_int(expediente.mensajes_de_notas().size()).is_equal(2)
	assert_str(expediente.mensajes_de_notas()[1].texto).is_equal("Nota A")
	assert_str(a.texto).is_equal("Nota A")
	assert_int(nuevas.size()).is_equal(1)


func test_reconstruir_sin_b_conserva_adjuntos_de_a_y_c() -> void:  # AC-INV-047, AC-INV-051
	var a := _con_nota("A")
	var b := _con_nota("B")
	var c := _con_nota("C")
	var anterior := Expediente.new(_caso([a, b]))
	anterior.registrar("B")
	anterior.registrar("A")
	var expediente := Expediente.new(_caso([a, c]))
	expediente.reconstruir(anterior.identidades(), anterior.mensajes_de_notas())
	assert_array(Array(expediente.identidades())).is_equal(["A"])
	assert_int(expediente.mensajes_de_notas().size()).is_equal(2)
	assert_int(expediente.registrar("C")).is_equal(Expediente.Resultado.ANOTADA)
	var bandeja := Bandeja.new([Conversacion.de(Conversacion.Interlocutor.NOTAS)])
	bandeja.abrir_jornada(3)
	for mensaje: Mensaje in expediente.mensajes_de_notas():
		bandeja.recibir(Conversacion.Interlocutor.NOTAS, mensaje)
	var notas := bandeja.mensajes_de(Conversacion.Interlocutor.NOTAS)
	assert_int(notas.size()).is_equal(4)
	if notas.size() != 4:
		return
	assert_str(notas[0].identidad).is_equal("NOTA_A_FOTO")
	assert_str(notas[1].identidad).is_equal("NOTA_A_TEXTO")
	assert_str(notas[2].identidad).is_equal("NOTA_C_FOTO")
	assert_str(notas[3].identidad).is_equal("NOTA_C_TEXTO")
	assert_object(notas[0].foto).is_same(a.foto)
	assert_object(notas[2].foto).is_same(c.foto)
	assert_object(bandeja.adjunto_de(Conversacion.Interlocutor.NOTAS, 0)).is_same(notas[1])
	assert_object(bandeja.adjunto_de(Conversacion.Interlocutor.NOTAS, 2)).is_same(notas[3])
	assert_str(notas[1].texto).is_equal("Nota A")
	assert_str(notas[3].texto).is_equal("Nota C")
