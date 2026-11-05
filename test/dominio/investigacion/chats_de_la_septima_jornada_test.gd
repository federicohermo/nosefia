## La jornada 7 abre con los tres mensajes de Enrique y los cinco chats de compradores.
extends GdUnitTestSuite

const JEFE := Conversacion.Interlocutor.JEFE
const AVISOS: Array[String] = ["J7_QUEJAS_HOLA", "J7_QUEJAS_RECLAMOS", "J7_QUEJAS_FIJATE"]
const HORAS: Array[String] = ["15:57", "15:58", "15:59"]
const JORNADA := QuejasDeLaJornada.JORNADA


func _bandeja_en(jornada: int, con_quejas: bool = false) -> Bandeja:
	var conversaciones := Conversacion.desde_disco()
	conversaciones.append_array(QuejasDeLaJornada.conversaciones())
	var bandeja := Bandeja.new(conversaciones)
	bandeja.abrir_jornada(jornada)
	if con_quejas:
		bandeja.usar_quejas(QuejasDeLaJornada.de_la_partida(1))
	return bandeja


func _identidades(mensajes: Array[Mensaje]) -> PackedStringArray:
	var identidades := PackedStringArray()
	for mensaje: Mensaje in mensajes:
		identidades.append(mensaje.identidad)
	return identidades


func _compradores() -> Array[Conversacion.Interlocutor]:
	var compradores: Array[Conversacion.Interlocutor] = []
	for chat in QuejasDeLaJornada.conversaciones():
		compradores.append(chat.interlocutor)
	return compradores


func _quienes(chats: Array[Conversacion]) -> Array[Conversacion.Interlocutor]:
	var quienes: Array[Conversacion.Interlocutor] = []
	for chat in chats:
		quienes.append(chat.interlocutor)
	return quienes


func test_enrique_suma_tres_mensajes_despues_de_la_devolucion_de_la_sexta() -> void:  # AC-INV-140
	var bandeja := _bandeja_en(JORNADA - 1)
	var devolucion := Mensaje.new()
	devolucion.identidad = "DEVOLUCION_J6_0"
	devolucion.texto = "Devolución"
	devolucion.jornada = JORNADA - 1
	devolucion.momento = Mensaje.Momento.CIERRE
	assert_bool(bandeja.recibir(JEFE, devolucion)).is_true()
	bandeja.abrir_jornada(JORNADA)
	var mensajes := bandeja.mensajes_de(JEFE)
	var identidades := _identidades(mensajes)
	assert_str(identidades[-4]).is_equal("DEVOLUCION_J6_0")
	assert_array(identidades.slice(-3)).is_equal(PackedStringArray(AVISOS))
	for posicion in HORAS.size():
		assert_str(mensajes[mensajes.size() - HORAS.size() + posicion].hora).is_equal(
			HORAS[posicion]
		)
		assert_bool(mensajes[mensajes.size() - HORAS.size() + posicion].dice_algo()).is_true()


func test_antes_de_la_septima_los_mensajes_no_existen() -> void:  # AC-INV-140
	for jornada: int in range(ReglasDeLaPartida.PRIMERA_JORNADA, JORNADA):
		var identidades := _identidades(_bandeja_en(jornada).mensajes_de(JEFE))
		for aviso in AVISOS:
			assert_bool(identidades.has(aviso)).is_false()


func test_retomar_en_la_septima_los_cuenta_una_sola_vez_como_nuevos() -> void:  # AC-INV-140
	var bandeja := _bandeja_en(JORNADA - 1)
	bandeja.marcar_leida(JEFE)
	assert_int(bandeja.no_leidos(JEFE)).is_zero()
	bandeja.abrir_jornada(JORNADA)
	assert_int(bandeja.no_leidos(JEFE)).is_equal(AVISOS.size())
	bandeja.abrir_jornada(JORNADA)
	assert_int(bandeja.no_leidos(JEFE)).is_equal(AVISOS.size())
	var retomada := _bandeja_en(JORNADA)
	assert_int(_identidades(retomada.mensajes_de(JEFE)).count(AVISOS[0])).is_equal(1)


func test_la_septima_lista_un_chat_por_comprador_con_un_mensaje_sin_leer() -> void:  # AC-INV-141
	var bandeja := _bandeja_en(JORNADA, true)
	var listados := _quienes(bandeja.conversaciones())
	for quien in _compradores():
		assert_bool(listados.has(quien)).is_true()
		assert_int(bandeja.mensajes_de(quien).size()).is_equal(1)
		assert_int(bandeja.no_leidos(quien)).is_equal(1)
		assert_str(bandeja.conversacion_de(quien).nombre).is_not_empty()


func test_antes_de_la_septima_ningun_comprador_aparece() -> void:  # AC-INV-141
	for jornada: int in range(ReglasDeLaPartida.PRIMERA_JORNADA, JORNADA):
		var listados := _quienes(_bandeja_en(jornada, true).conversaciones())
		for quien in _compradores():
			assert_bool(listados.has(quien)).is_false()


func test_sin_quejas_en_la_septima_no_hay_chats_de_compradores() -> void:  # AC-INV-141
	var listados := _quienes(_bandeja_en(JORNADA).conversaciones())
	for quien in _compradores():
		assert_bool(listados.has(quien)).is_false()


func test_responder_deja_la_respuesta_en_el_chat_sin_tocar_los_demas() -> void:  # AC-INV-146
	var bandeja := _bandeja_en(JORNADA, true)
	var quejas := QuejasDeLaJornada.de_la_partida(1)
	bandeja.usar_quejas(quejas)
	var quien := Conversacion.Interlocutor.LUCAS_ORTEGA
	var otro := Conversacion.Interlocutor.EL_SEBA
	bandeja.marcar_leida(quien)
	var sin_leer_del_otro := bandeja.no_leidos(otro)
	quejas.responder(QuejasDeLaJornada.indice_de(quien), true)
	assert_int(bandeja.mensajes_de(quien).size()).is_equal(2)
	assert_bool(bandeja.mensajes_de(quien)[1].propio).is_true()
	assert_bool(bandeja.marcar_leida(quien)).is_true()
	assert_int(bandeja.no_leidos(quien)).is_zero()
	assert_int(bandeja.no_leidos(otro)).is_equal(sin_leer_del_otro)


func test_la_captura_se_amplia_sin_tomar_la_respuesta_como_adjunto() -> void:  # AC-INV-146
	var quejas := QuejasDeLaJornada.de_la_partida(1)
	var bandeja := _bandeja_en(JORNADA)
	bandeja.usar_quejas(quejas)
	var quien := Conversacion.Interlocutor.MYRIAM_MELANO
	assert_object(bandeja.adjunto_de(quien, 0)).is_null()
	quejas.responder(QuejasDeLaJornada.indice_de(quien), false)
	assert_object(bandeja.adjunto_de(quien, 0)).is_null()
