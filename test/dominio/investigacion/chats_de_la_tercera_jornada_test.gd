extends GdUnitTestSuite

const JEFE := Conversacion.Interlocutor.JEFE
const YASMIN := Conversacion.Interlocutor.YASMIN
const JORNADA_DEL_LECTOR := GeneradorDeTickets.JORNADA_SIN_LECTOR
const CALAVERA := 0x1F480
const CARA_APRETADA := 0x1F62C


func _identidades(mensajes: Array[Mensaje]) -> Array[String]:
	var identidades: Array[String] = []
	for mensaje in mensajes:
		identidades.append(mensaje.identidad)
	return identidades


func _guion_esperado() -> Array[String]:
	var identidades: Array[String] = []
	for numero in range(1, 16):
		identidades.append("J2_%d" % numero)
	for numero in range(1, 11):
		identidades.append("J3_%d" % numero)
	return identidades


func _previos() -> int:
	return (
		Conversacion
		. de(YASMIN)
		. mensajes
		. filter(func(mensaje: Mensaje) -> bool: return mensaje.jornada < JORNADA_DEL_LECTOR)
		. size()
	)


func _bloque(mensajes: Array[Mensaje]) -> Array[Mensaje]:
	return mensajes.filter(
		func(mensaje: Mensaje) -> bool: return mensaje.identidad.begins_with("J3_")
	)


func test_la_jornada_del_lector_suma_el_bloque_tras_los_quince() -> void:  # AC-INV-066
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(JORNADA_DEL_LECTOR - 1)
	bandeja.marcar_leida(YASMIN)
	var del_jefe := bandeja.no_leidos(JEFE)
	bandeja.abrir_jornada(JORNADA_DEL_LECTOR)
	assert_array(_identidades(bandeja.mensajes_de(YASMIN))).is_equal(_guion_esperado())
	var bloque := _bloque(bandeja.mensajes_de(YASMIN))
	assert_int(bandeja.no_leidos(YASMIN)).is_equal(bloque.size())
	assert_int(bandeja.no_leidos(JEFE)).is_equal(del_jefe)
	bandeja.marcar_leida(YASMIN)
	assert_int(bandeja.no_leidos(YASMIN)).is_zero()
	assert_int(bandeja.no_leidos(JEFE)).is_equal(del_jefe)


func test_un_checkpoint_en_la_jornada_del_lector_abre_todo_sin_leer() -> void:  # AC-INV-066
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(JORNADA_DEL_LECTOR)
	var mensajes := bandeja.mensajes_de(YASMIN)
	assert_array(_identidades(mensajes)).is_equal(_guion_esperado())
	assert_int(bandeja.no_leidos(YASMIN)).is_equal(mensajes.size())
	for indice in mensajes.size():
		assert_int(mensajes[indice].jornada).is_equal(
			(
				ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
				if indice < _previos()
				else JORNADA_DEL_LECTOR
			)
		)


func test_antes_de_la_jornada_del_lector_el_bloque_no_existe() -> void:  # AC-INV-067
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	for jornada in range(ReglasDeLaPartida.PRIMERA_JORNADA, JORNADA_DEL_LECTOR):
		bandeja.abrir_jornada(jornada)
		for conversacion in bandeja.conversaciones():
			assert_array(_bloque(bandeja.mensajes_de(conversacion.interlocutor))).is_empty()
	bandeja.abrir_jornada(JORNADA_DEL_LECTOR - 1)
	assert_int(bandeja.mensajes_de(YASMIN).size()).is_equal(_previos())
	bandeja.abrir_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_array(bandeja.mensajes_de(YASMIN)).is_empty()
	bandeja.abrir_jornada(JORNADA_DEL_LECTOR)
	assert_array(_bloque(bandeja.mensajes_de(JEFE))).is_empty()


func test_el_bloque_no_concede_pistas_y_trae_sus_dos_glifos() -> void:  # AC-INV-068
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(JORNADA_DEL_LECTOR)
	var bloque := _bloque(bandeja.mensajes_de(YASMIN))
	assert_array(_identidades(bloque)).is_equal(_guion_esperado().slice(_previos()))
	for mensaje in bloque:
		assert_str(mensaje.tramo_de_pista).is_empty()
		assert_str(mensaje.pista).is_empty()
		assert_str(mensaje.texto_del_tramo).is_empty()
		assert_str(mensaje.pista_del_tramo(mensaje.tramo_de_pista)).is_empty()
		assert_bool(mensaje.foto == null).is_true()
	assert_bool(bloque[6].texto.contains(String.chr(CALAVERA))).is_true()
	assert_bool(bloque[8].texto.contains(String.chr(CARA_APRETADA))).is_true()


func test_repetir_la_apertura_no_duplica_ni_altera_el_guion() -> void:  # AC-INV-069
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(JORNADA_DEL_LECTOR)
	var antes := bandeja.mensajes_de(YASMIN)
	bandeja.abrir_jornada(JORNADA_DEL_LECTOR)
	assert_array(bandeja.mensajes_de(YASMIN)).is_equal(antes)
	var consultada := bandeja.mensajes_de(YASMIN)
	consultada.clear()
	assert_array(_identidades(bandeja.mensajes_de(YASMIN))).is_equal(_guion_esperado())
	bandeja.abrir_jornada(JORNADA_DEL_LECTOR + 1)
	assert_array(_identidades(bandeja.mensajes_de(YASMIN))).is_equal(_guion_esperado())


func test_un_guardado_previo_reconstruye_el_bloque_una_sola_vez() -> void:  # AC-SAV-035
	var partida := Partida.desde({"jornada": JORNADA_DEL_LECTOR - 1})
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		tarea.completar()
	partida.cerrar_la_jornada(partida.obligatorias().size())
	var datos := PoliticaDeGuardado.datos(partida)
	assert_int(partida.jornada()).is_equal(JORNADA_DEL_LECTOR)
	assert_bool(JSON.stringify(datos).contains("J3_")).is_false()
	var retomada := Partida.desde(datos)
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(retomada.jornada())
	var devoluciones: Array = retomada.call("devoluciones_del_jefe")
	for mensaje: Mensaje in devoluciones:
		assert_bool(bandeja.recibir(JEFE, mensaje)).is_true()
	assert_array(_identidades(bandeja.mensajes_de(YASMIN))).is_equal(_guion_esperado())
	assert_array(PoliticaDeGuardado.datos(retomada).devoluciones).is_equal(datos.devoluciones)
	assert_bool(JSON.stringify(PoliticaDeGuardado.datos(retomada)).contains("J3_")).is_false()
