## Las cinco quejas de cobro de la jornada 7: el sorteo, la respuesta del jugador y cuándo la
## obligatoria queda cumplida.
extends GdUnitTestSuite

const SEMILLAS := 200


func _sin_valor_en_su_texto(quien: Conversacion.Interlocutor) -> bool:
	var indice := QuejasDeLaJornada.indice_de(quien)
	var texto: String = QuejasDeLaJornada.FILAS[indice]["texto"]
	return not texto.contains(QuejasDeLaJornada.MARCA_DEL_VALOR)


func _incorrectas(quejas: QuejasDeLaJornada) -> int:
	var cuantas := 0
	for indice in QuejasDeLaJornada.cantidad():
		if not quejas.es_correcto(indice):
			cuantas += 1
	return cuantas


func _cobrados(quejas: QuejasDeLaJornada) -> Array[int]:
	var valores: Array[int] = []
	for indice in QuejasDeLaJornada.cantidad():
		valores.append(quejas.cobrado(indice))
	return valores


func _responder_bien(quejas: QuejasDeLaJornada, indice: int) -> void:
	quejas.responder(indice, not quejas.es_correcto(indice))


func test_el_total_correcto_de_cada_compra_sale_del_catalogo() -> void:  # AC-INV-141
	for indice in QuejasDeLaJornada.cantidad():
		var esperado := 0
		for id in QuejasDeLaJornada.productos_de(indice):
			esperado += Catalogo.de(id).precio
		assert_int(QuejasDeLaJornada.total_correcto(indice)).is_equal(esperado)
		assert_int(esperado).is_greater(0)


func test_cada_comprador_tiene_su_chat_y_ninguno_se_repite() -> void:  # AC-INV-141
	var chats := QuejasDeLaJornada.conversaciones()
	assert_int(chats.size()).is_equal(QuejasDeLaJornada.cantidad())
	var vistos: Array[Conversacion.Interlocutor] = []
	for chat in chats:
		assert_str(chat.nombre).is_not_empty()
		assert_int(chat.jornada_de_menu).is_equal(QuejasDeLaJornada.JORNADA)
		assert_bool(vistos.has(chat.interlocutor)).is_false()
		vistos.append(chat.interlocutor)
		assert_int(QuejasDeLaJornada.indice_de(chat.interlocutor)).is_greater_equal(0)
	assert_int(QuejasDeLaJornada.indice_de(Conversacion.Interlocutor.JEFE)).is_equal(-1)


func test_el_mensaje_de_cada_comprador_lleva_la_captura_con_su_valor() -> void:  # AC-INV-141
	var quejas := QuejasDeLaJornada.de_la_partida(1)
	for chat in QuejasDeLaJornada.conversaciones():
		var mensajes := quejas.mensajes_de(chat.interlocutor)
		assert_int(mensajes.size()).is_equal(1)
		assert_bool(mensajes[0].tiene_captura()).is_true()
		assert_bool(mensajes[0].propio).is_false()
		assert_int(mensajes[0].jornada).is_equal(QuejasDeLaJornada.JORNADA)


func test_el_valor_del_texto_es_el_de_la_captura() -> void:  # AC-INV-142
	for semilla in 20:
		var quejas := QuejasDeLaJornada.de_la_partida(semilla + 1)
		for chat in QuejasDeLaJornada.conversaciones():
			var indice := QuejasDeLaJornada.indice_de(chat.interlocutor)
			var mensaje := quejas.mensajes_de(chat.interlocutor)[0]
			var importe := QuejasDeLaJornada.formato_del_importe(quejas.cobrado(indice))
			assert_str(mensaje.importe_de_la_captura).is_equal(importe)
			assert_bool(mensaje.texto.contains(importe)).is_equal(
				not _sin_valor_en_su_texto(chat.interlocutor)
			)
			assert_bool(mensaje.texto.contains(QuejasDeLaJornada.MARCA_DEL_VALOR)).is_false()


func test_flavio_y_myriam_no_dicen_el_valor_en_el_texto() -> void:  # AC-INV-142
	assert_bool(_sin_valor_en_su_texto(Conversacion.Interlocutor.FLAVIO_BALBIN)).is_true()
	assert_bool(_sin_valor_en_su_texto(Conversacion.Interlocutor.MYRIAM_MELANO)).is_true()
	assert_bool(_sin_valor_en_su_texto(Conversacion.Interlocutor.EL_SEBA)).is_false()
	assert_bool(_sin_valor_en_su_texto(Conversacion.Interlocutor.SUKO_YANEZ)).is_false()
	assert_bool(_sin_valor_en_su_texto(Conversacion.Interlocutor.LUCAS_ORTEGA)).is_false()
	var quejas := QuejasDeLaJornada.de_la_partida(7)
	var sin_valor: Array[Conversacion.Interlocutor] = [
		Conversacion.Interlocutor.FLAVIO_BALBIN, Conversacion.Interlocutor.MYRIAM_MELANO
	]
	for quien in sin_valor:
		assert_bool(quejas.mensajes_de(quien)[0].texto.contains("$")).is_false()


