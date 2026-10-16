extends GdUnitTestSuite


func test_solo_los_gestos_aceptados_publican_y_leer_no_suena() -> void:  # AC-INV-026, AC-INV-010
	var sistema: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	var abiertos: Array[int] = []
	var cerrados: Array[int] = []
	var menus: Array[int] = []
	var chats: Array[Conversacion.Interlocutor] = []
	var cuentas: Array[int] = []
	var llegadas: Array[Mensaje] = []
	sistema.celular_abierto.connect(func() -> void: abiertos.append(1))
	sistema.celular_cerrado.connect(func() -> void: cerrados.append(1))
	sistema.menu_mostrado.connect(func() -> void: menus.append(1))
	sistema.chat_abierto.connect(
		func(quien: Conversacion.Interlocutor) -> void: chats.append(quien)
	)
	sistema.no_leidos_cambiados.connect(func(cuenta: int) -> void: cuentas.append(cuenta))
	sistema.mensaje_recibido.connect(
		func(_quien: Conversacion.Interlocutor, mensaje: Mensaje) -> void: llegadas.append(mensaje)
	)
	sistema.pedir_alternar(false)
	assert_array(abiertos).is_empty()
	sistema.abrir_jornada(1)
	sistema.pedir_alternar(true)
	sistema.pedir_alternar(false)
	assert_int(abiertos.size()).is_equal(1)
	assert_int(menus.size()).is_equal(1)
	sistema.pedir_chat(Conversacion.Interlocutor.JEFE)
	sistema.pedir_chat(Conversacion.Interlocutor.JEFE)
	assert_int(chats.size()).is_equal(1)
	assert_int(sistema.bandeja().no_leidos(Conversacion.Interlocutor.JEFE)).is_zero()
	assert_array(llegadas).is_empty()
	sistema.pedir_volver()
	sistema.pedir_volver()
	assert_int(menus.size()).is_equal(2)
	sistema.pedir_alternar(false)
	sistema.cerrar_jornada()
	assert_int(cerrados.size()).is_equal(1)
	assert_int(cuentas.size()).is_equal(2)


func test_recibir_cerrado_y_en_chat_avisa_una_vez() -> void:  # AC-INV-029, AC-INV-030
	var sistema: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	var eventos: Array[Mensaje] = []
	var cuentas: Array[int] = []
	sistema.mensaje_recibido.connect(
		func(_quien: Conversacion.Interlocutor, mensaje: Mensaje) -> void: eventos.append(mensaje)
	)
	sistema.no_leidos_cambiados.connect(func(cuenta: int) -> void: cuentas.append(cuenta))
	var mensaje := Mensaje.new()
	mensaje.texto = "Prueba"
	var antes := sistema.bandeja().no_leidos_totales()
	sistema.recibir(Conversacion.Interlocutor.JEFE, null)
	assert_array(eventos).is_empty()
	sistema.recibir(Conversacion.Interlocutor.JEFE, mensaje)
	assert_array(eventos).is_equal([mensaje])
	assert_array(cuentas).is_equal([antes + 1])
	sistema.abrir_jornada(1)
	sistema.pedir_alternar(false)
	sistema.pedir_chat(Conversacion.Interlocutor.JEFE)
	sistema.recibir(Conversacion.Interlocutor.JEFE, mensaje)
	assert_int(eventos.size()).is_equal(2)
	assert_int(sistema.bandeja().no_leidos(Conversacion.Interlocutor.JEFE)).is_equal(1)
	var nueva: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	assert_int(nueva.bandeja().no_leidos_totales()).is_equal(antes)


func test_modo_fijo_y_foto_publican_los_datos_y_un_solo_cierre() -> void:  # AC-INV-031, AC-INV-032
	var sistema: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	var foto := Mensaje.new()
	foto.foto = GradientTexture2D.new()
	var adjunto := Mensaje.new()
	adjunto.texto = "Texto adjunto"
	sistema.recibir(Conversacion.Interlocutor.JEFE, foto)
	sistema.recibir(Conversacion.Interlocutor.JEFE, adjunto)
	var fotos: Array[Mensaje] = []
	var adjuntos: Array[Mensaje] = []
	var cierres: Array[int] = []
	var cerradas: Array[int] = []
	sistema.foto_ampliada.connect(
		func(imagen: Mensaje, texto: Mensaje) -> void:
			fotos.append(imagen)
			adjuntos.append(texto)
	)
	sistema.foto_cerrada.connect(func() -> void: cerradas.append(1))
	sistema.celular_cerrado.connect(func() -> void: cierres.append(1))
	sistema.mostrar_fijo(Conversacion.Interlocutor.JEFE)
	sistema.pedir_alternar(false)
	sistema.pedir_volver()
	assert_bool(sistema.celular().fijo()).is_true()
	var indice := sistema.bandeja().mensajes_de(Conversacion.Interlocutor.JEFE).size() - 2
	sistema.pedir_foto(indice)
	sistema.pedir_foto(indice)
	assert_array(fotos).is_equal([foto])
	assert_array(adjuntos).is_equal([adjunto])
	sistema.pedir_cerrar_foto()
	sistema.pedir_cerrar_foto()
	assert_int(cerradas.size()).is_equal(1)
	sistema.soltar()
	sistema.soltar()
	assert_int(cierres.size()).is_equal(1)


