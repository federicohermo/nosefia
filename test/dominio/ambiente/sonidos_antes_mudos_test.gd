## Los usos que no tenían sonido, en la tabla del disco: la caja, lo que deja una bolsa, el
## ticket desechado, el jabón equivocado y el ambiente de afuera.
##
## La fila sin audio de AC-AMB-010 la sigue probando una tabla armada en su suite: ésta mira la
## tabla que suena en el juego.
extends GdUnitTestSuite


func _tabla() -> TablaDeSonidos:
	var tabla := TablaDeSonidos.desde_disco()
	(
		assert_object(tabla)
		. override_failure_message("`%s` no carga o no es una tabla" % TablaDeSonidos.RUTA)
		. is_not_null()
	)
	return tabla


static func _audio(entrada: EntradaSonora) -> String:
	if entrada == null or entrada.stream == null:
		return ""
	return entrada.stream.resource_path.get_file().get_basename()


func test_retirar_las_notas_no_cambia_los_numeros_de_los_eventos_restantes() -> void:
	assert_int(EntradaSonora.Evento.TICKET_IMPRESO).is_equal(29)
	assert_int(EntradaSonora.Evento.TICKET_DESECHADO).is_equal(30)
	assert_array(EntradaSonora.Evento.values()).not_contains(31)
	assert_int(EntradaSonora.Evento.PASADA_CON_JABON_EQUIVOCADO).is_equal(32)
	assert_int(EntradaSonora.Evento.AMBIENTE_EXTERIOR).is_equal(33)
	assert_array(EntradaSonora.Evento.values()).not_contains(9)
	assert_int(EntradaSonora.Evento.BOLSA_SACADA).is_equal(34)
	assert_int(EntradaSonora.Evento.OBJETO_DESECHADO).is_equal(35)
	assert_int(EntradaSonora.Evento.size()).is_equal(34)


func test_la_caja_se_alza_y_se_deja_con_su_audio() -> void:
	var tabla := _tabla()
	var esperado := {
		EntradaSonora.Evento.OBJETO_AGARRADO: "SFX_OBJETO_Caja_Alzar",
		EntradaSonora.Evento.OBJETO_SOLTADO: "SFX_OBJETO_Caja_Dejar",
		EntradaSonora.Evento.PRODUCTO_COLOCADO: "SFX_OBJETO_Caja_Dejar",
		EntradaSonora.Evento.UNIDAD_DEVUELTA: "SFX_OBJETO_Caja_Dejar",
	}
	for evento: EntradaSonora.Evento in esperado:
		var fila := tabla.de(evento, EntradaSonora.Sonoridad.CAJA)
		assert_str(_audio(fila)).is_equal(esperado[evento])
		assert_bool(fila != null and fila.posicional).is_true()


func test_la_bolsa_se_deja_con_su_audio_y_se_alza_como_antes() -> void:
	var tabla := _tabla()
	var esperado := {
		EntradaSonora.Evento.OBJETO_AGARRADO: "SFX_OBJETO_Bolsa_Alzar",
		EntradaSonora.Evento.OBJETO_SOLTADO: "SFX_OBJETO_Bolsa_Dejar",
		EntradaSonora.Evento.PRODUCTO_COLOCADO: "SFX_OBJETO_Bolsa_Dejar",
		EntradaSonora.Evento.UNIDAD_DEVUELTA: "SFX_OBJETO_Bolsa_Dejar",
	}
	for evento: EntradaSonora.Evento in esperado:
		assert_str(_audio(tabla.de(evento, EntradaSonora.Sonoridad.BOLSA))).is_equal(
			esperado[evento]
		)
	assert_array(tabla.pares_sin_fila()).is_empty()


func test_el_ticket_y_el_jabon_equivocado_suenan_por_su_bus() -> void:
	var tabla := _tabla()
	var esperado := {
		EntradaSonora.Evento.TICKET_DESECHADO:
		["ticket_desechado", EntradaSonora.BUS_DE_EFECTOS, "SFX_NOLEV_Inodoro"],
		EntradaSonora.Evento.PASADA_CON_JABON_EQUIVOCADO:
		["pasada_con_jabon_equivocado", EntradaSonora.BUS_DE_EFECTOS, "SFX_OBJETO_Mopa_Limpiar"],
	}
	for evento: EntradaSonora.Evento in esperado:
		var fila := tabla.de(evento)
		assert_object(fila).is_not_null()
		if fila == null:
			continue
		assert_str(fila.senal).is_equal(esperado[evento][0])
		assert_str(fila.bus).is_equal(esperado[evento][1])
		assert_str(_audio(fila)).is_equal(esperado[evento][2])
		assert_bool(fila.en_bucle).is_false()


func test_mojar_la_mopa_y_limpiar_conservan_su_audio() -> void:
	var tabla := _tabla()
	assert_str(_audio(tabla.de(EntradaSonora.Evento.MOPA_MOJADA))).is_equal(
		"SFX_OBJETO_Mopa_MojarEnBalde"
	)
	assert_str(_audio(tabla.de(EntradaSonora.Evento.PASADA_DADA))).is_equal(
		"SFX_OBJETO_Mopa_Limpiar"
	)


func test_el_ambiente_exterior_suena_en_bucle_desde_la_ventanilla() -> void:
	var tabla := _tabla()
	var exterior := tabla.de(EntradaSonora.Evento.AMBIENTE_EXTERIOR)
	assert_object(exterior).is_not_null()
	if exterior == null:
		return
	assert_str(_audio(exterior)).is_equal("AMB_PROXIMIDAD_Exterior")
	assert_str(exterior.bus).is_equal(EntradaSonora.BUS_DE_AMBIENTE)
	assert_bool(exterior.en_bucle and exterior.posicional).is_true()
	assert_bool(exterior.stream.get("loop")).is_true()
	assert_str(exterior.senal).is_empty()
	var timbre := tabla.de(EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR)
	assert_str(exterior.emisor).is_equal(timbre.emisor)


func test_solo_los_pasos_usan_audio_de_personaje() -> void:
	for entrada: EntradaSonora in _tabla().entradas:
		for indice in range(entrada.cantidad_de_variantes()):
			var nombre := entrada.variante(indice).resource_path.get_file()
			if nombre.begins_with("SFX_PERSONAJE_"):
				assert_int(entrada.evento).is_equal(EntradaSonora.Evento.PASO_DADO)
