extends GdUnitTestSuite


func _celular() -> Celular:
	var conversacion := Conversacion.new()
	conversacion.nombre = "Contacto"
	var foto := Mensaje.new()
	foto.foto = GradientTexture2D.new()
	conversacion.mensajes = [foto]
	return Celular.new(Bandeja.new([conversacion]))


func test_los_cinco_estados_de_q() -> void:  # AC-INV-026
	var celular := _celular()
	assert_bool(celular.alternar(false)).is_false()
	celular.habilitar(true)
	assert_bool(celular.alternar(true)).is_false()
	assert_bool(celular.abierto()).is_false()
	assert_bool(celular.alternar(false)).is_true()
	assert_int(celular.pantalla()).is_equal(Celular.Pantalla.MENU)
	assert_bool(celular.alternar(true)).is_true()
	assert_bool(celular.abierto()).is_false()
	celular.habilitar(false)
	assert_bool(celular.alternar(false)).is_false()


func test_reabrir_desde_chat_y_foto_siempre_vuelve_al_menu() -> void:  # AC-INV-027, AC-INV-012
	var celular := _celular()
	celular.habilitar(true)
	for ampliar: bool in [false, true]:
		celular.alternar(false)
		assert_bool(celular.abrir_chat(Conversacion.Interlocutor.JEFE)).is_true()
		assert_int(celular.bandeja().no_leidos_totales()).is_zero()
		if ampliar:
			assert_bool(celular.ampliar(0)).is_true()
		celular.alternar(false)
		celular.alternar(false)
		assert_int(celular.pantalla()).is_equal(Celular.Pantalla.MENU)
		celular.alternar(false)


func test_menu_chat_foto_y_gestos_rechazados() -> void:  # AC-INV-027, AC-INV-031
	var celular := _celular()
	assert_bool(celular.abrir_chat(Conversacion.Interlocutor.JEFE)).is_false()
	celular.habilitar(true)
	celular.alternar(false)
	assert_bool(celular.volver_al_menu()).is_false()
	assert_bool(celular.abrir_chat(Conversacion.Interlocutor.PROVEEDOR)).is_false()
	assert_bool(celular.abrir_chat(Conversacion.Interlocutor.JEFE)).is_true()
	assert_bool(celular.abrir_chat(Conversacion.Interlocutor.JEFE)).is_false()
	assert_bool(celular.ampliar(-1)).is_false()
	assert_bool(celular.ampliar(1)).is_false()
	assert_bool(celular.ampliar(0)).is_true()
	assert_int(celular.foto()).is_zero()
	assert_bool(celular.volver_al_menu()).is_false()
	assert_bool(celular.cerrar_foto()).is_true()
	assert_bool(celular.cerrar_foto()).is_false()
	assert_bool(celular.volver_al_menu()).is_true()


func test_fijo_fuera_de_jornada_bloquea_q_y_atras_pero_admite_foto() -> void:  # AC-INV-032
	var celular := _celular()
	assert_bool(celular.soltar()).is_false()
	assert_bool(celular.fijar_en(Conversacion.Interlocutor.PROVEEDOR)).is_false()
	assert_bool(celular.fijar_en(Conversacion.Interlocutor.JEFE)).is_true()
	assert_bool(celular.fijar_en(Conversacion.Interlocutor.JEFE)).is_false()
	assert_bool(celular.fijo()).is_true()
	assert_bool(celular.alternar(false)).is_false()
	assert_bool(celular.volver_al_menu()).is_false()
	assert_bool(celular.ampliar(0)).is_true()
	assert_bool(celular.cerrar_foto()).is_true()
	assert_bool(celular.soltar()).is_true()
	assert_bool(celular.soltar()).is_false()
	assert_bool(celular.abierto()).is_false()


func test_deshabilitar_y_otra_jornada_sueltan_el_modo_fijo() -> void:  # AC-INV-036
	var celular := _celular()
	celular.fijar_en(Conversacion.Interlocutor.JEFE)
	celular.habilitar(false)
	assert_bool(celular.fijo()).is_false()
	assert_bool(celular.abierto()).is_false()
	celular.habilitar(true)
	celular.alternar(false)
	assert_int(celular.pantalla()).is_equal(Celular.Pantalla.MENU)


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


