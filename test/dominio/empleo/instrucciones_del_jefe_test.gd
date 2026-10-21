extends GdUnitTestSuite

const CondicionesDelJefeTest := preload("res://test/dominio/empleo/condiciones_del_jefe_test.gd")

const GUION := "res://src/dominio/investigacion/conversacion_con_el_jefe.tres"
const PRIMERA := ReglasDeLaPartida.PRIMERA_JORNADA
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
## Qué recibe cada jornada, en orden. Las fotos van antes de su Intro.
const ENTRADAS := {
	PRIMERA:
	[
		"J1_Intro01",
		"J1_Foto02",
		"J1_Intro02",
		"J1_Foto03",
		"J1_Intro03",
		"J1_Foto04",
		"J1_Intro04",
		"J1_Intro05",
		"J1_Foto06",
		"J1_Intro06",
	],
	PRIMERA + 1: ["J1_Foto07", "J1_Intro07", "J1_Intro08"],
	PRIMERA + 2: ["J1_Foto09", "J1_Intro09"],
	COMPLETA: ["J1_Intro10", "J1_Foto11", "J1_Intro11", "J1_Intro12"],
}


func _guion() -> Conversacion:
	return load(GUION)


func _identidades(mensajes: Array[Mensaje]) -> Array[String]:
	var identidades: Array[String] = []
	for mensaje in mensajes:
		identidades.append(mensaje.identidad)
	return identidades


func test_volver_y_ok_recorren_las_pantallas_de_la_primera() -> void:  # AC-EMP-045
	var cantidad := (
		InstruccionesDelJefe
		. pasos_de(InstruccionesDelJefe.de_la_jornada(_guion().mensajes, PRIMERA))
		. size()
	)
	var instrucciones := InstruccionesDelJefe.new(cantidad)
	assert_int(instrucciones.paso_actual()).is_equal(1)
	assert_bool(instrucciones.se_puede_volver()).is_false()
	assert_bool(instrucciones.volver()).is_false()
	for paso in cantidad - 1:
		instrucciones.avanzar()
	assert_int(instrucciones.paso_actual()).is_equal(cantidad)
	assert_bool(instrucciones.en_el_ultimo()).is_true()
	assert_bool(instrucciones.terminadas()).is_false()
	assert_bool(instrucciones.volver()).is_true()
	assert_int(instrucciones.paso_actual()).is_equal(cantidad - 1)
	assert_bool(instrucciones.en_el_ultimo()).is_false()
	instrucciones.avanzar()
	instrucciones.avanzar()
	assert_bool(instrucciones.terminadas()).is_true()
	instrucciones.avanzar()
	assert_int(instrucciones.paso_actual()).is_equal(cantidad)
	assert_bool(instrucciones.volver()).is_false()
	var otras := InstruccionesDelJefe.new(cantidad)
	for paso in 3:
		otras.avanzar()
	for paso in 3:
		assert_bool(otras.volver()).is_true()
	assert_int(otras.paso_actual()).is_equal(1)
	assert_bool(otras.volver()).is_false()


func test_un_paso_termina_al_primer_avance() -> void:  # AC-EMP-045
	var instrucciones := InstruccionesDelJefe.new(1)
	assert_int(instrucciones.paso_actual()).is_equal(1)
	assert_bool(instrucciones.en_el_ultimo()).is_true()
	assert_bool(instrucciones.volver()).is_false()
	instrucciones.avanzar()
	assert_bool(instrucciones.terminadas()).is_true()
	instrucciones.avanzar()
	assert_int(instrucciones.paso_actual()).is_equal(1)


func test_cada_jornada_de_introduccion_recibe_lo_suyo() -> void:  # AC-EMP-046, AC-EMP-047
	var guion := _guion()
	var originales: Array[Mensaje] = guion.mensajes.duplicate()
	assert_str(guion.nombre).is_equal("Enrique Peldaño")
	assert_object(guion.imagen).is_not_null()
	for jornada: int in ENTRADAS:
		var propios: Array[Mensaje] = []
		for mensaje in guion.mensajes:
			if mensaje.jornada == jornada and mensaje.condicion.is_empty():
				propios.append(mensaje)
		assert_array(_identidades(propios)).is_equal(ENTRADAS[jornada])
	var bandeja := Bandeja.new([guion])
	bandeja.abrir_jornada(COMPLETA)
	var chat := bandeja.mensajes_de(guion.interlocutor)
	var esperado: Array[String] = []
	for jornada: int in ENTRADAS:
		esperado.append_array(ENTRADAS[jornada])
	assert_array(_identidades(chat)).is_equal(esperado)
	for indice in chat.size():
		if chat[indice].foto != null:
			assert_str(chat[indice].texto).is_empty()
			assert_str(chat[indice + 1].identidad).is_equal(
				chat[indice].identidad.replace("Foto", "Intro")
			)
			assert_object(bandeja.adjunto_de(guion.interlocutor, indice)).is_same(chat[indice + 1])
	assert_array(guion.mensajes).is_equal(originales)


