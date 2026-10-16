func test_notas_recibidas_j2_no_dan_boton_hasta_j3() -> void:  # AC-INV-028, AC-INV-052
	var normal := Conversacion.new()
	normal.interlocutor = Conversacion.Interlocutor.JEFE
	var notas := Conversacion.de(Conversacion.Interlocutor.NOTAS)
	assert_object(notas).is_not_null()
	if notas == null:
		return
	var bandeja := Bandeja.new([normal, notas])
	var mensaje := Mensaje.new()
	mensaje.identidad = "normal_J2"
	mensaje.jornada = 2
	mensaje.texto = "Mensaje normal"
	var nota := Mensaje.new()
	nota.identidad = "nota_J2"
	nota.jornada = 2
	nota.texto = "Mensaje de notas"
	bandeja.recibir(Conversacion.Interlocutor.JEFE, mensaje)
	bandeja.recibir(Conversacion.Interlocutor.NOTAS, nota)
	bandeja.abrir_jornada(1)
	assert_array(bandeja.conversaciones()).is_empty()
	assert_array(bandeja.mensajes_de(Conversacion.Interlocutor.NOTAS)).is_empty()
	bandeja.abrir_jornada(2)
	assert_array(bandeja.conversaciones()).is_equal([normal])
	assert_array(bandeja.mensajes_de(Conversacion.Interlocutor.NOTAS)).is_equal([nota])
	bandeja.abrir_jornada(3)
	assert_array(bandeja.conversaciones()).is_equal([normal, notas])
	assert_array(notas.mensajes).is_empty()
	assert_array(bandeja.mensajes_de(Conversacion.Interlocutor.NOTAS)).is_equal([nota])


func test_recibido_futuro_no_aparece_antes_de_su_jornada() -> void:  # AC-INV-028
	var normal := Conversacion.new()
	normal.interlocutor = Conversacion.Interlocutor.JEFE
	var bandeja := Bandeja.new([normal])
	var futuro := Mensaje.new()
	futuro.identidad = "futuro_J4"
	futuro.jornada = 4
	futuro.texto = "Mensaje de jornada cuatro"
	bandeja.abrir_jornada(2)
	assert_bool(bandeja.recibir(Conversacion.Interlocutor.JEFE, futuro)).is_true()
	assert_array(bandeja.mensajes_de(Conversacion.Interlocutor.JEFE)).is_empty()
	assert_array(bandeja.conversaciones()).is_empty()
	assert_int(bandeja.no_leidos_totales()).is_zero()
	bandeja.abrir_jornada(4)
	assert_array(bandeja.mensajes_de(Conversacion.Interlocutor.JEFE)).is_equal([futuro])
	assert_array(bandeja.conversaciones()).is_equal([normal])
	assert_int(bandeja.no_leidos_totales()).is_equal(1)