func test_el_sorteo_deja_entre_las_incorrectas_minimas_y_maximas() -> void:  # AC-INV-143
	var vistas: Array[int] = []
	for semilla in SEMILLAS:
		var incorrectas := _incorrectas(QuejasDeLaJornada.de_la_partida(semilla + 1))
		assert_int(incorrectas).is_between(
			QuejasDeLaJornada.MINIMO_INCORRECTAS, QuejasDeLaJornada.MAXIMO_INCORRECTAS
		)
		if not vistas.has(incorrectas):
			vistas.append(incorrectas)
	assert_bool(vistas.has(QuejasDeLaJornada.MINIMO_INCORRECTAS)).is_true()
	assert_bool(vistas.has(QuejasDeLaJornada.MAXIMO_INCORRECTAS)).is_true()


func test_un_valor_incorrecto_cambia_uno_o_dos_productos_y_no_es_el_total() -> void:  # AC-INV-143
	var catalogo: Array[Producto.Id] = []
	for producto in Catalogo.de_la_jornada(QuejasDeLaJornada.JORNADA):
		catalogo.append(producto.id)
	for semilla in SEMILLAS:
		var quejas := QuejasDeLaJornada.de_la_partida(semilla + 1)
		for indice in QuejasDeLaJornada.cantidad():
			var cobrados := quejas.productos_cobrados(indice)
			var originales := QuejasDeLaJornada.productos_de(indice)
			assert_int(cobrados.size()).is_equal(originales.size())
			var cambiados := 0
			for posicion in originales.size():
				if cobrados[posicion] != originales[posicion]:
					cambiados += 1
					assert_bool(catalogo.has(cobrados[posicion])).is_true()
			var correcto := QuejasDeLaJornada.total_correcto(indice)
			if quejas.es_correcto(indice):
				assert_int(cambiados).is_zero()
				assert_int(quejas.cobrado(indice)).is_equal(correcto)
			else:
				assert_int(cambiados).is_between(
					QuejasDeLaJornada.MINIMO_REEMPLAZOS, QuejasDeLaJornada.MAXIMO_REEMPLAZOS
				)
				assert_int(quejas.cobrado(indice)).is_not_equal(correcto)


func test_la_misma_semilla_sortea_los_mismos_valores() -> void:  # AC-INV-144
	for semilla in 20:
		assert_array(_cobrados(QuejasDeLaJornada.de_la_partida(semilla + 1))).is_equal(
			_cobrados(QuejasDeLaJornada.de_la_partida(semilla + 1))
		)


func test_semillas_distintas_sortean_valores_distintos() -> void:  # AC-INV-144
	var distintos: Array[Array] = []
	for semilla in 20:
		var valores: Array = _cobrados(QuejasDeLaJornada.de_la_partida(semilla + 1))
		if not distintos.has(valores):
			distintos.append(valores)
	assert_int(distintos.size()).is_greater(1)


func test_darle_la_razon_acierta_si_el_valor_es_incorrecto_y_rechazar_si_no() -> void:  # AC-INV-145
	for indice in QuejasDeLaJornada.cantidad():
		var da_la_razon := QuejasDeLaJornada.de_la_partida(3)
		assert_bool(da_la_razon.responder(indice, true)).is_true()
		assert_bool(da_la_razon.acerto(indice)).is_equal(not da_la_razon.es_correcto(indice))
		var rechaza := QuejasDeLaJornada.de_la_partida(3)
		assert_bool(rechaza.responder(indice, false)).is_true()
		assert_bool(rechaza.acerto(indice)).is_equal(rechaza.es_correcto(indice))
	assert_bool(QuejasDeLaJornada.de_la_partida(3).acerto(0)).is_false()


func test_una_queja_respondida_no_se_responde_otra_vez() -> void:  # AC-INV-145
	var quejas := QuejasDeLaJornada.de_la_partida(3)
	assert_bool(quejas.responder(0, true)).is_true()
	var respuesta := quejas.respuesta_de(0)
	assert_bool(quejas.responder(0, true)).is_false()
	assert_bool(quejas.responder(0, false)).is_false()
	assert_int(quejas.respuesta_de(0)).is_equal(respuesta)