func test_las_pantallas_de_cada_jornada() -> void:  # AC-EMP-045, AC-EMP-046
	var mensajes := _guion().mensajes
	var primera := InstruccionesDelJefe.pasos_de(
		InstruccionesDelJefe.de_la_jornada(mensajes, PRIMERA)
	)
	var con_foto: Array[String] = []
	for paso in primera:
		assert_int(paso.textos.size()).is_equal(1)
		if paso.foto != null:
			con_foto.append(paso.textos[0].identidad)
	assert_array(con_foto).is_equal(["J1_Intro02", "J1_Intro03", "J1_Intro04", "J1_Intro06"])
	assert_int(primera.size()).is_equal(6)
	assert_str(primera[-1].textos[0].identidad).is_equal("J1_Intro06")
	var tercera := InstruccionesDelJefe.pasos_de(
		InstruccionesDelJefe.de_la_jornada(mensajes, PRIMERA + 2)
	)
	assert_int(tercera.size()).is_equal(1)
	for jornada_y_intro: Array in [[PRIMERA + 1, "J1_Intro07"], [PRIMERA + 2, "J1_Intro09"]]:
		var pasos := InstruccionesDelJefe.pasos_de(
			InstruccionesDelJefe.de_la_jornada(mensajes, jornada_y_intro[0])
		)
		assert_str(pasos[0].textos[0].identidad).is_equal(jornada_y_intro[1])
		assert_object(pasos[0].foto).is_not_null()
	for jornada in range(PRIMERA, COMPLETA):
		var propios := InstruccionesDelJefe.de_la_jornada(mensajes, jornada)
		var textos := propios.filter(func(mensaje: Mensaje) -> bool: return mensaje.foto == null)
		assert_array(_identidades(propios)).is_equal(ENTRADAS[jornada])
		assert_int(InstruccionesDelJefe.pasos_de(propios).size()).is_equal(textos.size())


func test_fuera_de_la_introduccion_no_hay_instrucciones() -> void:  # AC-EMP-046, AC-EMP-077
	var mensajes := _guion().mensajes
	var ultima := PRIMERA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
	for jornada: int in [PRIMERA - 1, ultima + 1]:
		assert_array(InstruccionesDelJefe.de_la_jornada(mensajes, jornada)).is_empty()
	for jornada in range(COMPLETA, ultima + 1):
		assert_array(InstruccionesDelJefe.de_la_jornada(mensajes, jornada)).is_empty()


func test_una_jornada_sin_mensajes_propios_no_tiene_instrucciones() -> void:  # AC-EMP-077
	var sin_la_segunda: Array[Mensaje] = []
	for mensaje in _guion().mensajes:
		if mensaje.jornada != PRIMERA + 1:
			sin_la_segunda.append(mensaje)
	assert_array(InstruccionesDelJefe.de_la_jornada(sin_la_segunda, PRIMERA + 1)).is_empty()
	assert_array(InstruccionesDelJefe.de_la_jornada(sin_la_segunda, PRIMERA)).is_not_empty()


func test_sin_mensajes_no_inventa_pantallas() -> void:  # AC-EMP-046
	assert_array(InstruccionesDelJefe.pasos_de([])).is_empty()


func test_el_chat_guarda_solo_el_mensaje_1_elegido() -> void:  # AC-EMP-085
	var guion := _guion()
	var otras: Array[String] = []
	for jornada: int in ENTRADAS:
		if jornada == PRIMERA + 2:
			otras.append("J3_Mensaje1_SinFallas")
		if jornada != PRIMERA + 1:
			otras.append_array(ENTRADAS[jornada])
	for fila: Array in CondicionesDelJefeTest.FILAS:
		var partida := CondicionesDelJefeTest.cerrar_la_primera(fila[0], fila[1])
		var bandeja := Bandeja.new([guion])
		bandeja.abrir_jornada(PRIMERA, CondicionesDelJefe.elegidas(partida.noches_de_prueba))
		for mensaje in bandeja.mensajes_de(guion.interlocutor):
			assert_int(mensaje.jornada).is_equal(PRIMERA)
		CondicionesDelJefeTest.cerrar_la_noche(partida, 0, [])
		bandeja.abrir_jornada(COMPLETA, CondicionesDelJefe.elegidas(partida.noches_de_prueba))
		var chat := _identidades(bandeja.mensajes_de(guion.interlocutor))
		assert_int(chat.size()).is_equal(21)
		var desde := ENTRADAS[PRIMERA].size()
		assert_array(chat.slice(desde, desde + 4)).is_equal(
			[fila[2], "J1_Foto07", "J1_Intro07", "J1_Intro08"]
		)
		var sin_la_segunda := chat.slice(0, desde) + chat.slice(desde + 4)
		assert_array(sin_la_segunda).is_equal(otras)


func test_el_chat_guarda_solo_el_mensaje_1_elegido_de_la_tercera() -> void:  # AC-EMP-088
	var guion := _guion()
	var partida := CondicionesDelJefeTest.cerrar_la_segunda(1, true, false)
	var bandeja := Bandeja.new([guion])
	bandeja.abrir_jornada(COMPLETA, CondicionesDelJefe.elegidas(partida.noches_de_prueba))
	var de_la_tercera: Array[String] = []
	for mensaje in bandeja.mensajes_de(guion.interlocutor):
		if mensaje.jornada == PRIMERA + 2:
			de_la_tercera.append(mensaje.identidad)
	assert_array(de_la_tercera).is_equal(
		["J3_Mensaje1_AtencionYReposicionMal", "J1_Foto09", "J1_Intro09"]
	)