func test_otra_jornada_cierra_el_fijo_y_conserva_lecturas() -> void:  # AC-INV-036, AC-INV-037
	var sistema: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	sistema.mostrar_fijo(Conversacion.Interlocutor.JEFE)
	sistema.abrir_jornada(3)
	assert_bool(sistema.celular().abierto()).is_false()
	assert_bool(sistema.celular().fijo()).is_false()
	# La introducción sigue leída; los dos mensajes de apertura J2 son nuevos.
	assert_int(sistema.bandeja().no_leidos(Conversacion.Interlocutor.JEFE)).is_equal(2)
	sistema.pedir_alternar(false)
	assert_int(sistema.celular().pantalla()).is_equal(Celular.Pantalla.MENU)


func test_interlocutor_sin_conversacion_no_emite_llegada_ni_cuenta() -> void:  # AC-INV-030
	var sistema: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	var conversacion := Conversacion.new()
	conversacion.interlocutor = Conversacion.Interlocutor.JEFE
	var bandeja := Bandeja.new([conversacion])
	sistema.set("_bandeja", bandeja)
	sistema.set("_celular", Celular.new(bandeja))
	var llegadas: Array[Mensaje] = []
	var cuentas: Array[int] = []
	sistema.mensaje_recibido.connect(
		func(_quien: Conversacion.Interlocutor, mensaje: Mensaje) -> void: llegadas.append(mensaje)
	)
	sistema.no_leidos_cambiados.connect(func(cuenta: int) -> void: cuentas.append(cuenta))
	var mensaje := Mensaje.new()
	mensaje.texto = "Este interlocutor no tiene conversación."
	sistema.recibir(Conversacion.Interlocutor.PROVEEDOR, mensaje)
	sistema.recibir(Conversacion.Interlocutor.JEFE, null)
	assert_array(llegadas).is_empty()
	assert_array(cuentas).is_empty()
	assert_int(bandeja.no_leidos_totales()).is_zero()
	assert_array(bandeja.mensajes_de(Conversacion.Interlocutor.PROVEEDOR)).is_empty()


func test_el_tramo_identificado_emite_solo_en_su_chat_visible() -> void:  # AC-INV-041
	var sistema: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	var pedidos: Array[String] = []
	sistema.tramo_de_pista_pedido.connect(
		func(identidad: String) -> void: pedidos.append(identidad)
	)
	sistema.abrir_jornada(1)
	sistema.pedir_alternar(false)
	sistema.pedir_chat(Conversacion.Interlocutor.JEFE)
	sistema.pedir_tramo("J2_6", "falta_algo")
	assert_array(pedidos).is_empty()
	sistema.abrir_jornada(2)
	sistema.pedir_tramo("J2_6", "falta_algo")
	assert_array(pedidos).is_empty()
	sistema.pedir_alternar(false)
	sistema.pedir_chat(Conversacion.Interlocutor.YASMIN)
	assert_array(pedidos).is_empty()
	sistema.pedir_tramo("inexistente", "falta_algo")
	sistema.pedir_tramo("J2_6", "fuera")
	sistema.pedir_tramo("J2_5", "falta_algo")
	assert_array(pedidos).is_empty()
	sistema.pedir_tramo("J2_6", "falta_algo")
	sistema.pedir_tramo("J2_6", "falta_algo")
	assert_array(pedidos).is_equal(["2A", "2A"])
	sistema.pedir_volver()
	sistema.pedir_tramo("J2_6", "falta_algo")
	assert_array(pedidos).is_equal(["2A", "2A"])


# AC-INV-039, AC-INV-040
func test_abrir_repetido_no_duplica_y_cada_chat_tiene_su_lectura() -> void:
	var sistema: CelularDelEmpleado = auto_free(CelularDelEmpleado.new())
	sistema.abrir_jornada(2)
	sistema.pedir_alternar(false)
	sistema.pedir_chat(Conversacion.Interlocutor.YASMIN)
	var jefe := sistema.bandeja().no_leidos(Conversacion.Interlocutor.JEFE)
	assert_int(sistema.bandeja().no_leidos(Conversacion.Interlocutor.YASMIN)).is_zero()
	for _vez: int in 2:
		sistema.pedir_volver()
		sistema.pedir_chat(Conversacion.Interlocutor.YASMIN)
		sistema.pedir_alternar(false)
		sistema.pedir_alternar(false)
		sistema.abrir_jornada(2)
	assert_int(sistema.bandeja().mensajes_de(Conversacion.Interlocutor.YASMIN).size()).is_equal(15)
	assert_int(sistema.bandeja().no_leidos(Conversacion.Interlocutor.YASMIN)).is_zero()
	assert_int(sistema.bandeja().no_leidos(Conversacion.Interlocutor.JEFE)).is_equal(jefe)
