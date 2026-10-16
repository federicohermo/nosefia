func test_notas_vacias_abren_fijas_en_cierre_j1_y_q_no_las_cierra() -> void:  # AC-INV-052
	var notas := Conversacion.de(Conversacion.Interlocutor.NOTAS)
	assert_object(notas).is_not_null()
	if notas == null:
		return
	var bandeja := Bandeja.new([notas])
	bandeja.abrir_jornada(1)
	var celular := Celular.new(bandeja)
	assert_array(bandeja.conversaciones()).is_empty()
	assert_bool(celular.fijar_en(Conversacion.Interlocutor.NOTAS)).is_true()
	assert_bool(celular.fijo()).is_true()
	assert_bool(celular.abierto()).is_true()
	assert_int(celular.chat()).is_equal(Conversacion.Interlocutor.NOTAS)
	assert_bool(celular.alternar(false)).is_false()
	assert_bool(celular.volver_al_menu()).is_false()
	assert_bool(celular.abierto()).is_true()


func test_notas_j2_amplian_con_adjunto_sin_necesitar_boton() -> void:  # AC-INV-051, AC-INV-052
	var notas := Conversacion.de(Conversacion.Interlocutor.NOTAS)
	assert_object(notas).is_not_null()
	if notas == null:
		return
	var bandeja := Bandeja.new([notas])
	bandeja.abrir_jornada(2)
	var foto := Mensaje.new()
	foto.identidad = "nota_foto"
	foto.jornada = 2
	foto.orden = 0
	foto.foto = GradientTexture2D.new()
	var texto := Mensaje.new()
	texto.identidad = "nota_texto"
	texto.jornada = 2
	texto.orden = 1
	texto.texto = "Adjunto de la nota"
	bandeja.recibir(Conversacion.Interlocutor.NOTAS, foto)
	bandeja.recibir(Conversacion.Interlocutor.NOTAS, texto)
	var celular := Celular.new(bandeja)
	assert_array(bandeja.conversaciones()).is_empty()
	assert_bool(celular.fijar_en(Conversacion.Interlocutor.NOTAS)).is_true()
	assert_bool(celular.ampliar(0)).is_true()
	assert_object(bandeja.adjunto_de(Conversacion.Interlocutor.NOTAS, 0)).is_same(texto)
	assert_bool(celular.cerrar_foto()).is_true()
	assert_int(celular.chat()).is_equal(Conversacion.Interlocutor.NOTAS)
	assert_bool(celular.abierto()).is_true()
	assert_bool(celular.fijo()).is_true()
	assert_array(bandeja.mensajes_de(Conversacion.Interlocutor.NOTAS)).is_equal([foto, texto])
