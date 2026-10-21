extends GdUnitTestSuite

const GUION := "res://src/dominio/investigacion/conversacion_con_el_jefe.tres"
const PRIMERA := ReglasDeLaPartida.PRIMERA_JORNADA
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
## Qué recibe cada jornada, en orden. Las fotos van antes de su Intro.
const ENTRADAS := {
	PRIMERA:
	[
		"J1_Intro01",
		"J1_FotoReloj",
		"J1_Foto02",
		"J1_Intro02",
		"J1_Foto03",
		"J1_Intro03",
		"J1_Foto04",
		"J1_Intro04",
		"J1_Intro05",
		"J1_Foto06",
		"J1_Intro06",
		"J1_Reponer",
	],
	PRIMERA + 1: ["J2_FotoGondolas", "J1_Foto07", "J1_Intro07", "J1_Intro08"],
	PRIMERA + 2: ["J1_Foto09", "J1_Intro09", "J1_Intro12"],
	COMPLETA: ["J1_Intro10", "J1_Foto11", "J1_Intro11"],
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
			if mensaje.jornada == jornada:
				propios.append(mensaje)
		assert_array(_identidades(propios)).is_equal(ENTRADAS[jornada])
	var bandeja := Bandeja.new([guion])
	bandeja.abrir_jornada(COMPLETA)
	var chat := bandeja.mensajes_de(guion.interlocutor)
	var esperado: Array[String] = []
	for jornada: int in ENTRADAS:
		esperado.append_array(ENTRADAS[jornada])
	assert_array(_identidades(chat)).is_equal(esperado)
	var intro_por_foto := {
		"J1_FotoReloj": "J1_Intro02",
		"J1_Foto02": "J1_Intro02",
		"J1_Foto03": "J1_Intro03",
		"J1_Foto04": "J1_Intro04",
		"J1_Foto06": "J1_Intro06",
		"J2_FotoGondolas": "J1_Intro07",
		"J1_Foto07": "J1_Intro07",
		"J1_Foto09": "J1_Intro09",
		"J1_Foto11": "J1_Intro11",
	}
	assert_int(chat.size()).is_equal(22)
	var fotos := 0
	for indice in chat.size():
		if chat[indice].foto != null:
			fotos += 1
			assert_str(chat[indice].texto).is_empty()
			var adjunto := bandeja.adjunto_de(guion.interlocutor, indice)
			assert_object(adjunto).is_not_null()
			if adjunto != null:
				assert_str(adjunto.identidad).is_equal(intro_por_foto[chat[indice].identidad])
	assert_int(fotos).is_equal(9)
	assert_array(guion.mensajes).is_equal(originales)


func test_las_pantallas_de_cada_jornada() -> void:  # AC-EMP-045, AC-EMP-046
	var mensajes := _guion().mensajes
	var primera := InstruccionesDelJefe.pasos_de(
		InstruccionesDelJefe.de_la_jornada(mensajes, PRIMERA)
	)
	var con_foto: Array[String] = []
	for paso in primera:
		assert_int(paso.textos.size()).is_equal(1)
		if not _fotos(paso).is_empty():
			con_foto.append(paso.textos[0].identidad)
	assert_array(con_foto).is_equal(["J1_Intro02", "J1_Intro03", "J1_Intro04", "J1_Intro06"])
	assert_str(primera[-1].textos[0].identidad).is_equal("J1_Reponer")
	assert_array(_fotos(primera[-1])).is_empty()
	var tercera := InstruccionesDelJefe.pasos_de(
		InstruccionesDelJefe.de_la_jornada(mensajes, PRIMERA + 2)
	)
	assert_str(tercera[-1].textos[0].identidad).is_equal("J1_Intro12")
	assert_array(_fotos(tercera[-1])).is_empty()
	for jornada_y_intro: Array in [[PRIMERA + 1, "J1_Intro07"], [PRIMERA + 2, "J1_Intro09"]]:
		var pasos := InstruccionesDelJefe.pasos_de(
			InstruccionesDelJefe.de_la_jornada(mensajes, jornada_y_intro[0])
		)
		assert_str(pasos[0].textos[0].identidad).is_equal(jornada_y_intro[1])
		assert_array(_fotos(pasos[0])).is_not_empty()
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


func test_dos_fotos_se_agrupan_con_el_texto_y_conservan_su_orden() -> void:  # AC-EMP-046
	var primera := _mensaje("primera", true)
	var segunda := _mensaje("segunda", true)
	var texto := _mensaje("texto", false)
	texto.texto = "La instrucción de las dos fotos"
	var pasos := InstruccionesDelJefe.pasos_de([primera, segunda, texto])
	assert_int(pasos.size()).is_equal(1)
	if pasos.size() != 1:
		return
	assert_array(_fotos(pasos[0])).is_equal([primera, segunda])
	assert_array(pasos[0].textos).is_equal([texto])


func test_el_grupo_sin_texto_conserva_sus_fotos_huerfanas() -> void:  # AC-EMP-046
	var primera := _mensaje("primera", true)
	var segunda := _mensaje("segunda", true)
	for cantidad: int in [1, 2]:
		var mensajes: Array[Mensaje] = [primera]
		if cantidad == 2:
			mensajes.append(segunda)
		var pasos := InstruccionesDelJefe.pasos_de(mensajes)
		assert_int(pasos.size()).is_equal(1)
		assert_array(_fotos(pasos[0])).is_equal(mensajes)
		assert_array(pasos[0].textos).is_empty()


func test_los_pares_reales_preceden_su_intro_sin_sumar_pantallas() -> void:  # AC-EMP-046
	for caso: Array in [
		[PRIMERA, 1, ["J1_FotoReloj", "J1_Foto02"], "J1_Intro02", 7],
		[PRIMERA + 1, 0, ["J2_FotoGondolas", "J1_Foto07"], "J1_Intro07", 2],
	]:
		var pasos := InstruccionesDelJefe.pasos_de(
			InstruccionesDelJefe.de_la_jornada(_guion().mensajes, caso[0])
		)
		assert_int(pasos.size()).is_equal(caso[4])
		var paso: InstruccionesDelJefe.Paso = pasos[caso[1]]
		assert_array(_identidades(_fotos(paso))).is_equal(caso[2])
		assert_array(_identidades(paso.textos)).is_equal([caso[3]])


func test_las_fotos_nuevas_tienen_resolucion_de_captura() -> void:  # AC-EMP-047
	var encontradas: Array[String] = []
	for mensaje in _guion().mensajes:
		if mensaje.identidad in ["J1_FotoReloj", "J2_FotoGondolas"]:
			encontradas.append(mensaje.identidad)
			assert_object(mensaje.foto).is_not_null()
			if mensaje.foto != null:
				assert_vector(mensaje.foto.get_size()).is_equal(Vector2(960, 540))
	assert_array(encontradas).is_equal(["J1_FotoReloj", "J2_FotoGondolas"])


func _mensaje(identidad: String, con_foto: bool) -> Mensaje:
	var mensaje := Mensaje.new()
	mensaje.identidad = identidad
	if con_foto:
		mensaje.foto = GradientTexture2D.new()
	return mensaje


func _fotos(paso: InstruccionesDelJefe.Paso) -> Array[Mensaje]:
	var fotos: Variant = paso.get("fotos")
	assert_bool(fotos is Array).is_true()
	if not fotos is Array:
		return []
	return fotos
