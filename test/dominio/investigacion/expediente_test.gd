extends GdUnitTestSuite

const JORNADA_5 := GeneradorDeTickets.JORNADA_SIN_LECTOR
const JORNADA_6 := JORNADA_5 + 1


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


func test_el_objeto_de_una_pista_solo_la_levanta_la_noche_de_esa_pista() -> void:  # AC-CLN-050
	var levantar := _pista("L")
	levantar.canal = Pista.Canal.LEVANTAR
	var expediente := Expediente.new(_caso([levantar]))
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
	):
		assert_bool(expediente.levanta_una_pista(levantar.origen, jornada)).is_equal(
			jornada == levantar.jornada
		)
		assert_bool(expediente.levanta_una_pista(&"ajeno", jornada)).is_false()


## La cuarta jornada con la hipótesis elegida: de ella depende el camino hacia la quinta.
func _con_la_cuarta_elegida(caso: CasoDeInvestigacion, identidad: String) -> Expediente:
	var expediente := Expediente.new(caso)
	expediente.registrar(identidad)
	expediente.elegir(GeneradorDeTickets.JORNADA_SIN_LECTOR - 1, identidad)
	return expediente


func test_5b_se_registra_una_vez_con_su_foto_y_su_texto() -> void:  # AC-INV-091
	var caso := CasoDeInvestigacion.de_la_partida()
	var jornada := GeneradorDeTickets.JORNADA_SIN_LECTOR
	var expediente := _con_la_cuarta_elegida(caso, "2A")
	var antes := expediente.mensajes_de_notas().size()
	var nuevas: Array[Pista] = []
	expediente.pista_nueva.connect(func(pista: Pista) -> void: nuevas.append(pista))
	var ajenos: Array[Array] = [
		[&"5B", Pista.Canal.CHAT, jornada - 1], [&"5B", Pista.Canal.LEVANTAR, jornada]
	]
	for ajeno: Array in ajenos:
		assert_int(expediente.registrar_por_canal(ajeno[0], ajeno[1], ajeno[2])).is_equal(
			Expediente.Resultado.DESCONOCIDA
		)
	assert_array(Array(expediente.identidades())).is_equal(["2A"])
	assert_int(expediente.registrar_por_canal(&"5B", Pista.Canal.CHAT, jornada)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_int(expediente.registrar_por_canal(&"5B", Pista.Canal.CHAT, jornada)).is_equal(
		Expediente.Resultado.REPETIDA
	)
	assert_array(Array(expediente.identidades())).is_equal(["2A", "5B"])
	assert_int(nuevas.size()).is_equal(1)
	var notas := expediente.mensajes_de_notas()
	assert_int(notas.size()).is_equal(antes + 2)
	if notas.size() == antes + 2:
		assert_object(notas[antes].foto).is_not_null()
		assert_str(notas[antes].texto).is_empty()
		assert_object(notas[antes + 1].foto).is_null()
		assert_str(notas[antes + 1].texto).is_equal(caso.pista_de("5B").texto)
		assert_int(notas[antes + 1].jornada).is_equal(jornada)


func test_registrar_5b_con_2a_no_cambia_las_notas_de_2a() -> void:  # AC-INV-091
	var expediente := _con_la_cuarta_elegida(CasoDeInvestigacion.de_la_partida(), "2A")
	var antes := expediente.mensajes_de_notas()
	assert_int(expediente.registrar("5B")).is_equal(Expediente.Resultado.ANOTADA)
	assert_array(Array(expediente.identidades())).is_equal(["2A", "5B"])
	var despues := expediente.mensajes_de_notas()
	assert_int(despues.size()).is_equal(antes.size() + 2)
	for indice: int in antes.size():
		assert_str(despues[indice].identidad).is_equal(antes[indice].identidad)


func test_5b_esta_en_el_camino_de_2a_y_no_en_el_de_2b() -> void:  # AC-INV-091
	var caso := CasoDeInvestigacion.de_la_partida()
	var jornada := GeneradorDeTickets.JORNADA_SIN_LECTOR
	var con_2a := _con_la_cuarta_elegida(caso, "2A")
	assert_bool(Array(caso.opcion(jornada - 1, "2A").camino).has("5B")).is_true()
	assert_bool(Array(con_2a.pistas_activas(jornada)).has("5B")).is_true()
	var con_2b := _con_la_cuarta_elegida(caso, "2B")
	assert_bool(Array(caso.opcion(jornada - 1, "2B").camino).has("5B")).is_false()
	assert_bool(Array(con_2b.pistas_activas(jornada)).has("5B")).is_false()
	assert_int(con_2b.registrar_por_canal(&"5B", Pista.Canal.CHAT, jornada)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_array(Array(con_2b.identidades())).is_equal(["2B"])
	var sin_elegir := Expediente.new(caso)
	assert_int(sin_elegir.registrar("5B")).is_equal(Expediente.Resultado.DESCONOCIDA)


## La quinta con 5B encontrada y elegida: de ella depende el camino hacia la sexta.
func _con_la_quinta_elegida(caso: CasoDeInvestigacion) -> Expediente:
	var expediente := _con_la_cuarta_elegida(caso, "2A")
	expediente.registrar("5B")
	expediente.elegir(JORNADA_5, "5B")
	return expediente


func test_la_nota_esta_en_el_local_segun_las_elecciones_del_expediente() -> void:  # AC-INV-120
	var caso := CasoDeInvestigacion.de_la_partida()
	var nota := caso.pista_de("6C").origen
	var con_5b := _con_la_quinta_elegida(caso)
	assert_bool(con_5b.esta_en_el_local(nota, JORNADA_6)).is_true()
	assert_bool(con_5b.esta_en_el_local(nota, JORNADA_5)).is_false()
	assert_bool(con_5b.esta_en_el_local(nota, JORNADA_6 + 1)).is_false()
	assert_bool(con_5b.esta_en_el_local(&"balde", JORNADA_6)).is_true()
	assert_bool(_con_la_cuarta_elegida(caso, "2B").esta_en_el_local(nota, JORNADA_6)).is_false()
	assert_bool(Expediente.new(caso).esta_en_el_local(nota, JORNADA_6)).is_false()


func test_restaurar_las_elecciones_guardadas_devuelve_la_nota() -> void:  # AC-INV-120
	var caso := CasoDeInvestigacion.de_la_partida()
	var nota := caso.pista_de("6C").origen
	var guardado := _con_la_quinta_elegida(caso)
	var restaurado := Expediente.new(caso)
	restaurado.restaurar(guardado.identidades(), guardado.elecciones(), guardado.sorteos())
	assert_bool(restaurado.esta_en_el_local(nota, JORNADA_6)).is_true()
	var sin_elecciones := Expediente.new(caso)
	sin_elecciones.restaurar(guardado.identidades(), {}, {})
	assert_bool(sin_elecciones.esta_en_el_local(nota, JORNADA_6)).is_false()


func test_6c_se_registra_una_vez_con_su_foto_y_su_texto() -> void:  # AC-INV-122
	var caso := CasoDeInvestigacion.de_la_partida()
	var nota := caso.pista_de("6C").origen
	var expediente := _con_la_quinta_elegida(caso)
	var antes := expediente.mensajes_de_notas().size()
	var nuevas: Array[Pista] = []
	expediente.pista_nueva.connect(func(pista: Pista) -> void: nuevas.append(pista))
	var ajenos: Array[Array] = [
		[nota, Pista.Canal.LEVANTAR, JORNADA_5],
		[nota, Pista.Canal.LEVANTAR, JORNADA_6 + 1],
		[nota, Pista.Canal.CHAT, JORNADA_6],
		[nota, Pista.Canal.EXAMINAR_NO_LEVANTABLE, JORNADA_6],
	]
	for ajeno: Array in ajenos:
		assert_int(expediente.registrar_por_canal(ajeno[0], ajeno[1], ajeno[2])).is_equal(
			Expediente.Resultado.DESCONOCIDA
		)
	assert_array(Array(expediente.identidades())).is_equal(["2A", "5B"])
	assert_int(expediente.registrar_por_canal(nota, Pista.Canal.LEVANTAR, JORNADA_6)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_int(expediente.registrar_por_canal(nota, Pista.Canal.LEVANTAR, JORNADA_6)).is_equal(
		Expediente.Resultado.REPETIDA
	)
	assert_array(Array(expediente.identidades())).is_equal(["2A", "5B", "6C"])
	assert_int(nuevas.size()).is_equal(1)
	assert_int(nuevas[0].jornada).is_equal(JORNADA_6)
	var notas := expediente.mensajes_de_notas()
	assert_int(notas.size()).is_equal(antes + 2)
	if notas.size() == antes + 2:
		assert_object(notas[antes].foto).is_not_null()
		assert_str(notas[antes].texto).is_empty()
		assert_object(notas[antes + 1].foto).is_null()
		assert_str(notas[antes + 1].texto).is_equal(caso.pista_de("6C").texto)
		assert_int(notas[antes + 1].jornada).is_equal(JORNADA_6)


func test_6c_no_se_registra_fuera_de_su_camino() -> void:  # AC-INV-122
	var caso := CasoDeInvestigacion.de_la_partida()
	var con_2b := _con_la_cuarta_elegida(caso, "2B")
	assert_int(con_2b.registrar("6C")).is_equal(Expediente.Resultado.DESCONOCIDA)
	assert_array(Array(con_2b.identidades())).is_equal(["2B"])
	assert_int(Expediente.new(caso).registrar("6C")).is_equal(Expediente.Resultado.DESCONOCIDA)


func test_sin_pistas_en_la_5_el_sorteo_cae_en_5b_y_activa_6c() -> void:  # AC-INV-125
	var caso := CasoDeInvestigacion.de_la_partida()
	for semilla: int in [0, 1, 7, 12345]:
		var expediente := _con_la_cuarta_elegida(caso, "2A")
		var azar := RandomNumberGenerator.new()
		azar.seed = semilla
		expediente.sortear_camino(JORNADA_6, azar)
		assert_str(expediente.sorteos().get(JORNADA_6, "")).is_equal("5B")
		assert_array(Array(expediente.pistas_activas(JORNADA_6))).contains(["6C"])
		var otro := RandomNumberGenerator.new()
		otro.seed = semilla + 1
		expediente.sortear_camino(JORNADA_6, otro)
		assert_str(expediente.sorteos().get(JORNADA_6, "")).is_equal("5B")
		assert_bool(expediente.esta_en_el_local(caso.pista_de("6C").origen, JORNADA_6)).is_true()


func test_con_5b_encontrada_no_se_sortea_y_6c_esta_activa() -> void:  # AC-INV-125
	var caso := CasoDeInvestigacion.de_la_partida()
	var expediente := _con_la_quinta_elegida(caso)
	expediente.sortear_camino(JORNADA_6, RandomNumberGenerator.new())
	assert_dict(expediente.sorteos()).is_empty()
	assert_array(Array(expediente.pistas_activas(JORNADA_6))).contains(["6C"])