func test_un_indice_que_no_existe_se_rechaza_sin_cambiar_nada() -> void:  # AC-INV-145
	var quejas := QuejasDeLaJornada.de_la_partida(3)
	assert_bool(quejas.responder(-1, true)).is_false()
	assert_bool(quejas.responder(QuejasDeLaJornada.cantidad(), true)).is_false()
	for indice in QuejasDeLaJornada.cantidad():
		assert_bool(quejas.respondida(indice)).is_false()
	assert_bool(quejas.cumplida()).is_false()


func test_responder_agrega_la_respuesta_del_jugador_con_su_texto() -> void:  # AC-INV-146
	var quien := Conversacion.Interlocutor.EL_SEBA
	var indice := QuejasDeLaJornada.indice_de(quien)
	var quejas := QuejasDeLaJornada.de_la_partida(5)
	assert_int(quejas.mensajes_de(quien).size()).is_equal(1)
	quejas.responder(indice, true)
	var mensajes := quejas.mensajes_de(quien)
	assert_int(mensajes.size()).is_equal(2)
	assert_bool(mensajes[1].propio).is_true()
	assert_str(mensajes[1].texto).is_equal(QuejasDeLaJornada.TEXTO_DE_DAR_LA_RAZON)
	var otra := QuejasDeLaJornada.de_la_partida(5)
	otra.responder(indice, false)
	assert_str(otra.mensajes_de(quien)[1].texto).is_equal(QuejasDeLaJornada.TEXTO_DE_RECHAZAR)


func test_sin_respuestas_la_obligatoria_no_esta_cumplida() -> void:  # AC-INV-147
	assert_bool(QuejasDeLaJornada.de_la_partida(2).cumplida()).is_false()


func test_con_cuatro_bien_no_alcanza_y_con_las_cinco_bien_si() -> void:  # AC-INV-147
	var quejas := QuejasDeLaJornada.de_la_partida(2)
	for indice in QuejasDeLaJornada.cantidad() - 1:
		_responder_bien(quejas, indice)
	assert_bool(quejas.cumplida()).is_false()
	_responder_bien(quejas, QuejasDeLaJornada.cantidad() - 1)
	assert_bool(quejas.cumplida()).is_true()


func test_con_una_equivocada_no_se_cumple_ni_respondiendola_de_nuevo() -> void:  # AC-INV-147
	for equivocada in QuejasDeLaJornada.cantidad():
		var quejas := QuejasDeLaJornada.de_la_partida(2)
		for indice in QuejasDeLaJornada.cantidad():
			if indice == equivocada:
				quejas.responder(indice, quejas.es_correcto(indice))
			else:
				_responder_bien(quejas, indice)
		assert_bool(quejas.cumplida()).is_false()
		_responder_bien(quejas, equivocada)
		assert_bool(quejas.cumplida()).is_false()


func test_los_digitos_de_la_cuenta_son_fijos_y_distintos() -> void:  # AC-INV-148
	var vistas: Array[String] = []
	for indice in QuejasDeLaJornada.cantidad():
		var cuenta := QuejasDeLaJornada.cuenta_de(indice)
		assert_int(cuenta.length()).is_equal(4)
		assert_bool(cuenta.is_valid_int()).is_true()
		assert_bool(vistas.has(cuenta)).is_false()
		vistas.append(cuenta)
	for semilla in 10:
		var quejas := QuejasDeLaJornada.de_la_partida(semilla + 1)
		for chat in QuejasDeLaJornada.conversaciones():
			var indice := QuejasDeLaJornada.indice_de(chat.interlocutor)
			var mensaje := quejas.mensajes_de(chat.interlocutor)[0]
			assert_str(mensaje.origen_de_la_captura).is_equal(QuejasDeLaJornada.cuenta_de(indice))


func test_el_importe_lleva_el_punto_de_mil_de_la_captura() -> void:  # AC-INV-148
	assert_str(QuejasDeLaJornada.formato_del_importe(4200)).is_equal("$ 4.200")
	assert_str(QuejasDeLaJornada.formato_del_importe(30000)).is_equal("$ 30.000")
	assert_str(QuejasDeLaJornada.formato_del_importe(900)).is_equal("$ 900")
	assert_str(QuejasDeLaJornada.formato_del_importe(1234567)).is_equal("$ 1.234.567")