func test_esc_cierra_la_foto_y_despues_el_celular_libre() -> void:  # AC-INV-070, AC-INV-071
	var celular := _celular()
	assert_bool(celular.atender_esc()).is_false()
	celular.habilitar(true)
	assert_bool(celular.atender_esc()).is_false()
	celular.alternar(false)
	celular.abrir_chat(Conversacion.Interlocutor.JEFE)
	celular.ampliar(0)
	assert_bool(celular.atender_esc()).is_true()
	assert_bool(celular.abierto()).is_true()
	assert_int(celular.pantalla()).is_equal(Celular.Pantalla.CHAT)
	assert_bool(celular.atender_esc()).is_true()
	assert_bool(celular.abierto()).is_false()
	assert_bool(celular.atender_esc()).is_false()


func test_esc_no_cierra_el_celular_fijo() -> void:  # AC-INV-072
	var celular := _celular()
	celular.fijar_en(Conversacion.Interlocutor.JEFE)
	assert_bool(celular.atender_esc()).is_false()
	assert_bool(celular.abierto()).is_true()
	assert_bool(celular.fijo()).is_true()


func _celular_con(leidos: int, nuevos: int) -> Celular:
	var conversacion := Conversacion.new()
	conversacion.nombre = "Contacto"
	var mensajes: Array[Mensaje] = []
	for indice in leidos:
		mensajes.append(_mensaje("viejo %d" % indice))
	conversacion.mensajes = mensajes
	var celular := Celular.new(Bandeja.new([conversacion]))
	celular.habilitar(true)
	celular.alternar(false)
	celular.abrir_chat(conversacion.interlocutor)
	celular.volver_al_menu()
	for indice in nuevos:
		celular.bandeja().recibir(conversacion.interlocutor, _mensaje("nuevo %d" % indice))
	return celular


func _mensaje(texto: String) -> Mensaje:
	var mensaje := Mensaje.new()
	mensaje.texto = texto
	return mensaje


func test_abrir_con_mensajes_sin_leer_apunta_al_primero() -> void:  # AC-INV-160
	var celular := _celular_con(27, 3)
	var quien := celular.bandeja().conversaciones()[0].interlocutor
	assert_bool(celular.abrir_chat(quien)).is_true()
	assert_int(celular.primer_nuevo()).is_equal(27)
	assert_int(celular.bandeja().no_leidos_totales()).is_zero()


func test_abrir_sin_mensajes_sin_leer_no_apunta_a_ninguno() -> void:  # AC-INV-161
	var celular := _celular_con(30, 0)
	var quien := celular.bandeja().conversaciones()[0].interlocutor
	celular.abrir_chat(quien)
	assert_int(celular.primer_nuevo()).is_equal(Celular.AL_FINAL)


func test_un_unico_sin_leer_que_es_el_ultimo_es_el_primero() -> void:  # AC-INV-162
	var celular := _celular_con(29, 1)
	var quien := celular.bandeja().conversaciones()[0].interlocutor
	celular.abrir_chat(quien)
	assert_int(celular.primer_nuevo()).is_equal(29)


func test_volver_al_menu_suelta_a_donde_apuntaba() -> void:  # AC-INV-160
	var celular := _celular_con(27, 3)
	var quien := celular.bandeja().conversaciones()[0].interlocutor
	celular.abrir_chat(quien)
	celular.volver_al_menu()
	assert_int(celular.primer_nuevo()).is_equal(Celular.AL_FINAL)


func test_el_fijo_apunta_al_primer_mensaje_que_llega_y_no_cambia() -> void:  # AC-INV-163
	var celular := _celular_con(5, 3)
	var quien := celular.bandeja().conversaciones()[0].interlocutor
	celular.fijar_en(quien)
	assert_int(celular.primer_nuevo()).is_equal(Celular.AL_FINAL)
	celular.llegar(quien, 8)
	assert_int(celular.primer_nuevo()).is_equal(8)
	celular.llegar(quien, 9)
	assert_int(celular.primer_nuevo()).is_equal(8)


func test_la_llegada_a_un_chat_libre_no_cambia_a_donde_apunta() -> void:  # AC-INV-164
	var celular := _celular_con(30, 0)
	var quien := celular.bandeja().conversaciones()[0].interlocutor
	celular.abrir_chat(quien)
	celular.llegar(quien, 30)
	assert_int(celular.primer_nuevo()).is_equal(Celular.AL_FINAL)
