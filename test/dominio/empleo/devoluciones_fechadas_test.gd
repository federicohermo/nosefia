extends GdUnitTestSuite

const JEFE := Conversacion.Interlocutor.JEFE


func _cerrar_impecable(partida: Partida) -> void:
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		tarea.completar()
	partida.cerrar_la_jornada(partida.obligatorias().size())


func test_checkpoint_fechado_con_orden() -> void:  # AC-EMP-070, AC-SAV-027
	var partida := Partida.desde({"jornada": 2})
	assert_array(partida.mensajes_del_jefe()).is_empty()
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		if tarea.tipo() != Tarea.Tipo.REPONER:
			tarea.completar()
	partida.cerrar_la_jornada(partida.obligatorias().size() - 1)
	var datos := PoliticaDeGuardado.datos(partida)
	var mensajes: Array = datos.devoluciones
	assert_int(mensajes.size()).is_equal(3)
	assert_bool(mensajes[0] is Dictionary).is_true()
	if not mensajes[0] is Dictionary:
		return
	for indice: int in mensajes.size():
		var registro: Dictionary = mensajes[indice]
		assert_int(registro.jornada).is_equal(2)
		assert_int(registro.orden).is_equal(indice)
		assert_str(registro.texto).is_equal(partida.mensajes_del_jefe()[indice])
		assert_str(registro.identidad).is_not_empty()
	assert_str(mensajes[0].identidad).is_not_equal(mensajes[1].identidad)
	assert_int(partida.jornada()).is_equal(3)
	var retomada := Partida.desde(datos)
	assert_array(PoliticaDeGuardado.datos(retomada).devoluciones).is_equal(mensajes)
	partida.cerrar_la_jornada(0)
	assert_array(PoliticaDeGuardado.datos(partida).devoluciones).is_equal(mensajes)


func test_legado_conserva_repetidos_sin_fabricar_fecha() -> void:  # AC-SAV-028
	var textos: Array = ["Buen día!", "Buen día!", "Seguí así"]
	var partida := Partida.desde({"jornada": 2, "medios": 3, "devoluciones": textos})
	assert_array(partida.mensajes_del_jefe()).is_equal(textos)
	assert_array(PoliticaDeGuardado.datos(partida).devoluciones).is_equal(textos)
	assert_int(partida.jornada()).is_equal(2)
	assert_int(partida.medios()).is_equal(3)
	for dato: Variant in [7, null]:
		var saneada := Partida.desde({"jornada": 2, "medios": 3, "devoluciones": dato})
		assert_array(saneada.mensajes_del_jefe()).is_empty()
		assert_int(saneada.jornada()).is_equal(2)
		assert_int(saneada.medios()).is_equal(3)


func test_dos_cierres_guardan_bloques_en_su_orden() -> void:  # AC-EMP-066, AC-EMP-070
	var partida := Partida.nueva()
	_cerrar_impecable(partida)
	_cerrar_impecable(partida)
	var mensajes: Array = PoliticaDeGuardado.datos(partida).devoluciones
	assert_int(mensajes.size()).is_equal(4)
	assert_bool(mensajes[0] is Dictionary).is_true()
	if not mensajes[0] is Dictionary:
		return
	assert_int(mensajes[0].jornada).is_equal(1)
	assert_int(mensajes[1].jornada).is_equal(1)
	assert_int(mensajes[2].jornada).is_equal(2)
	assert_int(mensajes[3].jornada).is_equal(2)
	assert_str(mensajes[0].texto).is_equal(mensajes[2].texto)
	assert_str(mensajes[0].identidad).is_not_equal(mensajes[2].identidad)
	(
		assert_array(
			PoliticaDeGuardado.datos(Partida.desde(PoliticaDeGuardado.datos(partida))).devoluciones
		)
		. is_equal(mensajes)
	)


func test_retoma_intercala_y_no_fusiona() -> void:  # AC-INV-056, AC-EMP-066, AC-SAV-027
	var partida := Partida.nueva()
	_cerrar_impecable(partida)
	_cerrar_impecable(partida)
	var datos := PoliticaDeGuardado.datos(partida)
	assert_bool(datos.devoluciones[0] is Dictionary).is_true()
	if not datos.devoluciones[0] is Dictionary:
		return
	var retomada := Partida.desde(datos)
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(3)
	var devoluciones: Array = retomada.call("devoluciones_del_jefe")
	for mensaje: Mensaje in devoluciones:
		assert_bool(bandeja.recibir(JEFE, mensaje)).is_true()
	var historial := bandeja.mensajes_de(JEFE)
	assert_int(historial.size()).is_equal(25)
	assert_str(historial[19].texto).is_equal("Buen día!")
	assert_str(historial[19].get("identidad")).is_not_equal(historial[23].get("identidad"))
	assert_str(historial[21].get("identidad")).is_equal("J2_CONTENEDOR_FOTO")
	assert_str(historial[22].get("identidad")).is_equal("J2_CONTENEDOR_TEXTO")
	assert_str(historial[23].texto).is_equal("Buen día!")
	assert_int(historial[23].jornada).is_equal(2)
	assert_int(bandeja.conversaciones().size()).is_equal(2)
	if bandeja.conversaciones().size() != 2:
		return
	assert_int(bandeja.no_leidos(bandeja.conversaciones()[1].interlocutor)).is_equal(15)
	historial.clear()
	assert_int(bandeja.mensajes_de(JEFE).size()).is_equal(25)
	assert_int(Conversacion.de(JEFE).mensajes.size()).is_equal(21)
