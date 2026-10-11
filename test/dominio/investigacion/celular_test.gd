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
